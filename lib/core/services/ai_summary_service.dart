import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/chat_message.dart';
import '../../models/chat_summary.dart';

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
}
