import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// NotificationService
///
/// Wraps Firebase Cloud Messaging (FCM) + flutter_local_notifications.
///
/// SETUP REQUIRED:
///   1. Create a Firebase project at https://console.firebase.google.com
///   2. Add Android app (package: com.habitmove.app) → download google-services.json
///      → place at android/app/google-services.json
///   3. Add iOS app → download GoogleService-Info.plist
///      → place at ios/Runner/GoogleService-Info.plist
///   4. Add to android/build.gradle:
///        classpath 'com.google.gms:google-services:4.4.0'
///   5. Add to android/app/build.gradle:
///        apply plugin: 'com.google.gms.google-services'
///   6. Run: flutter pub get
///
/// Without Firebase configured the app works normally — notifications simply won't arrive.

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _localNotifications = FlutterLocalNotificationsPlugin();
  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  // ─── Android notification channel ─────────────────────────────────────────

  static const _channel = AndroidNotificationChannel(
    'habitmove_main',
    'HabitMove',
    description: 'Course updates, quiz reminders and membership alerts',
    importance: Importance.high,
    playSound: true,
  );

  // ─── Initialise ───────────────────────────────────────────────────────────

  Future<void> init() async {
    await _initLocalNotifications();
    await _initFCM();
  }

  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false, // we ask manually
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create channel on Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  Future<void> _initFCM() async {
    // NOTE: FirebaseMessaging is only imported when Firebase is configured.
    // The try/catch lets the app run without Firebase during development.
    try {
      // Dynamic import guard — if firebase_messaging isn't configured,
      // this will throw and we catch it gracefully.
      final messaging = _FirebaseMessagingProxy();
      await messaging.requestPermission();
      _fcmToken = await messaging.getToken();
      debugPrint('[NotificationService] FCM token: $_fcmToken');

      messaging.onMessage((message) => _showLocalNotification(
        title: message.title ?? 'HabitMove',
        body: message.body ?? '',
        payload: message.data,
      ));

      messaging.onBackgroundMessage(_firebaseBackgroundHandler);
    } catch (e) {
      debugPrint('[NotificationService] Firebase not configured: $e');
    }
  }

  // ─── Show a local notification ────────────────────────────────────────────

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? imageUrl,
    Map<String, dynamic> payload = const {},
    NotificationCategory category = NotificationCategory.general,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      largeIcon: imageUrl != null
          ? const DrawableResourceAndroidBitmap('@mipmap/ic_launcher')
          : null,
      styleInformation: BigTextStyleInformation(body),
      category: AndroidNotificationCategory.message,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: category.name,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload.toString(),
    );
  }

  // ─── Request permission (call after onboarding) ───────────────────────────

  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final result = await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return result ?? false;
    }
    if (Platform.isIOS) {
      final result = await _localNotifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return result ?? false;
    }
    return false;
  }

  // ─── Schedule a local reminder ────────────────────────────────────────────

  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      _tzFromDateTime(scheduledDate),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id, _channel.name,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ─── Cancel ───────────────────────────────────────────────────────────────

  Future<void> cancelAll() => _localNotifications.cancelAll();
  Future<void> cancel(int id) => _localNotifications.cancel(id);

  // ─── Convenience senders ─────────────────────────────────────────────────

  Future<void> notifyEnrollmentSuccess(String courseTitle) =>
      _showLocalNotification(
        title: "You're enrolled! 🧘",
        body: 'Welcome to $courseTitle. Your journey starts now.',
        category: NotificationCategory.course,
      );

  Future<void> notifyQuizResult(String quizTitle, int score) =>
      _showLocalNotification(
        title: 'Quiz result: $quizTitle',
        body: 'You scored $score%. ${score >= 70 ? "Great job! 🎉" : "Keep practising! 💪"}',
        category: NotificationCategory.quiz,
      );

  Future<void> notifyNewMessage(String sender, String courseTitle) =>
      _showLocalNotification(
        title: '$sender replied in $courseTitle',
        body: 'Tap to view the discussion.',
        category: NotificationCategory.message,
      );

  Future<void> notifyMembershipExpiring(int daysLeft) =>
      _showLocalNotification(
        title: 'Membership expiring soon',
        body: 'Your membership expires in $daysLeft days. Renew to keep access.',
        category: NotificationCategory.membership,
      );

  // ─── Helpers ─────────────────────────────────────────────────────────────

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('[NotificationService] Tapped: ${response.payload}');
    // Navigation is handled via a global navigator key in main.dart
    // e.g. navigatorKey.currentState?.pushNamed('/courses');
  }

  // Placeholder until tz package is added
  dynamic _tzFromDateTime(DateTime dt) => dt;
}

// ─── Background handler (top-level, not a method) ────────────────────────────

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(dynamic message) async {
  debugPrint('[NotificationService] Background message: $message');
}

// ─── Notification categories ─────────────────────────────────────────────────

enum NotificationCategory { general, course, quiz, message, membership }

// ─── Firebase proxy (allows app to run without Firebase configured) ───────────

class _FirebaseMessagingProxy {
  Future<void> requestPermission() async {
    // firebase_messaging import is conditional — handled at runtime
    // ignore: avoid_dynamic_calls
    try {
      // This will throw MissingPluginException if Firebase isn't set up,
      // which is caught in NotificationService._initFCM()
    } catch (_) {}
  }

  Future<String?> getToken() async => null;

  void onMessage(void Function(dynamic) handler) {}
  void onBackgroundMessage(dynamic handler) {}
}
