import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageStatus { sent, delivered, read }

enum MessageType { text, image, video, voice }

class ChatMessage {
  final String? id;

  /// Plaintext content — populated after decryption by [ChatController].
  /// Empty string for media messages or when decryption is pending.
  final String text;

  final String senderId;

  /// Firebase Auth UID of the sender — used to look up live profile data
  /// (name, avatar). Absent on messages created before this field was added.
  final String? senderUid;

  final String organizationId;
  final String departmentId;
  final DateTime? createdAt;
  final bool isEdited;
  final DateTime? editedAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? deletedBy;

  /// 'admin' when sent by an admin user; null/empty otherwise.
  final String? senderRole;

  /// DisplayIds of participants who have opened this message.
  final List<String> readBy;
  final MessageType messageType;
  final String? mediaUrl;

  /// Duration in seconds — used for voice and video messages.
  final int? mediaDuration;
  final String? mediaFileName;

  // ── E2EE fields ─────────────────────────────────────────────────────────────

  /// When true, [encryptedText] and [iv] carry the ciphertext from Firestore.
  final bool isEncrypted;

  /// Base-64 AES-256-GCM ciphertext of the message body.
  final String? encryptedText;

  /// Base-64 12-byte GCM nonce paired with [encryptedText].
  final String? iv;

  /// Base-64 AES-256-GCM ciphertext of [mediaUrl].
  final String? encryptedMediaUrl;

  /// Base-64 GCM nonce paired with [encryptedMediaUrl].
  final String? mediaIv;

  const ChatMessage({
    this.id,
    required this.text,
    required this.senderId,
    this.senderUid,
    required this.organizationId,
    required this.departmentId,
    this.createdAt,
    this.isEdited = false,
    this.editedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
    this.senderRole,
    this.readBy = const [],
    this.messageType = MessageType.text,
    this.mediaUrl,
    this.mediaDuration,
    this.mediaFileName,
    this.isEncrypted = false,
    this.encryptedText,
    this.iv,
    this.encryptedMediaUrl,
    this.mediaIv,
  });

  bool get isMedia => messageType != MessageType.text;

  /// Returns the delivery/read status from the perspective of [myDisplayId].
  /// Only meaningful for messages sent by [myDisplayId].
  MessageStatus statusFor(String myDisplayId) {
    if (readBy.any((id) => id != myDisplayId)) return MessageStatus.read;
    if (createdAt != null) return MessageStatus.delivered;
    return MessageStatus.sent;
  }

  /// Return a copy with [text] (and optionally [mediaUrl]) replaced by their
  /// decrypted counterparts.  All other fields are preserved.
  ChatMessage withDecrypted({String? text, String? mediaUrl}) => ChatMessage(
        id: id,
        text: text ?? this.text,
        senderId: senderId,
        senderUid: senderUid,
        organizationId: organizationId,
        departmentId: departmentId,
        createdAt: createdAt,
        isEdited: isEdited,
        editedAt: editedAt,
        readBy: readBy,
        messageType: messageType,
        mediaUrl: mediaUrl ?? this.mediaUrl,
        mediaDuration: mediaDuration,
        mediaFileName: mediaFileName,
        isEncrypted: isEncrypted,
        encryptedText: encryptedText,
        iv: iv,
        encryptedMediaUrl: encryptedMediaUrl,
        mediaIv: mediaIv,
      );

  factory ChatMessage.fromJson(Map<String, dynamic> json, {String? id}) {
    final encrypted = json['isEncrypted'] as bool? ?? false;
    return ChatMessage(
      id: id,
      // Plain-text field kept for backwards compatibility with old messages.
      text: json['text'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderUid: json['senderUid'] as String?,
      organizationId: json['organizationId'] as String? ?? '',
      departmentId: json['departmentId'] as String? ?? '',
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : null,
      isEdited: json['isEdited'] as bool? ?? false,
      editedAt: json['editedAt'] is Timestamp
          ? (json['editedAt'] as Timestamp).toDate()
          : null,
      isDeleted: json['isDeleted'] as bool? ?? false,
      deletedAt: json['deletedAt'] is Timestamp
          ? (json['deletedAt'] as Timestamp).toDate()
          : null,
      deletedBy: json['deletedBy'] as String?,
      senderRole: json['senderRole'] as String?,
      readBy: List<String>.from(json['readBy'] as List? ?? []),
      messageType: _parseType(json['messageType'] as String?),
      mediaUrl: json['mediaUrl'] as String?,
      mediaDuration: json['mediaDuration'] as int?,
      mediaFileName: json['mediaFileName'] as String?,
      isEncrypted: encrypted,
      encryptedText: json['encryptedText'] as String?,
      iv: json['iv'] as String?,
      encryptedMediaUrl: json['encryptedMediaUrl'] as String?,
      mediaIv: json['mediaIv'] as String?,
    );
  }

  static MessageType _parseType(String? raw) {
    switch (raw) {
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'voice':
        return MessageType.voice;
      default:
        return MessageType.text;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'senderId': senderId,
      if (senderUid != null) 'senderUid': senderUid,
      'organizationId': organizationId,
      'departmentId': departmentId,
      'createdAt': FieldValue.serverTimestamp(),
      if (messageType != MessageType.text) 'messageType': messageType.name,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      if (mediaDuration != null) 'mediaDuration': mediaDuration,
      if (mediaFileName != null) 'mediaFileName': mediaFileName,
      if (isEncrypted) 'isEncrypted': true,
      if (encryptedText != null) 'encryptedText': encryptedText,
      if (iv != null) 'iv': iv,
      if (encryptedMediaUrl != null) 'encryptedMediaUrl': encryptedMediaUrl,
      if (mediaIv != null) 'mediaIv': mediaIv,
    };
  }
}
