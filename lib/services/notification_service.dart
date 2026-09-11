import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_database/firebase_database.dart';

/// Comprehensive Push & In-App Notification Service for Bee Talk
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Tracks currently active chat room ID so we don't alert for the chat the user is actively viewing
  String? activeRoomId;

  /// Callback when a user taps a notification payload
  Function(Map<String, dynamic> payload)? onNotificationTapped;

  /// Active database subscriptions for real-time background message monitoring
  final Map<String, StreamSubscription<DatabaseEvent>> _roomSubscriptions = {};
  StreamSubscription<DatabaseEvent>? _userChatsSubscription;

  /// Channel ID and Name for Android High Priority Alerts
  static const String channelId = 'bee_talk_messages';
  static const String channelName = 'Bee Talk Messages';
  static const String channelDescription = 'Instant notifications for incoming chat messages in Bee Talk';

  /// Initialize notification plugin, channels, and click handling
  Future<void> initialize({Function(Map<String, dynamic> payload)? onNotificationClick}) async {
    if (_isInitialized) return;

    if (onNotificationClick != null) {
      onNotificationTapped = onNotificationClick;
    }

    // Android Initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS / Darwin Initialization settings
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          try {
            final Map<String, dynamic> payloadMap = jsonDecode(response.payload!);
            onNotificationTapped?.call(payloadMap);
          } catch (e) {
            debugPrint('Error parsing notification payload: $e');
          }
        }
      },
    );

    // Create high-importance Android Notification Channel
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
          showBadge: true,
        ),
      );
    }

    _isInitialized = true;
    debugPrint('🐝 NotificationService initialized successfully');
  }

  /// Request Notification Permissions (Android 13+ and iOS)
  Future<bool> requestPermission() async {
    try {
      final status = await Permission.notification.request();
      
      // Also request via Android-specific plugin API if available
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }

      return status.isGranted;
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      return false;
    }
  }

  /// Display a heads-up push alert for an incoming message
  Future<void> showMessageNotification({
    required String roomId,
    required String senderId,
    required String senderName,
    required String senderAvatar,
    required String messageText,
    String? senderLang,
  }) async {
    // Suppress notification if user is currently inside this specific chat room
    if (activeRoomId == roomId) {
      return;
    }

    final int notificationId = roomId.hashCode.abs() % 100000;

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      category: AndroidNotificationCategory.message,
      styleInformation: BigTextStyleInformation(
        messageText,
        htmlFormatBigText: false,
        contentTitle: '$senderAvatar $senderName',
        htmlFormatContentTitle: false,
        summaryText: 'New Bee Talk Message',
      ),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payload = jsonEncode({
      'roomId': roomId,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'senderLang': senderLang ?? 'English',
    });

    try {
      await _localNotifications.show(
        notificationId,
        '$senderAvatar $senderName',
        messageText,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing local notification: $e');
    }
  }

  /// Start background/in-app listener across all user chat rooms
  void startListeningToUserMessages({
    required String currentUserId,
    required Function(String roomId, String senderName, String avatar, String text) onInAppAlert,
  }) {
    final dbRef = FirebaseDatabase.instance.ref();
    final userChatsRef = dbRef.child('user_chats').child(currentUserId);
    final appStartTime = DateTime.now().millisecondsSinceEpoch - 1000;

    _userChatsSubscription?.cancel();
    _userChatsSubscription = userChatsRef.onValue.listen((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return;
      final chatsMap = Map<dynamic, dynamic>.from(event.snapshot.value as Map);

      for (final key in chatsMap.keys) {
        final roomId = key.toString();
        if (_roomSubscriptions.containsKey(roomId)) continue;

        // Listen to newest messages in this room
        final messageQuery = dbRef
            .child('messages')
            .child(roomId)
            .orderByChild('timestamp')
            .limitToLast(1);

        final sub = messageQuery.onChildAdded.listen((msgEvent) {
          if (!msgEvent.snapshot.exists || msgEvent.snapshot.value == null) return;
          final msgData = Map<dynamic, dynamic>.from(msgEvent.snapshot.value as Map);

          final senderId = (msgData['senderId'] ?? '').toString();
          final timestamp = (msgData['timestamp'] is int)
              ? msgData['timestamp'] as int
              : DateTime.now().millisecondsSinceEpoch;

          // Only alert for new incoming messages from other users created after app start
          if (senderId.isNotEmpty && senderId != currentUserId && timestamp > appStartTime) {
            final senderName = (msgData['senderName'] ?? 'Bee User').toString();
            final senderAvatar = (msgData['senderAvatar'] ?? '🐝').toString();
            final text = (msgData['text'] ?? msgData['originalText'] ?? '').toString();
            final senderLang = (msgData['senderLang'] ?? 'en').toString();

            // Mark message as 'delivered' in database
            final msgKey = msgEvent.snapshot.key;
            if (msgKey != null && (msgData['status'] == null || msgData['status'] == 'sent')) {
              dbRef.child('messages').child(roomId).child(msgKey).update({
                'status': 'delivered',
              });
            }

            // Show push notification
            showMessageNotification(
              roomId: roomId,
              senderId: senderId,
              senderName: senderName,
              senderAvatar: senderAvatar,
              messageText: text,
              senderLang: senderLang,
            );

            // In-app alert callback
            if (activeRoomId != roomId) {
              onInAppAlert(roomId, senderName, senderAvatar, text);
            }
          }
        });

        _roomSubscriptions[roomId] = sub;
      }
    });
  }

  /// Stop listening and clean up all subscriptions
  void dispose() {
    _userChatsSubscription?.cancel();
    for (final sub in _roomSubscriptions.values) {
      sub.cancel();
    }
    _roomSubscriptions.clear();
  }
}
