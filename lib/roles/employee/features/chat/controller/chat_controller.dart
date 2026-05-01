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
    // Fire-and-forget: loads the AES session key in the background.
    // Messages received before the key is ready display as [Encrypted].
    _initEncryption();
  }

  final FirebaseService _firebase = FirebaseService.instance;
  final _imagePicker = ImagePicker();
  final _audioRecorder = AudioRecorder();

  // Exposed so _InputBar can attach it to the TextField for auto-focus.
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
  String? errorMessage;

  ChatMessage? editingMessage;
  bool get isEditing => editingMessage != null;

  List<String> typingDisplayIds = [];

  // ── Recording state ────────────────────────────────────────────────────────
  bool isRecording = false;
  int recordingSeconds = 0;

  // ── Upload state ───────────────────────────────────────────────────────────
  bool isUploadingMedia = false;

  // ── E2EE ──────────────────────────────────────────────────────────────────
  Uint8List? _conversationKey;

  /// True once the conversation key has been fetched / generated.
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

  // ── Encryption init ────────────────────────────────────────────────────────

  Future<void> _initEncryption() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _conversationKey = await ConversationKeyService.getOrCreate(
      organizationId: organizationId,
      normalizedDepartmentId: _normalizedDepartmentId(),
      currentUid: uid,
    );

    if (_conversationKey != null && messages.isNotEmpty) {
      // Re-decrypt messages that arrived before the key was ready.
      messages = messages.map(_tryDecrypt).toList();
    }
    notifyListeners();
  }

  // ── Message stream ─────────────────────────────────────────────────────────

  void _listenForMessages() {
    debugPrint('OrgId: $organizationId');
    debugPrint('DeptId: $departmentId');

    _subscription = _messagesCollection()
        .orderBy('createdAt')
        .snapshots()
        .listen(
          (snapshot) {
            messages = snapshot.docs
                .map((doc) =>
                    _tryDecrypt(ChatMessage.fromJson(doc.data(), id: doc.id)))
                .toList();
            debugPrint('Messages count: ${messages.length}');
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

  // ── Decrypt helper ─────────────────────────────────────────────────────────

  /// Attempt to decrypt [msg] using the current conversation key.
  ///
  /// Returns the original message unchanged if:
  ///   • the message is not encrypted (legacy plain-text message), or
  ///   • no conversation key is available yet.
  ///
  /// Returns a copy with `text = '[Encrypted message]'` on auth-tag failure
  /// (tampered data or key mismatch).
  ChatMessage _tryDecrypt(ChatMessage msg) {
    if (!msg.isEncrypted) return msg; // plain-text (legacy) message
    if (_conversationKey == null) return msg; // key not ready yet

    String? decryptedText;
    String? decryptedMediaUrl;

    // Decrypt message body
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

    // Decrypt media URL (if present)
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
      final payload = _buildTextPayload(text);
      await _messagesCollection().add(payload);
      messageController.clear();
      _scrollToBottom();
    } catch (e) {
      errorMessage = e.toString();
    }

    isSending = false;
    notifyListeners();
  }

  Map<String, dynamic> _buildTextPayload(String plaintext) {
    final base = {
      'senderId': displayId,
      'organizationId': organizationId,
      'departmentId': _normalizedDepartmentId(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (_conversationKey != null) {
      final enc = AesService.encrypt(plaintext, _conversationKey!);
      return {
        ...base,
        'text': '', // do not store plaintext in Firestore
        'isEncrypted': true,
        'encryptedText': enc.ciphertext,
        'iv': enc.iv,
      };
    }

    // Fallback: no key available (should not happen in normal flow).
    debugPrint('[E2EE] ⚠️  Sending unencrypted — conversation key not ready');
    return {...base, 'text': plaintext};
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> deleteMessage(ChatMessage message) async {
    if (message.id == null) return;
    try {
      await _messagesCollection().doc(message.id!).delete();
    } catch (e) {
      errorMessage = e.toString();
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
    notifyListeners();

    try {
      Map<String, dynamic> update = {
        'isEdited': true,
        'editedAt': FieldValue.serverTimestamp(),
      };

      if (_conversationKey != null) {
        final enc = AesService.encrypt(newText, _conversationKey!);
        update.addAll({
          'text': '',
          'isEncrypted': true,
          'encryptedText': enc.ciphertext,
          'iv': enc.iv,
        });
      } else {
        update['text'] = newText;
      }

      await _messagesCollection().doc(msg.id!).update(update);
      cancelEditing();
    } catch (e) {
      errorMessage = e.toString();
    }

    isSending = false;
    notifyListeners();
  }

  // ── Image send ─────────────────────────────────────────────────────────────

  Future<void> pickAndSendImage() async {
    final XFile? xFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (xFile == null) return;

    final file = File(xFile.path);
    final sizeBytes = await file.length();
    if (sizeBytes > 20 * 1024 * 1024) {
      errorMessage = 'imageTooLarge';
      notifyListeners();
      return;
    }

    final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _sendMediaMessage(
      file: file,
      messageType: MessageType.image,
      mediaFileName: fileName,
    );
  }

  // ── Video send ─────────────────────────────────────────────────────────────

  Future<void> pickAndSendVideo() async {
    final XFile? xFile = await _imagePicker.pickVideo(
      source: ImageSource.gallery,
    );
    if (xFile == null) return;

    final file = File(xFile.path);
    final sizeBytes = await file.length();
    if (sizeBytes > 50 * 1024 * 1024) {
      errorMessage = 'videoTooLarge';
      notifyListeners();
      return;
    }

    final fileName = 'vid_${DateTime.now().millisecondsSinceEpoch}.mp4';
    await _sendMediaMessage(
      file: file,
      messageType: MessageType.video,
      mediaFileName: fileName,
    );
  }

  // ── Voice recording ────────────────────────────────────────────────────────

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

    final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _sendMediaMessage(
      file: file,
      messageType: MessageType.voice,
      mediaDuration: duration,
      mediaFileName: fileName,
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
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_media/$organizationId/$_chatStorageId/$mediaFileName');

      final metadata = messageType == MessageType.voice
          ? SettableMetadata(contentType: 'audio/mp4')
          : null;
      await ref.putFile(file, metadata);
      final url = await ref.getDownloadURL();

      final base = {
        'senderId': displayId,
        'organizationId': organizationId,
        'departmentId': _normalizedDepartmentId(),
        'createdAt': FieldValue.serverTimestamp(),
        'messageType': messageType.name,
        if (mediaDuration != null) 'mediaDuration': mediaDuration,
        if (mediaFileName != null) 'mediaFileName': mediaFileName,
      };

      if (_conversationKey != null) {
        // Encrypt the Storage download URL so Firebase never sees it.
        final encUrl = AesService.encrypt(url, _conversationKey!);
        await _messagesCollection().add({
          ...base,
          'text': '',
          'isEncrypted': true,
          'encryptedMediaUrl': encUrl.ciphertext,
          'mediaIv': encUrl.iv,
        });
      } else {
        debugPrint('[E2EE] ⚠️  Sending media URL unencrypted');
        await _messagesCollection()
            .add({...base, 'text': '', 'mediaUrl': url});
      }

      _scrollToBottom();
    } catch (e) {
      errorMessage = e.toString();
    }

    isUploadingMedia = false;
    notifyListeners();
  }

  String get _chatStorageId {
    if (messagesPath != null && messagesPath!.isNotEmpty) {
      return messagesPath!.split('/').where((s) => s.isNotEmpty).join('_');
    }
    return 'dept_${_normalizedDepartmentId()}';
  }

  // ── Typing indicators ──────────────────────────────────────────────────────

  void onTextChanged(String text) {
    debugPrint('[Typing] onTextChanged: "${text.length} chars"');
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
    debugPrint(
        '[Typing] _listenToTyping() started for doc: ${_chatDocRef().path}');
    _typingSubscription = _chatDocRef().snapshots().listen(
      (snap) {
        if (!snap.exists) {
          debugPrint('[Typing] chat doc does not exist');
          if (typingDisplayIds.isNotEmpty) {
            typingDisplayIds = [];
            notifyListeners();
          }
          return;
        }
        final data = snap.data() ?? {};
        final raw =
            Map<String, dynamic>.from(data['typing'] as Map? ?? {});
        debugPrint('[Typing] raw typing map: $raw');
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
        debugPrint('[Typing] typingDisplayIds: $typingDisplayIds');
        notifyListeners();
      },
      onError: (e) {
        debugPrint('[Typing] stream error: $e');
      },
    );
  }

  Future<void> _setTyping(bool isTyping) async {
    try {
      if (isTyping) {
        debugPrint('[Typing] setting typing=true for $displayId');
        await _chatDocRef().set(
          {
            'typing': {displayId: FieldValue.serverTimestamp()},
          },
          SetOptions(mergeFields: [
            FieldPath(['typing', displayId])
          ]),
        );
        _isTypingSet = true;
      } else if (_isTypingSet) {
        debugPrint('[Typing] clearing typing for $displayId');
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
      final readBy = List<String>.from(data['readBy'] as List? ?? []);
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

  String _sanitize(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return cleaned.toLowerCase();
  }

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
