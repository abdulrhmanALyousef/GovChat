import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../datasource/remote_data/firebase_service.dart';

/// Background / terminated message handler.
/// Must be a top-level function annotated with @pragma('vm:entry-point').
/// FCM automatically displays the notification when the app is not in the
/// foreground and the message contains a notification payload, so this handler
/// only needs to handle data-only messages or side-effects.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM][bg] id=${message.messageId} type=${message.data["type"]}');
}

class PushNotificationService {
  static final PushNotificationService instance = PushNotificationService._();
  PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  final _tapController = StreamController<Map<String, dynamic>>.broadcast();

  /// Emit routing payloads when a notification is tapped.
  /// Listen in [EmployeeMainScreen] to navigate to the correct screen.
  Stream<Map<String, dynamic>> get onNotificationTapped =>
      _tapController.stream;

  /// Messages-collection path of the chat screen that is currently visible.
  /// Set in [ChatController] constructor; cleared in [ChatController.dispose].
  /// When a foreground FCM message arrives for the same path, the local
  /// notification is suppressed because the user is already viewing that chat.
  static String? activeConversationPath;

  // ── Notification channel IDs ───────────────────────────────────────────────
  static const _msgChannelId = 'govchat_messages';
  static const _msgChannelName = 'Messages';
  static const _announceChannelId = 'govchat_announcements';
  static const _announceChannelName = 'Announcements';
  static const _systemChannelId = 'govchat_system';
  static const _systemChannelName = 'System';
  static const _primaryColor = Color(0xFF4ADE80);

  // ── Initialization ─────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    // Request notification permission (iOS + Android 13+)
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Initialize local notifications plugin used for foreground display
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onLocalTap,
    );

    // Create Android notification channels
    if (!kIsWeb && Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _msgChannelId, _msgChannelName,
        description: 'New chat messages',
        importance: Importance.high,
      ));
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _announceChannelId, _announceChannelName,
        description: 'Organization announcements',
        importance: Importance.high,
      ));
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _systemChannelId, _systemChannelName,
        description: 'System and security alerts',
        importance: Importance.defaultImportance,
      ));
    }

    // iOS: show notifications while app is in the foreground
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Wire FCM handlers
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    _initialized = true;
    debugPrint('[FCM] PushNotificationService initialized');
  }

  // ── Token management ───────────────────────────────────────────────────────

  /// Fetch and persist the device FCM token to [employees/{uid}].
  /// Fire-and-forget; call after successful login.
  Future<void> uploadToken(String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await FirebaseService.instance.firestore
          .collection('employees')
          .doc(uid)
          .update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[FCM] token uploaded for uid=$uid');

      // Keep token fresh when FCM rotates it
      _messaging.onTokenRefresh.listen((newToken) {
        FirebaseService.instance.firestore
            .collection('employees')
            .doc(uid)
            .update({
          'fcmToken': newToken,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        }).ignore();
        debugPrint('[FCM] token refreshed for uid=$uid');
      });
    } catch (e) {
      debugPrint('[FCM] uploadToken error: $e');
    }
  }

  /// Remove token from Firestore and invalidate it on the FCM server.
  /// Call before logout so the device stops receiving push notifications.
  Future<void> deleteToken(String uid) async {
    try {
      await FirebaseService.instance.firestore
          .collection('employees')
          .doc(uid)
          .update({'fcmToken': FieldValue.delete()});
      await _messaging.deleteToken();
      debugPrint('[FCM] token deleted for uid=$uid');
    } catch (e) {
      debugPrint('[FCM] deleteToken error: $e');
    }
  }

  // ── Initial message (app opened from terminated state) ─────────────────────

  /// If the app was launched by tapping a notification while it was terminated,
  /// [getInitialMessage] returns that message once.
  /// Call this in [EmployeeMainScreen] after the first build frame.
  Future<void> checkInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    if (message != null) {
      debugPrint('[FCM] initial message type=${message.data["type"]}');
      _route(message.data);
    }
  }

  // ── Foreground handler ─────────────────────────────────────────────────────

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final data = message.data;
    final type = data['type'] as String? ?? '';

    // Suppress chat notification when the user is already in that conversation
    if (type == 'chat') {
      final convPath = data['conversationPath'] as String? ?? '';
      if (convPath.isNotEmpty && convPath == activeConversationPath) {
        debugPrint('[FCM][fg] suppressed — user is in active chat');
        return;
      }
    }

    await _showLocal(message);
  }

  Future<void> _showLocal(RemoteMessage message) async {
    final data = message.data;
    final type = data['type'] as String? ?? '';
    final notif = message.notification;

    final title = notif?.title ??
        (data['title'] as String? ?? 'GovChat');
    final body = notif?.body ??
        (data['body'] as String? ?? '');

    String channelId;
    String channelName;
    switch (type) {
      case 'chat':
        channelId = _msgChannelId;
        channelName = _msgChannelName;
        break;
      case 'announcement':
        channelId = _announceChannelId;
        channelName = _announceChannelName;
        break;
      default:
        channelId = _systemChannelId;
        channelName = _systemChannelName;
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: _primaryColor,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    // Deterministic notification ID to avoid stacking duplicates per message
    final id = (message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch)
            .abs() %
        2147483647;

    // Encode data as a simple key=value query string for routing on tap
    final payload =
        data.entries.map((e) => '${e.key}=${e.value}').join('&');

    await _plugin.show(id, title, body, details, payload: payload);
  }

  // ── Tap routing ────────────────────────────────────────────────────────────

  void _onLocalTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    final data = Map<String, dynamic>.fromEntries(
      payload.split('&').map((kv) {
        final idx = kv.indexOf('=');
        if (idx < 0) return MapEntry(kv, '');
        return MapEntry(kv.substring(0, idx), kv.substring(idx + 1));
      }),
    );
    _route(data);
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    debugPrint('[FCM] app opened from background tap type=${message.data["type"]}');
    _route(message.data);
  }

  void _route(Map<String, dynamic> data) {
    if (data.isNotEmpty) {
      _tapController.add(Map<String, dynamic>.from(data));
    }
  }

  void dispose() {
    _tapController.close();
  }
}
