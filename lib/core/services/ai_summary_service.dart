import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/chat_message.dart';
import '../../models/chat_summary.dart';
import '../../models/inbox_summary.dart';
import '../services/encryption/e2ee_crypto.dart';
import '../services/encryption/e2ee_key_store.dart';
import '../services/encryption/e2ee_manager.dart';

/// Provides AI-powered chat summarisation via Gemini REST API (v1 stable).
///
/// Only successfully decrypted text messages are included in the transcript.
/// Undecryptable and media messages are silently excluded.
///
/// Uses direct HTTP to `v1` endpoint — the `google_generative_ai` SDK is
/// NOT used because it hardcodes `v1beta` which returns 404 for current models.
class AiSummaryService {
  AiSummaryService._();
  static final AiSummaryService instance = AiSummaryService._();

  static const String _remoteConfigKey = 'gemini_api_key';
  static const String _fallbackApiKey =
      'AIzaSyB5vMP-GFtjmw2ptn9cAtHbSZ4-Km2dlcc';

  /// Stable v1 endpoint — NOT v1beta.
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1/models';

  /// Cached model name resolved from the API. Populated once per session.
  String? _resolvedModel;

  static String _systemPrompt(String langCode) {
    final isArabic = langCode == 'ar';

    final baseRules = isArabic
        ? '''أنت مساعد ذكاء اصطناعي داخل تطبيق محادثة مشفر من طرف إلى طرف.

لغة الإخراج: العربية — بغض النظر عن لغة الرسائل الأصلية.
إذا كانت المحادثة بالإنجليزية أو بلغة مختلطة، لخّص المعنى بالعربية بأسلوب طبيعي وسلس.

قواعد مهمة:
- تم فك تشفير الرسائل محليًا على جهاز المستخدم قبل إرسالها إليك.
- لا تذكر التشفير أو المفاتيح أو تفاصيل الأمان إلا إذا طُلب ذلك صراحةً.
- لخّص فقط النص المقدم دون اختلاق رسائل أو سياق غير موجود.
- تجاهل الرسائل التالفة أو غير القابلة للقراءة.
- ركّز على: القرارات، المهام، بنود العمل، الأسئلة المعلقة، السياق المهم، المواعيد النهائية، المشكلات التقنية.
- اكتب بأسلوب عربي طبيعي وواضح — تجنّب الترجمة الحرفية أو الصياغات الآلية.
- استخدم جملًا مترابطة ومفيدة بدلًا من تكرار عبارات مثل "لم يتم ذكر..." في كل حقل.
- إذا لم يوجد محتوى لحقل معين، اكتب ملاحظة مختصرة ومختلفة (مثل: "لا يوجد" أو "غير متوفر في المحادثة").
- حافظ على المعنى التقني الدقيق.
- إذا كانت المحادثة قصيرة، قدّم ملخصًا قصيرًا وموجزًا.
- إذا احتوت المحادثة على أكواد أو سجلات، لخّص المشكلة التقنية بدقة.
- لا تُخرج بيانات وصفية داخلية حساسة.
- أبقِ الأسماء والمصطلحات التقنية والأكواد بلغتها الأصلية دون ترجمة.

أسلوب المخرجات: واضح، مقروء، موجز، دقيق، منظم عند الحاجة.'''
        : '''You are an AI assistant inside an end-to-end encrypted chat application.

Output language: English — regardless of the original chat language.
If the conversation is in Arabic or mixed languages, summarize the meaning in natural English.

Important rules:
- Messages were decrypted locally on the user's device before being sent to you.
- Never mention encryption, cryptography, keys, ciphertext, or security internals unless explicitly asked.
- Only summarize the provided plaintext transcript.
- Never invent missing messages or context.
- Ignore corrupted, missing, or undecryptable messages.
- Focus on: decisions, tasks, action items, unanswered questions, important context, deadlines, technical issues.
- Keep summaries concise and readable.
- Preserve important technical meaning.
- If the chat is short, return a short concise summary.
- If the chat contains code or logs, summarize the technical issue accurately.
- Never output sensitive internal metadata.
- Never include raw IDs, encryption keys, MAC errors, or internal storage paths unless explicitly requested.
- Keep names, technical terms, and code unchanged — do not translate them.
- If a field has no relevant content, write a brief varied note (e.g. "None identified" or "Not discussed") instead of repeating the same phrase.

Expected output style: clean, human-readable, concise, accurate, structured when useful.''';

    return '$baseRules\n\nThe user transcript will be appended after this system prompt.';
  }

  // ── Safe field extraction ─────────────────────────────────────────────────
  // Gemini may return a field as a String, a Map, or a List depending on
  // how it interprets the prompt.  This helper normalises any value to a
  // human-readable string so the parser never crashes on unexpected types.

  static String _asString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is Map) {
      // e.g. {"Chat A": "summary …", "Chat B": "summary …"}
      final lines = (value as Map<String, dynamic>).entries.map(
        (e) => '${e.key}: ${e.value}',
      );
      return lines.join('\n');
    }
    if (value is List) {
      return value.map((e) => e.toString()).join('\n');
    }
    return value.toString();
  }

  // ── Tolerant JSON parser ──────────────────────────────────────────────────
  // Gemini may return truncated JSON, partial JSON, or plain text.
  // This parser tries multiple strategies before giving up.

  static Map<String, dynamic> _tolerantJsonParse(String raw) {
    // 1. Try direct parse — the happy path.
    try {
      final result = jsonDecode(raw);
      if (result is Map<String, dynamic>) {
        return result;
      }
    } catch (_) {}

    // 2. Try fixing truncated JSON by closing open braces/quotes.
    try {
      var fixed = raw;
      // If it ends mid-string, close the quote and braces.
      if (!fixed.trimRight().endsWith('}')) {
        // Count unmatched braces.
        var depth = 0;
        var inString = false;
        var lastChar = '';
        for (var i = 0; i < fixed.length; i++) {
          final c = fixed[i];
          if (c == '"' && lastChar != '\\') inString = !inString;
          if (!inString) {
            if (c == '{') depth++;
            if (c == '}') depth--;
          }
          lastChar = c;
        }
        if (inString) fixed += '"';
        while (depth > 0) {
          fixed += '}';
          depth--;
        }
      }
      final result = jsonDecode(fixed);
      if (result is Map<String, dynamic>) {
        debugPrint('[AI_SUMMARY:INBOX] parsed with brace-fix');
        return result;
      }
    } catch (_) {}

    // 3. Try extracting a JSON substring from mixed prose.
    try {
      final firstBrace = raw.indexOf('{');
      final lastBrace = raw.lastIndexOf('}');
      if (firstBrace != -1 && lastBrace > firstBrace) {
        final sub = raw.substring(firstBrace, lastBrace + 1);
        final result = jsonDecode(sub);
        if (result is Map<String, dynamic>) {
          debugPrint('[AI_SUMMARY:INBOX] parsed from substring');
          return result;
        }
      }
    } catch (_) {}

    // 4. Regex extraction — pull "key": "value" pairs individually.
    final fields = <String, dynamic>{};
    final fieldPattern = RegExp(
      r'"(\w+)"\s*:\s*"((?:[^"\\]|\\.)*)(?:"|$)',
      dotAll: true,
    );
    for (final match in fieldPattern.allMatches(raw)) {
      final key = match.group(1)!;
      var value = match.group(2) ?? '';
      // Unescape basic JSON escapes.
      value = value
          .replaceAll(r'\"', '"')
          .replaceAll(r'\\', r'\')
          .replaceAll(r'\n', '\n');
      fields[key] = value;
    }
    if (fields.isNotEmpty) {
      debugPrint(
        '[AI_SUMMARY:INBOX] regex-extracted ${fields.length} fields',
      );
      return fields;
    }

    // 5. Nothing worked — return empty map (caller will use raw-text fallback).
    debugPrint('[AI_SUMMARY:INBOX] all parse strategies failed');
    return {};
  }

  // ── Patterns for sensitive data that must never leave the device ──────────

  static final _googleApiKey = RegExp(r'AIza[0-9A-Za-z\-_]{35}');

  static final _base64Key = RegExp(
    r'(?<![A-Za-z0-9+/=])[A-Za-z0-9+/]{44,}={0,2}(?![A-Za-z0-9+/=])',
  );

  static final _hexKey = RegExp(r'\b[0-9a-fA-F]{32,}\b');

  static final _bearerToken = RegExp(
    r'Bearer\s+[A-Za-z0-9\-._~+/]+=*',
    caseSensitive: false,
  );

  static final _pemKey = RegExp(
    r'-----BEGIN[^-]+-----[\s\S]*?-----END[^-]+-----',
    caseSensitive: false,
  );

  static final _urlWithSecret = RegExp(
    r'https?://\S*[?&](key|token|api_key|secret)=[^\s&]+',
    caseSensitive: false,
  );

  static final _storageUrl = RegExp(
    r'https?://firebasestorage\.googleapis\.com/\S+',
    caseSensitive: false,
  );

  static final _dataUri = RegExp(r'data:[a-z]+/[a-z0-9.+-]+;base64,\S+');

  // ── API key loading ───────────────────────────────────────────────────────

  Future<String> _loadApiKey() async {
    // 1. Try Firebase Remote Config first.
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 15),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await rc.fetchAndActivate();
      final remoteKey = rc.getString(_remoteConfigKey);
      if (remoteKey.isNotEmpty) {
        debugPrint('[AI_SUMMARY] API key loaded (Remote Config)');
        return remoteKey;
      }
    } catch (e) {
      debugPrint('[AI_SUMMARY] Remote Config fetch failed: $e');
    }

    // 2. Fallback to hardcoded key.
    debugPrint('[AI_SUMMARY] API key loaded (fallback)');
    return _fallbackApiKey;
  }

  // ── Dynamic model resolution ───────────────────────────────────────────────

  /// Fetches available models from the Gemini API and picks the best
  /// Flash text model. Result is cached in [_resolvedModel] for the session.
  ///
  /// Selection priority:
  ///   1. Model whose ID contains "flash" and supports "generateContent".
  ///   2. Prefer models with "gemini-2" over "gemini-1".
  ///   3. Among equal-generation matches, prefer shorter IDs (base aliases).
  Future<String> _resolveModel(String apiKey) async {
    if (_resolvedModel != null) {
      debugPrint('[AI_SUMMARY] using cached model=$_resolvedModel');
      return _resolvedModel!;
    }

    final url = '$_baseUrl?key=$apiKey';
    debugPrint('[AI_SUMMARY] fetching available models');

    final response = await http.get(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      debugPrint('[AI_SUMMARY] models.list failed (${response.statusCode}): '
          '${response.body}');
      throw Exception(
        'Failed to list Gemini models (${response.statusCode}). '
        'Check API key and billing.',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final models = (body['models'] as List?) ?? [];

    // Filter to flash models that support generateContent.
    final flashModels = models.where((m) {
      final id = (m['name'] as String? ?? '').toLowerCase();
      final methods = (m['supportedGenerationMethods'] as List?) ?? [];
      return id.contains('flash') &&
          methods.any((method) => method == 'generateContent');
    }).toList();

    if (flashModels.isEmpty) {
      debugPrint('[AI_SUMMARY] no flash models available');
      throw Exception(
        'No Gemini Flash models available for this API key. '
        'Check Google AI Studio for model access.',
      );
    }

    // Sort: prefer gemini-2 over gemini-1, then shorter names (base aliases).
    flashModels.sort((a, b) {
      final aId = (a['name'] as String).toLowerCase();
      final bId = (b['name'] as String).toLowerCase();
      final aGen2 = aId.contains('gemini-2');
      final bGen2 = bId.contains('gemini-2');
      if (aGen2 != bGen2) return aGen2 ? -1 : 1;
      return aId.length.compareTo(bId.length);
    });

    // The API returns "models/gemini-2.0-flash" — strip the "models/" prefix.
    final fullName = flashModels.first['name'] as String;
    _resolvedModel =
        fullName.startsWith('models/') ? fullName.substring(7) : fullName;

    debugPrint('[AI_SUMMARY] resolved model=$_resolvedModel');
    return _resolvedModel!;
  }

  // ── Sanitisation ──────────────────────────────────────────────────────────

  String _sanitize(String raw) {
    return raw
        .replaceAll(_googleApiKey, '[REDACTED]')
        .replaceAll(_base64Key, '[REDACTED]')
        .replaceAll(_hexKey, '[REDACTED]')
        .replaceAll(_bearerToken, '[REDACTED]')
        .replaceAll(_pemKey, '[REDACTED]')
        .replaceAll(_urlWithSecret, '[REDACTED_URL]')
        .replaceAll(_storageUrl, '[REDACTED_URL]')
        .replaceAll(_dataUri, '[REDACTED]');
  }

  // ── Firestore summary document reference ─────────────────────────────────

  DocumentReference<Map<String, dynamic>> _summaryRef(String messagesPath) {
    final parts = messagesPath.split('/');
    final parentPath = parts.sublist(0, parts.length - 1).join('/');
    return FirebaseFirestore.instance
        .collection('$parentPath/ai_summaries')
        .doc('latest');
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Generates a summary for [messages] via Gemini and persists it to
  /// Firestore at the location derived from [messagesPath].
  ///
  /// Each message is individually checked for readability — one failed
  /// decryption never aborts the entire pipeline.  Only throws if zero
  /// messages are readable or the Gemini API call itself fails.
  Future<ChatSummary> summarize({
    required List<ChatMessage> messages,
    required String messagesPath,
    required String chatTitle,
    String languageCode = 'en',
  }) async {
    debugPrint('[AI_SUMMARY] started');
    debugPrint('[AI_SUMMARY] locale=$languageCode');
    debugPrint('[AI_SUMMARY] total messages=${messages.length}');

    // ── 1. Pre-filter: keep ONLY text-type messages ─────────────────────
    final textMessages = messages.where((m) {
      return m.messageType == MessageType.text &&
          !m.isDeleted &&
          m.text.trim().isNotEmpty;
    }).toList();

    final skippedMedia = messages.length - textMessages.length;
    debugPrint('[AI_SUMMARY] text messages=${textMessages.length} '
        'skipped (media/deleted/empty)=$skippedMedia');

    // ── 2. Per-message readability check with individual try/catch ───────
    final decrypted = <String>[];
    int failed = 0;

    for (final msg in textMessages) {
      try {
        if (msg.text.startsWith('[Decryption error:')) {
          failed++;
          continue;
        }
        final sanitized = _sanitize(msg.text.trim());
        if (sanitized.isNotEmpty) {
          decrypted.add('[${msg.senderId}]: $sanitized');
        }
      } catch (e) {
        failed++;
        debugPrint('[AI_SUMMARY] processing failed for ${msg.id}: $e');
      }
    }

    debugPrint('[AI_SUMMARY] decrypted=${decrypted.length} failed=$failed');

    if (decrypted.isEmpty) {
      debugPrint('[AI_SUMMARY] aborting — zero readable messages');
      throw Exception('No decryptable messages available for summary.');
    }

    // ── 3. Load API key and build prompt ────────────────────────────────
    final apiKey = await _loadApiKey();
    final transcript = decrypted.join('\n');
    final isArabic = languageCode == 'ar';

    final jsonHints = isArabic
        ? '''
{
  "mainPoints": "<ملخص من 2-4 جمل للمواضيع الرئيسية التي نوقشت>",
  "importantDecisions": "<القرارات الرئيسية المتخذة، أو 'لم تُسجَّل قرارات رئيسية'>",
  "tasksAndActionItems": "<المهام أو بنود العمل المحددة، أو 'لم تُحدَّد مهام معينة'>",
  "deadlinesAndCommitments": "<التواريخ أو المواعيد النهائية المذكورة، أو 'لم تُذكر مواعيد نهائية'>",
  "overallTone": "<النبرة العامة للمحادثة، مثل: رسمي، تعاوني، عاجل>"
}'''
        : '''
{
  "mainPoints": "<2-4 sentence summary of the main topics discussed>",
  "importantDecisions": "<Key decisions made, or 'No major decisions recorded'>",
  "tasksAndActionItems": "<Specific tasks or action items assigned, or 'No specific tasks identified'>",
  "deadlinesAndCommitments": "<Dates, deadlines, or commitments mentioned, or 'No deadlines mentioned'>",
  "overallTone": "<Overall tone of the conversation, e.g. formal, collaborative, urgent>"
}''';

    final instruction = isArabic
        ? 'حلّل المحادثة أدناه وأجب فقط بكائن JSON صالح — بدون علامات markdown. يجب أن تكون جميع القيم باللغة العربية.'
        : 'Analyze the conversation below and reply ONLY with a valid JSON object — no markdown fences. All values must be in English.';

    final prompt = '''
${_systemPrompt(languageCode)}

---

$instruction

Chat title: "$chatTitle"
Messages available: ${decrypted.length}

Transcript:
$transcript

Required JSON structure:
$jsonHints
''';

    // ── 4. Resolve model dynamically and call Gemini v1 stable REST API ──
    final model = await _resolveModel(apiKey);
    final endpoint = '$_baseUrl/$model:generateContent?key=$apiKey';

    debugPrint('[AI_SUMMARY] model=$model  endpoint=v1 (stable)');
    debugPrint('[AI_SUMMARY] sending request');

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.2,
          'maxOutputTokens': 1024,
        },
      }),
    );

    debugPrint('[AI_SUMMARY] response received  status=${response.statusCode}');

    if (response.statusCode != 200) {
      debugPrint('[AI_SUMMARY] error body: ${response.body}');
      throw Exception(
        'Gemini API error (${response.statusCode}). '
        'Check API key, billing, and model availability.',
      );
    }

    // ── 5. Parse JSON response ──────────────────────────────────────────
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = body['candidates'] as List?;
    final candidate =
        (candidates != null && candidates.isNotEmpty) ? candidates.first : null;
    final parts =
        (candidate as Map<String, dynamic>?)?['content']?['parts'] as List?;
    final rawText =
        (parts != null && parts.isNotEmpty ? parts.first['text'] : null)
                as String? ??
            '';

    if (rawText.isEmpty) {
      debugPrint('[AI_SUMMARY] empty response from Gemini');
      throw Exception('Gemini returned an empty response. Please try again.');
    }

    final cleaned = rawText
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (_) {
      debugPrint('[AI_SUMMARY] JSON parse failed. Raw: $cleaned');
      throw Exception(
        'Could not parse Gemini response. Please try again.',
      );
    }

    final summary = ChatSummary(
      mainPoints: parsed['mainPoints'] as String? ?? '',
      importantDecisions: parsed['importantDecisions'] as String? ?? '',
      tasksAndActionItems: parsed['tasksAndActionItems'] as String? ?? '',
      deadlinesAndCommitments:
          parsed['deadlinesAndCommitments'] as String? ?? '',
      overallTone: parsed['overallTone'] as String? ?? '',
      generatedAt: DateTime.now(),
    );

    await _summaryRef(messagesPath).set(summary.toJson());
    debugPrint('[AI_SUMMARY] summary completed and saved');
    return summary;
  }

  /// Returns the most recently saved summary for this chat, or `null` if none
  /// has been generated yet.
  Future<ChatSummary?> fetchSummary(String messagesPath) async {
    final doc = await _summaryRef(messagesPath).get();
    if (!doc.exists || doc.data() == null) return null;
    return ChatSummary.fromJson(doc.data()!);
  }

  // ── Inbox-level summary ──────────────────────────────────────────────────

  /// Maximum recent messages to fetch per conversation for the inbox summary.
  static const int _inboxMsgsPerChat = 10;

  /// Maximum conversations to include in a single inbox summary.
  static const int _inboxMaxChats = 10;

  /// Maximum total messages across all chats to keep token usage reasonable.
  static const int _inboxMaxTotal = 80;

  /// Maximum characters for the combined transcript.
  static const int _inboxMaxTranscriptChars = 8000;

  /// Maximum characters per individual message line.
  static const int _inboxMaxMsgChars = 200;

  static String _inboxSystemPrompt(String langCode) {
    final isArabic = langCode == 'ar';

    return isArabic
        ? '''أنت مساعد ذكاء اصطناعي داخل تطبيق محادثة حكومي مشفر.
المهمة: تلخيص النشاط الأخير عبر عدة محادثات في صندوق الوارد.

لغة الإخراج: العربية — بغض النظر عن لغة الرسائل الأصلية.

قواعد مهمة:
- تم فك تشفير الرسائل محليًا قبل إرسالها إليك.
- لا تذكر التشفير أو المفاتيح أو تفاصيل الأمان.
- لخّص فقط النص المقدم دون اختلاق رسائل أو سياق.
- ركّز على: القرارات، المهام العاجلة، البنود المعلقة، التحديثات المهمة، المواعيد النهائية.
- اكتب بأسلوب عربي طبيعي وواضح.
- إذا لم يوجد محتوى لحقل معين، اكتب ملاحظة مختصرة مثل "لا يوجد" أو "غير متوفر".
- أبقِ الأسماء والمصطلحات التقنية بلغتها الأصلية.
- لكل محادثة، اكتب سطرًا أو سطرين كحد أقصى في تفصيل المحادثات.'''
        : '''You are an AI assistant inside an encrypted government chat application.
Task: Summarize recent activity across multiple conversations in the user's inbox.

Output language: English — regardless of the original chat language.

Important rules:
- Messages were decrypted locally on the user's device before being sent to you.
- Never mention encryption, keys, or security internals.
- Only summarize the provided plaintext transcript.
- Never invent missing messages or context.
- Focus on: decisions, urgent items, pending tasks, important updates, deadlines, action items.
- Keep summaries concise and actionable.
- If a field has no relevant content, write a brief note like "None identified".
- Keep names and technical terms unchanged.
- For the per-chat breakdown, write 1-2 lines max per conversation.''';
  }

  /// Firestore doc reference for storing the inbox summary per user.
  DocumentReference<Map<String, dynamic>> _inboxSummaryRef(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('ai_summaries')
        .doc('inbox_latest');
  }

  /// Persistent HTTP client for inbox requests — avoids connection churn.
  final http.Client _httpClient = http.Client();

  /// Generates an inbox-level summary across all provided conversations.
  ///
  /// For each conversation, fetches the most recent [_inboxMsgsPerChat]
  /// messages, decrypts them locally, then sends the combined transcript
  /// to Gemini. Only text messages with successful decryption are included.
  Future<InboxSummary> summarizeInbox({
    required List<InboxChat> chats,
    required String uid,
    String languageCode = 'en',
  }) async {
    final sw = Stopwatch()..start();
    final chatCount = chats.length > _inboxMaxChats
        ? _inboxMaxChats
        : chats.length;
    debugPrint(
      '[AI_SUMMARY:INBOX] started — ${chats.length} conversations '
      '(capped to $chatCount)',
    );

    final firestore = FirebaseFirestore.instance;
    final sections = <String>[];
    var totalMessages = 0;
    var totalChars = 0;

    for (var ci = 0; ci < chatCount; ci++) {
      if (totalMessages >= _inboxMaxTotal) break;
      if (totalChars >= _inboxMaxTranscriptChars) break;

      final chat = chats[ci];
      try {
        final snap = await firestore
            .collection(chat.messagesPath)
            .orderBy('createdAt', descending: true)
            .limit(_inboxMsgsPerChat)
            .get();

        if (snap.docs.isEmpty) continue;

        final convPath = chat.messagesPath.replaceAll('/messages', '');
        var key = E2eeKeyStore.getConversationKeyCached(convPath);
        key ??= await E2eeKeyStore.getConversationKey(convPath);

        if (key == null) {
          final currentUid = E2eeManager.currentUid;
          if (currentUid != null) {
            key = await E2eeManager.getConversationKey(
              conversationPath: convPath,
              currentUid: currentUid,
              memberUids: const [],
              isPrivateChat: chat.type == 'private',
            );
          }
        }

        final lines = <String>[];
        for (final doc in snap.docs.reversed) {
          if (totalMessages >= _inboxMaxTotal) break;
          if (totalChars >= _inboxMaxTranscriptChars) break;

          final data = doc.data();
          final msgType = data['messageType'] as String? ?? 'text';
          if (msgType != 'text') continue;
          if (data['isDeleted'] as bool? ?? false) continue;

          final isEncrypted = data['isEncrypted'] as bool? ?? false;
          String? text;

          if (isEncrypted && key != null) {
            final encText = data['encryptedText'] as String?;
            final iv = data['iv'] as String?;
            if (encText != null && iv != null) {
              final msgId = doc.id;
              text = E2eeManager.getCachedDecryptedText(msgId);
              if (text == null) {
                try {
                  text = await E2eeCrypto.decrypt(
                    EncryptedPayload(ciphertext: encText, nonce: iv),
                    key,
                  );
                  E2eeManager.cacheDecryptedText(msgId, text);
                } catch (_) {
                  continue;
                }
              }
            }
          } else if (!isEncrypted) {
            text = data['text'] as String?;
          }

          if (text == null || text.trim().isEmpty) continue;
          if (text.startsWith('[Decryption error:')) continue;

          var sanitized = _sanitize(text.trim());
          if (sanitized.isEmpty) continue;

          // Truncate long messages.
          if (sanitized.length > _inboxMaxMsgChars) {
            sanitized = '${sanitized.substring(0, _inboxMaxMsgChars)}…';
          }

          final sender = data['senderId'] as String? ?? '?';
          final line = '[$sender]: $sanitized';
          lines.add(line);
          totalMessages++;
          totalChars += line.length + 1; // +1 for newline
        }

        if (lines.isNotEmpty) {
          final section =
              '--- ${chat.title} (${chat.type}) ---\n${lines.join('\n')}';
          sections.add(section);
        }
      } catch (e) {
        debugPrint('[AI_SUMMARY:INBOX] error processing ${chat.title}: $e');
      }
    }

    debugPrint(
      '[AI_SUMMARY:INBOX] collected: $totalMessages msgs, '
      '$totalChars chars, ${sections.length} chats '
      'in ${sw.elapsedMilliseconds}ms',
    );

    if (sections.isEmpty) {
      throw Exception('No decryptable messages available across conversations.');
    }

    // Build prompt.
    final apiKey = await _loadApiKey();
    final isArabic = languageCode == 'ar';
    var transcript = sections.join('\n\n');

    // Final safety cap on transcript length.
    if (transcript.length > _inboxMaxTranscriptChars) {
      transcript = '${transcript.substring(0, _inboxMaxTranscriptChars)}\n[truncated]';
    }

    final jsonHints = isArabic
        ? '''
{
  "highlights": "<ملخص من 3-5 جمل لأهم التحديثات عبر جميع المحادثات>",
  "urgentItems": "<البنود العاجلة التي تتطلب إجراءً فوريًا، أو 'لا يوجد'>",
  "decisions": "<القرارات الرئيسية المتخذة عبر المحادثات، أو 'لم تُسجَّل قرارات'>",
  "pendingItems": "<المهام والبنود المعلقة التي تحتاج متابعة، أو 'لا يوجد'>",
  "perChatBreakdown": "<سطر أو سطرين لكل محادثة نشطة — اسم المحادثة: ملخص مختصر>",
  "trends": "<اتجاهات التواصل العامة: النبرة، مستوى النشاط، المواضيع المتكررة>"
}'''
        : '''
{
  "highlights": "<3-5 sentence summary of the most important updates across all chats>",
  "urgentItems": "<Urgent items requiring immediate action, or 'None identified'>",
  "decisions": "<Key decisions made across conversations, or 'No decisions recorded'>",
  "pendingItems": "<Pending tasks and items needing follow-up, or 'None identified'>",
  "perChatBreakdown": "<1-2 lines per active conversation — chat name: brief summary>",
  "trends": "<Overall communication trends: tone, activity level, recurring themes>"
}''';

    final instruction = isArabic
        ? 'حلّل النشاط الأخير عبر جميع المحادثات أدناه وأجب فقط بكائن JSON صالح — بدون علامات markdown. يجب أن تكون جميع القيم نصوصًا باللغة العربية — لا كائنات JSON متداخلة.'
        : 'Analyze the recent activity across all conversations below and reply ONLY with a valid JSON object — no markdown fences. All values MUST be plain strings — never nested JSON objects or arrays.';

    final prompt = '''
${_inboxSystemPrompt(languageCode)}

---

$instruction

Total conversations: ${sections.length}
Total messages: $totalMessages

Transcript:
$transcript

Required JSON structure:
$jsonHints
''';

    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.2,
        'maxOutputTokens': 2048,
      },
    });

    debugPrint(
      '[AI_SUMMARY:INBOX] payload: ${requestBody.length} bytes, '
      '~${(requestBody.length / 4).round()} tokens (est)',
    );

    // Call Gemini with retry + timeout.
    final model = await _resolveModel(apiKey);
    final endpoint = '$_baseUrl/$model:generateContent?key=$apiKey';
    final uri = Uri.parse(endpoint);

    http.Response response;
    const maxRetries = 2;

    for (var attempt = 0; ; attempt++) {
      try {
        debugPrint(
          '[AI_SUMMARY:INBOX] request attempt=${attempt + 1} to $model',
        );

        response = await _httpClient
            .post(uri, headers: {'Content-Type': 'application/json'}, body: requestBody)
            .timeout(const Duration(seconds: 60));
        break; // Success — exit retry loop.
      } catch (e) {
        debugPrint('[AI_SUMMARY:INBOX] request failed (attempt ${attempt + 1}): $e');
        if (attempt >= maxRetries) {
          throw Exception(
            'Network error after ${maxRetries + 1} attempts. '
            'Please check your connection and try again.',
          );
        }
        // Exponential backoff: 2s, 4s.
        await Future.delayed(Duration(seconds: 2 << attempt));
      }
    }

    debugPrint(
      '[AI_SUMMARY:INBOX] response status=${response.statusCode} '
      'in ${sw.elapsedMilliseconds}ms',
    );

    if (response.statusCode != 200) {
      debugPrint('[AI_SUMMARY:INBOX] error: ${response.body}');
      throw Exception(
        'Gemini API error (${response.statusCode}). '
        'Check API key, billing, and model availability.',
      );
    }

    // Parse response — reuse the same extraction logic as per-chat summaries.
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = body['candidates'] as List?;
    debugPrint('[AI_SUMMARY:INBOX] candidates=${candidates?.length ?? 0}');

    final candidate =
        (candidates != null && candidates.isNotEmpty) ? candidates.first : null;
    final parts =
        (candidate as Map<String, dynamic>?)?['content']?['parts'] as List?;
    final rawText =
        (parts != null && parts.isNotEmpty ? parts.first['text'] : null)
                as String? ??
            '';

    debugPrint('[AI_SUMMARY:INBOX] rawText length=${rawText.length}');

    if (rawText.isEmpty) {
      throw Exception('Gemini returned an empty response. Please try again.');
    }

    final cleaned = rawText
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    final parsed = _tolerantJsonParse(cleaned);

    debugPrint(
      '[AI_SUMMARY:INBOX] parsed ${parsed.length} fields: '
      '${parsed.keys.join(", ")}',
    );

    final summary = InboxSummary(
      highlights: _asString(parsed['highlights']),
      urgentItems: _asString(parsed['urgentItems']),
      decisions: _asString(parsed['decisions']),
      pendingItems: _asString(parsed['pendingItems']),
      perChatBreakdown: _asString(parsed['perChatBreakdown']),
      trends: _asString(parsed['trends']),
      generatedAt: DateTime.now(),
    );

    // If every field is empty, the response was truly unusable.
    if (summary.highlights.isEmpty &&
        summary.urgentItems.isEmpty &&
        summary.decisions.isEmpty &&
        summary.pendingItems.isEmpty &&
        summary.perChatBreakdown.isEmpty &&
        summary.trends.isEmpty) {
      // Last resort: put the entire raw text into highlights.
      final fallback = InboxSummary(
        highlights: cleaned.length > 2000
            ? '${cleaned.substring(0, 2000)}…'
            : cleaned,
        urgentItems: '',
        decisions: '',
        pendingItems: '',
        perChatBreakdown: '',
        trends: '',
        generatedAt: DateTime.now(),
      );
      await _inboxSummaryRef(uid).set(fallback.toJson());
      debugPrint('[AI_SUMMARY:INBOX] used raw-text fallback');
      return fallback;
    }

    await _inboxSummaryRef(uid).set(summary.toJson());
    debugPrint(
      '[AI_SUMMARY:INBOX] done in ${sw.elapsedMilliseconds}ms',
    );
    return summary;
  }

  /// Returns the most recently saved inbox summary, or `null`.
  Future<InboxSummary?> fetchInboxSummary(String uid) async {
    final doc = await _inboxSummaryRef(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return InboxSummary.fromJson(doc.data()!);
  }
}

/// Lightweight descriptor for a conversation to be summarized.
class InboxChat {
  final String title;
  final String type;
  final String messagesPath;
  const InboxChat({
    required this.title,
    required this.type,
    required this.messagesPath,
  });
}
