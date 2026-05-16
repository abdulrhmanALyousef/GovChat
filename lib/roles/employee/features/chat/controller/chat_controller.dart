import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart'
    show SecretBoxAuthenticationError;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../../core/datasource/remote_data/firebase_service.dart';
import '../../../../../core/services/encryption/e2ee_crypto.dart';
import '../../../../../core/services/encryption/e2ee_manager.dart';
import '../../../../../core/services/logging_service.dart';
import '../../../../../core/services/push_notification_service.dart';
import '../../../../../models/chat_message.dart';

class ChatController extends ChangeNotifier {
  ChatController({
    required this.organizationId,
    required this.departmentId,
    required this.departmentName,
    required this.displayId,
    required this.employeeUid,
    this.messagesPath,
  }) {
    _listenForMessages();
    _listenToTyping();
    _listenToEmployeeProfiles();
    _listenToOrgSettings();
    // Store the future so every send path can await it if the key is not
    // ready yet when the user taps Send.
    _encryptionReady = _initEncryption();
    // Mark this conversation as active so foreground FCM notifications for
    // it are suppressed while the user is already viewing it.
    PushNotificationService.activeConversationPath = _activeMessagesPath;
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
  final String employeeUid;

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

  // ── Org settings ───────────────────────────────────────────────────────────
  bool mediaSharingEnabled = true;

  // ── E2EE ──────────────────────────────────────────────────────────────────
  Uint8List? _conversationKey;

  /// Completes once [_initEncryption] has finished.
  Future<void>? _encryptionReady;

  bool get isEncryptionReady => _conversationKey != null;

  // ── Internal ───────────────────────────────────────────────────────────────
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _typingSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _keyDocSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _orgSettingsSubscription;

  Timer? _typingDebounceTimer;
  Timer? _typingClearTimer;
  Timer? _recordingTimer;

  bool _isTypingSet = false;
  String? _recordingPath;

  // ── Live employee profile cache ───────────────────────────────────────────
  /// Maps employee UID → {name, avatarUrl, displayId}.
  final Map<String, Map<String, String>> _profileCache = {};

  /// Current employee's display name for audit logs.
  String get _currentEmployeeName => _profileCache[employeeUid]?['name'] ?? displayId;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _profilesSubscription;

  /// Look up a sender's current profile info. Falls back gracefully for
  /// messages sent before senderUid was stored.
  ({String name, String avatarUrl}) getSenderProfile(
    String? senderUid,
    String senderId,
  ) {
    // Try by UID first (new messages).
    if (senderUid != null && _profileCache.containsKey(senderUid)) {
      final p = _profileCache[senderUid]!;
      return (name: p['name'] ?? senderId, avatarUrl: p['avatarUrl'] ?? '');
    }
    // Fall back to displayId match (old messages).
    for (final entry in _profileCache.values) {
      if (entry['displayId'] == senderId) {
        return (
          name: entry['name'] ?? senderId,
          avatarUrl: entry['avatarUrl'] ?? '',
        );
      }
    }
    return (name: senderId, avatarUrl: '');
  }

  void _listenToOrgSettings() {
    _orgSettingsSubscription = _firebase.firestore
        .collection('organizations')
        .doc(organizationId)
        .collection('settings')
        .doc('chat')
        .snapshots()
        .listen(
          (snap) {
            final enabled = snap.exists
                ? (snap.data()?['mediaSharingEnabled'] as bool?) ?? true
                : true;
            if (enabled != mediaSharingEnabled) {
              mediaSharingEnabled = enabled;
              notifyListeners();
            }
          },
          onError: (_) {},
        );
  }

  void _listenToEmployeeProfiles() {
    _profilesSubscription = _firebase.firestore
        .collection('employees')
        .where('organizationId', isEqualTo: organizationId)
        .snapshots()
        .listen((snapshot) {
          for (final doc in snapshot.docs) {
            final data = doc.data();
            _profileCache[doc.id] = {
              'name': (data['name'] as String?) ?? '',
              'avatarUrl': (data['avatarUrl'] as String?) ?? '',
              'displayId': (data['displayId'] as String?) ?? '',
            };
          }
          notifyListeners();
        }, onError: (_) {});
  }

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
      String? uid = E2eeManager.currentUid;
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
        debugPrint('[E2EE] uid still null — cannot init encryption');
        errorMessage = 'Authentication required for encryption.';
        notifyListeners();
        return;
      }

      debugPrint('[E2EE] uid=$uid  path=$_conversationPath');

      // ── 2. Wait for X25519 key initialisation ───────────────────────────────
      await E2eeManager.ensureInitialized();

      // ── 3. Fetch member UIDs ────────────────────────────────────────────────
      final memberUids = await _fetchMemberUids(uid);
      debugPrint('[E2EE] memberUids (${memberUids.length}): $memberUids');

      // ── 4. Get the conversation AES key ─────────────────────────────────────
      _conversationKey = await E2eeManager.getConversationKey(
        conversationPath: _conversationPath,
        currentUid: uid,
        memberUids: memberUids,
        isPrivateChat: _isPrivateChat,
      );

      if (_conversationKey == null) {
        debugPrint(
          '[E2EE] no conversation key for $uid — '
          'listening for group key distribution',
        );
        _listenForKeyDoc(uid);
        errorMessage =
            'Waiting for encryption key. '
            'Ask the conversation starter to re-open this chat, '
            'then tap Retry.';
      } else {
        debugPrint(
          '[E2EE] conversation key ready '
          '(${_conversationKey!.length} B)',
        );
        if (errorMessage?.contains('Waiting for encryption key') == true) {
          errorMessage = null;
        }
        if (messages.isNotEmpty) {
          debugPrint(
            '[E2EE] re-decrypting ${messages.length} buffered '
            'messages',
          );
          messages = await Future.wait(messages.map(_tryDecrypt));
        }
      }

      notifyListeners();
    } catch (e, st) {
      debugPrint('[E2EE] _initEncryption() error: $e\n$st');
    }
  }

  Future<List<String>> _fetchMemberUids(String currentUid) async {
    // ── Private 1-to-1 ──────────────────────────────────────────────────────
    if (_isPrivateChat) {
      try {
        final doc = await _firebase.firestore.doc(_conversationPath).get();
        final participants = List<String>.from(
          doc.data()?['participants'] as List? ?? [],
        );
        debugPrint('[E2EE] private chat participants: $participants');
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
        debugPrint('[E2EE] org members (${uids.length}): $uids');
        return uids;
      } catch (e) {
        debugPrint('[E2EE] fetchMemberUids (org) error: $e');
        return [currentUid];
      }
    }

    // ── Department (group) ────────────────────────────────────────────────────
    // Strategy 1: composite index query (departmentId exact match).
    // Strategy 2: org-level query + client-side filter (fallback when the
    //   composite index is missing or the stored departmentId uses different
    //   casing/formatting than our normalized version).
    final normalizedId = _normalizedDepartmentId();
    debugPrint(
      '[E2EE] fetching dept members for deptId=$normalizedId '
      'org=$organizationId',
    );

    try {
      final snap = await _firebase.firestore
          .collection('employees')
          .where('organizationId', isEqualTo: organizationId)
          .where('departmentId', isEqualTo: normalizedId)
          .get();

      if (snap.docs.isNotEmpty) {
        final uids = snap.docs.map((d) => d.id).toList();
        if (!uids.contains(currentUid)) uids.add(currentUid);
        debugPrint('[E2EE] dept members via index (${uids.length}): $uids');
        return uids;
      }

      // Index query returned zero results — might be a format mismatch.
      debugPrint(
        '[E2EE] composite query returned 0 results — '
        'trying org-level fallback',
      );
    } catch (e) {
      // FAILED_PRECONDITION → composite index doesn't exist yet.
      // Any other error → Firestore unavailable.
      debugPrint('[E2EE] composite dept query error: $e — using fallback');
    }

    // Fallback: fetch all org employees, filter client-side by department.
    // This avoids the missing-index problem and handles casing differences.
    try {
      final allSnap = await _firebase.firestore
          .collection('employees')
          .where('organizationId', isEqualTo: organizationId)
          .get();

      final uids = allSnap.docs
          .where((doc) {
            final data = doc.data();
            final storedDeptId = _sanitize(
              (data['departmentId'] as String? ?? '').trim(),
            );
            final storedDeptName = _sanitize(
              (data['department'] as String? ?? '').trim(),
            );
            return storedDeptId == normalizedId ||
                storedDeptName == normalizedId ||
                storedDeptId == _sanitize(departmentId.trim()) ||
                storedDeptName == _sanitize(departmentName.trim());
          })
          .map((d) => d.id)
          .toList();

      if (!uids.contains(currentUid)) uids.add(currentUid);
      debugPrint('[E2EE] dept members via fallback (${uids.length}): $uids');
      return uids;
    } catch (e) {
      debugPrint('[E2EE] fetchMemberUids (dept fallback) error: $e');
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

  // ── Key doc listener ────────────────────────────────────────────────────────

  /// Listen on the current user's group key doc in Firestore.
  /// When the key creator distributes, the doc appears and we can
  /// automatically decrypt without the user tapping Retry.
  void _listenForKeyDoc(String uid) {
    _keyDocSubscription?.cancel();
    _keyDocSubscription = _firebase.firestore
        .doc('$_conversationPath/groupKey/$uid')
        .snapshots()
        .listen((snap) {
          if (snap.exists && _conversationKey == null) {
            debugPrint(
              '[E2EE] group key doc appeared for $uid — re-initialising',
            );
            _keyDocSubscription?.cancel();
            _keyDocSubscription = null;
            _encryptionReady = _initEncryption();
          }
        });
  }

  // ── Decrypt helper ─────────────────────────────────────────────────────────

  Future<ChatMessage> _tryDecrypt(ChatMessage msg) async {
    if (!msg.isEncrypted) return msg;

    if (_conversationKey == null) {
      debugPrint('[E2EE][decrypt] key NULL — skipping msg ${msg.id}');
      return msg;
    }

    String? decryptedText;
    String? decryptedMediaUrl;

    if (msg.encryptedText != null && msg.iv != null) {
      try {
        decryptedText = await E2eeManager.decryptMessage(
          EncryptedPayload(ciphertext: msg.encryptedText!, nonce: msg.iv!),
          _conversationKey!,
        );
      } on SecretBoxAuthenticationError catch (e) {
        debugPrint('[E2EE][decrypt] wrong key for msg=${msg.id}: $e');
        decryptedText = '[Decryption error: wrong key or corrupted data]';
      } catch (e) {
        debugPrint('[E2EE][decrypt] error for msg=${msg.id}: $e');
        decryptedText = '[Decryption error: $e]';
      }
    }

    if (msg.encryptedMediaUrl != null && msg.mediaIv != null) {
      try {
        decryptedMediaUrl = await E2eeManager.decryptMessage(
          EncryptedPayload(
            ciphertext: msg.encryptedMediaUrl!,
            nonce: msg.mediaIv!,
          ),
          _conversationKey!,
        );
      } catch (e) {
        debugPrint('[E2EE][decrypt] media decrypt error for msg=${msg.id}: $e');
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
          (snapshot) async {
            final rawMessages = snapshot.docs
                .map((doc) => ChatMessage.fromJson(doc.data(), id: doc.id))
                .where((m) => !m.isDeleted)
                .toList();

            if (_conversationKey != null) {
              messages = await Future.wait(rawMessages.map(_tryDecrypt));
            } else {
              messages = rawMessages;
            }

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
        errorMessage =
            'Could not initialise encryption. '
            'Tap Retry on the banner or restart the app.';
        isSending = false;
        notifyListeners();
        return;
      }

      final enc = await E2eeManager.encryptMessage(text, _conversationKey!);
      final ref = await _messagesCollection().add({
        'senderId': displayId,
        'senderUid': employeeUid,
        'organizationId': organizationId,
        'departmentId': _normalizedDepartmentId(),
        'createdAt': FieldValue.serverTimestamp(),
        'text': '',
        'isEncrypted': true,
        'encryptedText': enc.ciphertext,
        'iv': enc.nonce,
      });

      LoggingService.instance.log(
        organizationId: organizationId,
        actionType: 'message_sent',
        performedByUserId: _firebase.currentUser?.uid ?? displayId,
        performedByRole: 'employee',
        performedByEmail: _firebase.currentUser?.email ?? '',
        performedByName: _currentEmployeeName,
        performedByEmployeeId: displayId,
        performedByDepartmentId: _normalizedDepartmentId(),
        targetId: ref.id,
        targetType: 'message',
        metadata: {
          'chatType': _detectChatType(),
          'departmentId': _normalizedDepartmentId(),
          'departmentName': departmentName,
          'messagePreview': text.length > 120 ? '${text.substring(0, 120)}…' : text,
        },
      );

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
      final uid = _firebase.currentUser?.uid ?? displayId;
      await _messagesCollection().doc(message.id!).update({
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': uid,
      });

      // Determine the content to log. message.text is already decrypted
      // when _conversationKey is available; empty for media-only messages.
      String deletedContent;
      if (message.text.isNotEmpty) {
        deletedContent = message.text.length > 200
            ? '${message.text.substring(0, 200)}…'
            : message.text;
      } else if (message.mediaUrl != null && message.mediaUrl!.isNotEmpty) {
        deletedContent = '[${message.messageType.name} message]';
      } else {
        deletedContent = '[Encrypted — key unavailable at deletion time]';
      }

      LoggingService.instance.log(
        organizationId: organizationId,
        actionType: 'message_deleted',
        performedByUserId: uid,
        performedByRole: 'employee',
        performedByEmail: _firebase.currentUser?.email ?? '',
        performedByName: _currentEmployeeName,
        performedByEmployeeId: displayId,
        performedByDepartmentId: _normalizedDepartmentId(),
        targetId: message.id,
        targetType: 'message',
        metadata: {
          'chatType': _detectChatType(),
          'departmentId': _normalizedDepartmentId(),
          'departmentName': departmentName,
          'messageId': message.id,
          'senderId': message.senderId,
          'senderName': getSenderProfile(message.senderUid, message.senderId).name,
          'deletedContent': deletedContent,
          'messageType': message.messageType.name,
        },
      ).ignore();
    } catch (e) {
      errorMessage = 'Failed to delete message.';
      notifyListeners();
    }
  }

  String _detectChatType() {
    if (messagesPath == null || messagesPath!.isEmpty) return 'department';
    if (messagesPath!.contains('private_chats')) return 'private';
    if (messagesPath!.contains('org_chats')) return 'organization';
    return 'department';
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

      final oldText = msg.text;
      final enc = await E2eeManager.encryptMessage(newText, _conversationKey!);
      await _messagesCollection().doc(msg.id!).update({
        'text': '',
        'isEncrypted': true,
        'encryptedText': enc.ciphertext,
        'iv': enc.nonce,
        'isEdited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });

      LoggingService.instance.log(
        organizationId: organizationId,
        actionType: 'message_edited',
        performedByUserId: _firebase.currentUser?.uid ?? displayId,
        performedByRole: 'employee',
        performedByEmail: _firebase.currentUser?.email ?? '',
        performedByName: _currentEmployeeName,
        performedByEmployeeId: displayId,
        performedByDepartmentId: _normalizedDepartmentId(),
        targetId: msg.id,
        targetType: 'message',
        metadata: {
          'chatType': _detectChatType(),
          'departmentId': _normalizedDepartmentId(),
          'departmentName': departmentName,
          'messageId': msg.id,
          'oldValue': oldText.length > 200 ? '${oldText.substring(0, 200)}…' : oldText,
          'newValue': newText.length > 200 ? '${newText.substring(0, 200)}…' : newText,
        },
      ).ignore();

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
    await _pickAndSendImage(ImageSource.gallery);
  }

  Future<void> captureAndSendImage() async {
    await _pickAndSendImage(ImageSource.camera);
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    if (!mediaSharingEnabled) {
      errorMessage = 'Media sharing is disabled by your organization administrator.';
      notifyListeners();
      return;
    }
    final XFile? xFile = await _imagePicker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1920,
      maxHeight: 1920,
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
    await _pickAndSendVideo(ImageSource.gallery);
  }

  Future<void> captureAndSendVideo() async {
    await _pickAndSendVideo(ImageSource.camera);
  }

  Future<void> _pickAndSendVideo(ImageSource source) async {
    if (!mediaSharingEnabled) {
      errorMessage = 'Media sharing is disabled by your organization administrator.';
      notifyListeners();
      return;
    }
    final XFile? xFile = await _imagePicker.pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 5),
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
    if (!mediaSharingEnabled) {
      errorMessage = 'Media sharing is disabled by your organization administrator.';
      notifyListeners();
      return;
    }
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
      final ref = FirebaseStorage.instance.ref().child(
        'chat_media/$organizationId/$_chatStorageId/$mediaFileName',
      );

      final metadata = messageType == MessageType.voice
          ? SettableMetadata(contentType: 'audio/mp4')
          : null;

      await ref.putFile(file, metadata);
      final url = await ref.getDownloadURL();

      // ── Encrypt Storage URL and write to Firestore ───────────────────────
      final encUrl = await E2eeManager.encryptMessage(url, _conversationKey!);

      final mediaRef = await _messagesCollection().add({
        'senderId': displayId,
        'senderUid': employeeUid,
        'organizationId': organizationId,
        'departmentId': _normalizedDepartmentId(),
        'createdAt': FieldValue.serverTimestamp(),
        'messageType': messageType.name,
        'text': '',
        'isEncrypted': true,
        'encryptedMediaUrl': encUrl.ciphertext,
        'mediaIv': encUrl.nonce,
        // ignore: use_null_aware_elements
        if (mediaDuration != null) 'mediaDuration': mediaDuration,
        // ignore: use_null_aware_elements
        if (mediaFileName != null) 'mediaFileName': mediaFileName,
      });

      LoggingService.instance.log(
        organizationId: organizationId,
        actionType: 'media_uploaded',
        performedByUserId: _firebase.currentUser?.uid ?? displayId,
        performedByRole: 'employee',
        performedByEmail: _firebase.currentUser?.email ?? '',
        performedByName: _currentEmployeeName,
        performedByEmployeeId: displayId,
        performedByDepartmentId: _normalizedDepartmentId(),
        targetId: mediaRef.id,
        targetType: 'message',
        metadata: {
          'chatType': _detectChatType(),
          'departmentId': _normalizedDepartmentId(),
          'departmentName': departmentName,
          'mediaType': messageType.name,
          // ignore: use_null_aware_elements
          if (mediaDuration != null) 'mediaDuration': mediaDuration,
        },
      ).ignore();

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
        debugPrint(
          '[E2EE] _encryptionReady completed with error (swallowed): $e',
        );
      }
    }

    // One retry — covers the race where ensureInitialized() returned before the
    // Firestore write completed on first login, or after a transient network blip.
    if (_conversationKey == null) {
      debugPrint(
        '[E2EE] Key still null after initial wait — retrying _initEncryption()',
      );
      try {
        await _initEncryption();
      } catch (e) {
        debugPrint('[E2EE] _initEncryption retry error (swallowed): $e');
      }
    }

    debugPrint(
      '[E2EE] _awaitEncryptionKey done — '
      'key ${_conversationKey == null ? "STILL NULL" : "ready"}',
    );
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
    _typingSubscription = _chatDocRef().snapshots().listen((snap) {
      if (!snap.exists) {
        if (typingDisplayIds.isNotEmpty) {
          typingDisplayIds = [];
          notifyListeners();
        }
        return;
      }
      final data = snap.data() ?? {};
      final raw = Map<String, dynamic>.from(data['typing'] as Map? ?? {});
      final now = DateTime.now();
      typingDisplayIds = raw.entries
          .where((e) => e.key != displayId)
          .where((e) {
            final ts = e.value;
            if (ts is Timestamp) {
              return now.difference(ts.toDate()) < const Duration(seconds: 10);
            }
            return false;
          })
          .map((e) => e.key)
          .toList();
      notifyListeners();
    }, onError: (e) => debugPrint('[Typing] stream error: $e'));
  }

  Future<void> _setTyping(bool isTyping) async {
    try {
      if (isTyping) {
        await _chatDocRef().set(
          {
            'typing': {displayId: FieldValue.serverTimestamp()},
          },
          SetOptions(
            mergeFields: [
              FieldPath(['typing', displayId]),
            ],
          ),
        );
        _isTypingSet = true;
      } else if (_isTypingSet) {
        await _chatDocRef().update({'typing.$displayId': FieldValue.delete()});
        _isTypingSet = false;
      }
    } catch (e) {
      debugPrint('[Typing] _setTyping error: $e');
    }
  }

  DocumentReference<Map<String, dynamic>> _chatDocRef() {
    if (messagesPath != null && messagesPath!.isNotEmpty) {
      final segments = messagesPath!.split('/');
      final docPath = segments.sublist(0, segments.length - 1).join('/');
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

  String _sanitize(String value) =>
      value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_').toLowerCase();

  /// The Firestore path for the messages collection in this conversation.
  /// Used by [PushNotificationService] to suppress foreground notifications
  /// when the user is already viewing this chat.
  String get _activeMessagesPath {
    if (messagesPath != null && messagesPath!.isNotEmpty) {
      return messagesPath!;
    }
    return 'organizations/$organizationId/departments/${_normalizedDepartmentId()}/messages';
  }

  // ── Dispose ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    // Clear active conversation so foreground notifications resume
    if (PushNotificationService.activeConversationPath == _activeMessagesPath) {
      PushNotificationService.activeConversationPath = null;
    }
    _typingDebounceTimer?.cancel();
    _typingClearTimer?.cancel();
    _recordingTimer?.cancel();
    _setTyping(false).ignore();
    _typingSubscription?.cancel();
    _keyDocSubscription?.cancel();
    _profilesSubscription?.cancel();
    _orgSettingsSubscription?.cancel();
    _audioRecorder.dispose();
    messageController.dispose();
    scrollController.dispose();
    inputFocusNode.dispose();
    _subscription?.cancel();
    super.dispose();
  }
}
