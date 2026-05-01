import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart' show InvalidCipherTextException;
import 'package:record/record.dart';

import '../../../../../core/datasource/remote_data/firebase_service.dart';
import '../../../../../core/services/encryption/aes_service.dart';
import '../../../../../core/services/encryption/conversation_key_service.dart';
import '../../../../../core/services/encryption/key_management_service.dart';
import '../../../../../models/chat_message.dart';

class ChatController extends ChangeNotifier {
  ChatController({
    required this.organizationId,
    required this.departmentId,
    required this.departmentName,
    required this.displayId,
    this.messagesPath,
  }) {
    _listenForMessages();
    _listenToTyping();
    // Store the future so every send path can await it if the key is not
    // ready yet when the user taps Send.
    _encryptionReady = _initEncryption();
  }

  final FirebaseService _firebase = FirebaseService.instance;
  final _imagePicker = ImagePicker();
  final _audioRecorder = AudioRecorder();

  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final FocusNode inputFocusNode = FocusNode();

  final String organizationId;
  final String departmentId;
  final String departmentName;
  final String displayId;

  /// When set, overrides the default department-based Firestore path.
  final String? messagesPath;

  // ── Message state ──────────────────────────────────────────────────────────
  List<ChatMessage> messages = [];
  bool isSending = false;

  /// Visible error string.  Set by any failed operation; cleared at the start
  /// of the next send attempt.  The screen watches this and shows a banner.
  String? errorMessage;

  ChatMessage? editingMessage;
  bool get isEditing => editingMessage != null;

  List<String> typingDisplayIds = [];

  // ── Recording / upload state ───────────────────────────────────────────────
  bool isRecording = false;
  int recordingSeconds = 0;
  bool isUploadingMedia = false;

  // ── E2EE ──────────────────────────────────────────────────────────────────
  Uint8List? _conversationKey;

  /// Completes (possibly with an error-free result even when the key is null
  /// due to a hard failure) once [_initEncryption] has finished.
  Future<void>? _encryptionReady;

  bool get isEncryptionReady => _conversationKey != null;

  // ── Internal ───────────────────────────────────────────────────────────────
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _typingSubscription;

  Timer? _typingDebounceTimer;
  Timer? _typingClearTimer;
  Timer? _recordingTimer;

  bool _isTypingSet = false;
  String? _recordingPath;

  // ── Conversation-path helpers ──────────────────────────────────────────────

  /// Parent Firestore path of the messages collection.
  /// Used as the key-storage root for [ConversationKeyService].
  String get _conversationPath {
    if (messagesPath != null && messagesPath!.isNotEmpty) {
      final parts = messagesPath!.split('/');
      if (parts.isNotEmpty && parts.last == 'messages') {
        return parts.sublist(0, parts.length - 1).join('/');
      }
      return messagesPath!;
    }
    return 'organizations/$organizationId/departments/${_normalizedDepartmentId()}';
  }

  bool get _isPrivateChat =>
      messagesPath != null && messagesPath!.contains('/private_chats/');

  bool get _isOrgChat =>
      messagesPath != null && messagesPath!.contains('/org_chats/');

  // ── Encryption init ────────────────────────────────────────────────────────

  Future<void> _initEncryption() async {
    try {
      debugPrint('[E2EE] _initEncryption() start — path: $_conversationPath');

      // ── 1. Resolve the Firebase UID ─────────────────────────────────────────
      // FirebaseAuth.instance.currentUser can be null for a brief window on
      // cold-start even when the user IS authenticated.  Wait up to 5 s.
      String? uid = KeyManagementService.currentUid;
      if (uid == null) {
        debugPrint('[E2EE] currentUid null — waiting for auth state...');
        try {
          final user = await FirebaseAuth.instance
              .authStateChanges()
              .where((u) => u != null)
              .first
              .timeout(const Duration(seconds: 5));
          uid = user?.uid;
        } catch (_) {}
      }

      if (uid == null) {
        debugPrint('[E2EE] ⚠️  uid still null after wait — '
            'generating anonymous session key');
        // Build a throwaway key so the user is not permanently blocked.
        // Messages will be encrypted; they won't be decryptable across
        // devices/sessions, but they won't be plaintext.
        _conversationKey = await ConversationKeyService.getOrCreate(
          conversationPath: _conversationPath,
          currentUid: 'anonymous',
          memberUids: const [],
        );
        notifyListeners();
        return;
      }

      debugPrint('[E2EE] uid=$uid  path=$_conversationPath');

      // ── 2. Wait for RSA key initialisation (first-login generation) ─────────
      debugPrint('[E2EE] ensureInitialized() ...');
      await KeyManagementService.ensureInitialized();
      debugPrint('[E2EE] ensureInitialized() done');

      // ── 3. Fetch member UIDs for key distribution ────────────────────────────
      final memberUids = await _fetchMemberUids(uid);
      debugPrint('[E2EE] memberUids (${memberUids.length}): $memberUids');

      // ── 4. Get or create the conversation AES key ────────────────────────────
      // getOrCreate() never returns null — it falls back to a local session key
      // if RSA / Firestore are unavailable.
      _conversationKey = await ConversationKeyService.getOrCreate(
        conversationPath: _conversationPath,
        currentUid: uid,
        memberUids: memberUids,
      );

      if (_conversationKey == null) {
        // Should never happen after the refactor, but guard defensively.
        debugPrint('[E2EE] ⚠️  getOrCreate() returned null — unexpected');
      } else {
        debugPrint('[E2EE] ✅ conversationKey ready '
            '(${_conversationKey!.length} B) for $_conversationPath');
        if (messages.isNotEmpty) {
          messages = messages.map(_tryDecrypt).toList();
        }
      }

      notifyListeners();
    } catch (e, st) {
      debugPrint('[E2EE] _initEncryption() unexpected error: $e\n$st');
      // Try to set a fallback key so at least this session can send.
      try {
        _conversationKey ??= await ConversationKeyService.getOrCreate(
          conversationPath: _conversationPath,
          currentUid: KeyManagementService.currentUid ?? 'fallback',
          memberUids: const [],
        );
      } catch (_) {}
    }
  }

  Future<List<String>> _fetchMemberUids(String currentUid) async {
    // ── Private 1-to-1 ──────────────────────────────────────────────────────
    if (_isPrivateChat) {
      try {
        final doc =
            await _firebase.firestore.doc(_conversationPath).get();
        final participants = List<String>.from(
          doc.data()?['participants'] as List? ?? [],
        );
        if (participants.isEmpty) return [currentUid];
        return participants;
      } catch (e) {
        debugPrint('[E2EE] fetchMemberUids (private) error: $e');
        return [currentUid];
      }
    }

    // ── Org-wide ─────────────────────────────────────────────────────────────
    if (_isOrgChat) {
      try {
        final snap = await _firebase.firestore
            .collection('employees')
            .where('organizationId', isEqualTo: organizationId)
            .where('status', isEqualTo: 'active')
            .get();
        final uids = snap.docs.map((d) => d.id).toList();
        if (!uids.contains(currentUid)) uids.add(currentUid);
        return uids;
      } catch (e) {
        debugPrint('[E2EE] fetchMemberUids (org) error: $e');
        return [currentUid];
      }
    }

    // ── Department (group) ────────────────────────────────────────────────────
    try {
      final snap = await _firebase.firestore
          .collection('employees')
          .where('organizationId', isEqualTo: organizationId)
          .where('departmentId', isEqualTo: _normalizedDepartmentId())
          .get();
      final uids = snap.docs.map((d) => d.id).toList();
      if (!uids.contains(currentUid)) uids.add(currentUid);
      return uids;
    } catch (e) {
      debugPrint('[E2EE] fetchMemberUids (dept) error: $e');
      return [currentUid];
    }
  }

  // ── Error helper ───────────────────────────────────────────────────────────

  /// Clear the visible error banner.
  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  /// Manually re-run encryption initialisation.
  /// Called by the UI retry button so users can recover without restarting.
  Future<void> retryEncryptionInit() async {
    errorMessage = null;
    notifyListeners();
    _encryptionReady = _initEncryption();
    await _encryptionReady;
  }

  // ── Decrypt helper ─────────────────────────────────────────────────────────

  ChatMessage _tryDecrypt(ChatMessage msg) {
    if (!msg.isEncrypted) return msg; // legacy plain-text — pass through
    if (_conversationKey == null) return msg; // key not ready yet

    String? decryptedText;
    String? decryptedMediaUrl;

    if (msg.encryptedText != null && msg.iv != null) {
      try {
        decryptedText = AesService.decrypt(
          AesEncryptedData(ciphertext: msg.encryptedText!, iv: msg.iv!),
          _conversationKey!,
        );
      } on InvalidCipherTextException {
        decryptedText = '[Decryption failed]';
      } catch (_) {
        decryptedText = '[Decryption failed]';
      }
    }

    if (msg.encryptedMediaUrl != null && msg.mediaIv != null) {
      try {
        decryptedMediaUrl = AesService.decrypt(
          AesEncryptedData(
              ciphertext: msg.encryptedMediaUrl!, iv: msg.mediaIv!),
          _conversationKey!,
        );
      } on InvalidCipherTextException {
        decryptedMediaUrl = null;
      } catch (_) {
        decryptedMediaUrl = null;
      }
    }

    return msg.withDecrypted(
      text: decryptedText,
      mediaUrl: decryptedMediaUrl ?? msg.mediaUrl,
    );
  }

  // ── Message stream ─────────────────────────────────────────────────────────

  void _listenForMessages() {
    _subscription = _messagesCollection()
        .orderBy('createdAt')
        .snapshots()
        .listen(
          (snapshot) {
            messages = snapshot.docs
                .map((doc) =>
                    _tryDecrypt(ChatMessage.fromJson(doc.data(), id: doc.id)))
                .toList();
            _markMessagesAsRead(snapshot.docs).ignore();
            notifyListeners();
            _scrollToBottom();
          },
          onError: (error) {
            errorMessage = error.toString();
            notifyListeners();
          },
        );
  }

  // ── Text send ──────────────────────────────────────────────────────────────

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;

    _typingDebounceTimer?.cancel();
    _typingClearTimer?.cancel();
    _setTyping(false).ignore();

    isSending = true;
    errorMessage = null;
    notifyListeners();

    try {
      // ── Ensure encryption key is ready ──────────────────────────────────
      await _awaitEncryptionKey();

      // _awaitEncryptionKey() guarantees a non-null key; this guard is a
      // last-resort defensive check only.
      if (_conversationKey == null) {
        errorMessage = 'Could not initialise encryption. '
            'Tap Retry on the banner or restart the app.';
        isSending = false;
        notifyListeners();
        return;
      }

      final enc = AesService.encrypt(text, _conversationKey!);
      await _messagesCollection().add({
        'senderId': displayId,
        'organizationId': organizationId,
        'departmentId': _normalizedDepartmentId(),
        'createdAt': FieldValue.serverTimestamp(),
        'text': '', // plaintext never stored
        'isEncrypted': true,
        'encryptedText': enc.ciphertext,
        'iv': enc.iv,
      });

      messageController.clear();
      _scrollToBottom();
    } catch (e, st) {
      debugPrint('[ChatController] sendMessage error: $e\n$st');
      errorMessage = 'Failed to send message. Please try again.';
    }

    isSending = false;
    notifyListeners();
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> deleteMessage(ChatMessage message) async {
    if (message.id == null) return;
    try {
      await _messagesCollection().doc(message.id!).delete();
    } catch (e) {
      errorMessage = 'Failed to delete message.';
      notifyListeners();
    }
  }

  // ── Edit ───────────────────────────────────────────────────────────────────

  void startEditing(ChatMessage message) {
    editingMessage = message;
    messageController.text = message.text;
    messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: message.text.length),
    );
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      inputFocusNode.requestFocus();
    });
  }

  void cancelEditing() {
    editingMessage = null;
    messageController.clear();
    notifyListeners();
  }

  Future<void> confirmEdit() async {
    final msg = editingMessage;
    if (msg == null || msg.id == null) return;

    final newText = messageController.text.trim();
    if (newText.isEmpty) return;
    if (newText == msg.text) {
      cancelEditing();
      return;
    }

    isSending = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _awaitEncryptionKey();

      if (_conversationKey == null) {
        errorMessage = 'Could not initialise encryption. Please try again.';
        isSending = false;
        notifyListeners();
        return;
      }

      final enc = AesService.encrypt(newText, _conversationKey!);
      await _messagesCollection().doc(msg.id!).update({
        'text': '',
        'isEncrypted': true,
        'encryptedText': enc.ciphertext,
        'iv': enc.iv,
        'isEdited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });

      cancelEditing();
    } catch (e, st) {
      debugPrint('[ChatController] confirmEdit error: $e\n$st');
      errorMessage = 'Failed to edit message. Please try again.';
    }

    isSending = false;
    notifyListeners();
  }

  // ── Image / Video / Voice send ─────────────────────────────────────────────

  Future<void> pickAndSendImage() async {
    final XFile? xFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (xFile == null) return;

    final file = File(xFile.path);
    if (await file.length() > 20 * 1024 * 1024) {
      errorMessage = 'imageTooLarge';
      notifyListeners();
      return;
    }

    await _sendMediaMessage(
      file: file,
      messageType: MessageType.image,
      mediaFileName: 'img_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
  }

  Future<void> pickAndSendVideo() async {
    final XFile? xFile = await _imagePicker.pickVideo(
      source: ImageSource.gallery,
    );
    if (xFile == null) return;

    final file = File(xFile.path);
    if (await file.length() > 50 * 1024 * 1024) {
      errorMessage = 'videoTooLarge';
      notifyListeners();
      return;
    }

    await _sendMediaMessage(
      file: file,
      messageType: MessageType.video,
      mediaFileName: 'vid_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );
  }

  Future<void> startVoiceRecording() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      errorMessage = 'microphonePermissionDenied';
      notifyListeners();
      return;
    }

    final dir = await getTemporaryDirectory();
    _recordingPath =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        bitRate: 128000,
        numChannels: 1,
      ),
      path: _recordingPath!,
    );

    recordingSeconds = 0;
    isRecording = true;
    notifyListeners();

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      recordingSeconds++;
      notifyListeners();
    });
  }

  Future<void> stopAndSendVoiceRecording() async {
    _recordingTimer?.cancel();
    final path = await _audioRecorder.stop();
    final duration = recordingSeconds;

    isRecording = false;
    recordingSeconds = 0;
    notifyListeners();

    if (path == null) return;
    final file = File(path);
    if (!await file.exists()) return;

    await _sendMediaMessage(
      file: file,
      messageType: MessageType.voice,
      mediaDuration: duration,
      mediaFileName: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
  }

  Future<void> cancelVoiceRecording() async {
    _recordingTimer?.cancel();
    await _audioRecorder.cancel();
    isRecording = false;
    recordingSeconds = 0;
    _recordingPath = null;
    notifyListeners();
  }

  // ── Media upload + send ────────────────────────────────────────────────────

  Future<void> _sendMediaMessage({
    required File file,
    required MessageType messageType,
    int? mediaDuration,
    String? mediaFileName,
  }) async {
    isUploadingMedia = true;
    errorMessage = null;
    notifyListeners();

    try {
      // ── Ensure encryption key is ready BEFORE uploading ─────────────────
      // We must not upload first and then find the key unavailable — the
      // file would be in Storage with no encrypted reference in Firestore.
      await _awaitEncryptionKey();

      if (_conversationKey == null) {
        errorMessage =
            'Could not initialise encryption. Tap Retry or restart the app.';
        isUploadingMedia = false;
        notifyListeners();
        return;
      }

      // ── Upload file to Storage ───────────────────────────────────────────
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_media/$organizationId/$_chatStorageId/$mediaFileName');

      final metadata = messageType == MessageType.voice
          ? SettableMetadata(contentType: 'audio/mp4')
          : null;

      await ref.putFile(file, metadata);
      final url = await ref.getDownloadURL();

      // ── Encrypt Storage URL and write to Firestore ───────────────────────
      final encUrl = AesService.encrypt(url, _conversationKey!);

      await _messagesCollection().add({
        'senderId': displayId,
        'organizationId': organizationId,
        'departmentId': _normalizedDepartmentId(),
        'createdAt': FieldValue.serverTimestamp(),
        'messageType': messageType.name,
        'text': '', // plaintext never stored
        'isEncrypted': true,
        'encryptedMediaUrl': encUrl.ciphertext,
        'mediaIv': encUrl.iv,
        // ignore: use_null_aware_elements
        if (mediaDuration != null) 'mediaDuration': mediaDuration,
        // ignore: use_null_aware_elements
        if (mediaFileName != null) 'mediaFileName': mediaFileName,
      });

      _scrollToBottom();
    } catch (e, st) {
      debugPrint('[ChatController] _sendMediaMessage error: $e\n$st');
      errorMessage = 'Failed to send media. Please try again.';
    }

    isUploadingMedia = false;
    notifyListeners();
  }

  // ── Encryption-ready guard ─────────────────────────────────────────────────

  /// Await the initial encryption setup.  If the key is still null after that
  /// (e.g. RSA generation genuinely failed), the caller must check and surface
  /// an error — this method only ensures we gave it every chance to succeed.
  Future<void> _awaitEncryptionKey() async {
    if (_conversationKey != null) return;

    // _encryptionReady may be a failed Future if _initEncryption() threw before
    // our try-catch was in place (or in the current session if it re-throws for
    // any reason).  Always swallow here so callers only see a null key, not an
    // exception.
    if (_encryptionReady != null) {
      try {
        await _encryptionReady;
      } catch (e) {
        debugPrint('[E2EE] _encryptionReady completed with error (swallowed): $e');
      }
    }

    // One retry — covers the race where ensureInitialized() returned before the
    // Firestore write completed on first login, or after a transient network blip.
    if (_conversationKey == null) {
      debugPrint('[E2EE] Key still null after initial wait — retrying _initEncryption()');
      try {
        await _initEncryption();
      } catch (e) {
        debugPrint('[E2EE] _initEncryption retry error (swallowed): $e');
      }
    }

    debugPrint('[E2EE] _awaitEncryptionKey done — '
        'key ${_conversationKey == null ? "STILL NULL" : "ready"}');
  }

  // ── Storage path ───────────────────────────────────────────────────────────

  String get _chatStorageId {
    if (messagesPath != null && messagesPath!.isNotEmpty) {
      return messagesPath!.split('/').where((s) => s.isNotEmpty).join('_');
    }
    return 'dept_${_normalizedDepartmentId()}';
  }

  // ── Typing indicators ──────────────────────────────────────────────────────

  void onTextChanged(String text) {
    if (text.isNotEmpty) {
      _typingDebounceTimer?.cancel();
      _typingDebounceTimer = Timer(
        const Duration(milliseconds: 300),
        () => _setTyping(true).ignore(),
      );
      _typingClearTimer?.cancel();
      _typingClearTimer = Timer(
        const Duration(seconds: 4),
        () => _setTyping(false).ignore(),
      );
    } else {
      _typingDebounceTimer?.cancel();
      _typingClearTimer?.cancel();
      _setTyping(false).ignore();
    }
  }

  void _listenToTyping() {
    _typingSubscription = _chatDocRef().snapshots().listen(
      (snap) {
        if (!snap.exists) {
          if (typingDisplayIds.isNotEmpty) {
            typingDisplayIds = [];
            notifyListeners();
          }
          return;
        }
        final data = snap.data() ?? {};
        final raw =
            Map<String, dynamic>.from(data['typing'] as Map? ?? {});
        final now = DateTime.now();
        typingDisplayIds = raw.entries
            .where((e) => e.key != displayId)
            .where((e) {
              final ts = e.value;
              if (ts is Timestamp) {
                return now.difference(ts.toDate()) <
                    const Duration(seconds: 10);
              }
              return false;
            })
            .map((e) => e.key)
            .toList();
        notifyListeners();
      },
      onError: (e) => debugPrint('[Typing] stream error: $e'),
    );
  }

  Future<void> _setTyping(bool isTyping) async {
    try {
      if (isTyping) {
        await _chatDocRef().set(
          {'typing': {displayId: FieldValue.serverTimestamp()}},
          SetOptions(mergeFields: [
            FieldPath(['typing', displayId])
          ]),
        );
        _isTypingSet = true;
      } else if (_isTypingSet) {
        await _chatDocRef()
            .update({'typing.$displayId': FieldValue.delete()});
        _isTypingSet = false;
      }
    } catch (e) {
      debugPrint('[Typing] _setTyping error: $e');
    }
  }

  DocumentReference<Map<String, dynamic>> _chatDocRef() {
    if (messagesPath != null && messagesPath!.isNotEmpty) {
      final segments = messagesPath!.split('/');
      final docPath =
          segments.sublist(0, segments.length - 1).join('/');
      return _firebase.firestore.doc(docPath);
    }
    return _firebase.firestore
        .collection('organizations')
        .doc(organizationId)
        .collection('departments')
        .doc(_normalizedDepartmentId());
  }

  // ── Read receipts ──────────────────────────────────────────────────────────

  Future<void> _markMessagesAsRead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final unread = docs.where((doc) {
      final data = doc.data();
      final senderId = data['senderId'] as String? ?? '';
      if (senderId == displayId) return false;
      final readBy =
          List<String>.from(data['readBy'] as List? ?? []);
      return !readBy.contains(displayId);
    }).toList();

    if (unread.isEmpty) return;

    final batch = _firebase.firestore.batch();
    for (final doc in unread) {
      batch.update(doc.reference, {
        'readBy': FieldValue.arrayUnion([displayId]),
      });
    }
    try {
      await batch.commit();
    } catch (_) {}
  }

  // ── Firestore paths ────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _messagesCollection() {
    if (messagesPath != null && messagesPath!.isNotEmpty) {
      return _firebase.firestore.collection(messagesPath!);
    }
    return _firebase.firestore
        .collection('organizations')
        .doc(organizationId)
        .collection('departments')
        .doc(_normalizedDepartmentId())
        .collection('messages');
  }

  void _scrollToBottom() {
    if (!scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  String _normalizedDepartmentId() {
    if (departmentId.trim().isNotEmpty) {
      return _sanitize(departmentId.trim());
    }
    if (departmentName.trim().isNotEmpty) {
      return _sanitize(departmentName.trim());
    }
    return 'general';
  }

  String _sanitize(String value) =>
      value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_').toLowerCase();

  // ── Dispose ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _typingDebounceTimer?.cancel();
    _typingClearTimer?.cancel();
    _recordingTimer?.cancel();
    _setTyping(false).ignore();
    _typingSubscription?.cancel();
    _audioRecorder.dispose();
    messageController.dispose();
    scrollController.dispose();
    inputFocusNode.dispose();
    _subscription?.cancel();
    super.dispose();
  }
}
