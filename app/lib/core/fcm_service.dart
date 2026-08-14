import 'dart:developer' as developer;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Alert payload as published by backend/app/fcm.py's FirebaseFCMClient —
/// state, and both language strings (Section 6.4: the backend ships both,
/// the app picks which to show).
class AlertMessage {
  final String state; // "WATCH" | "WARNING" | "EVACUATE"
  final String messageEn;
  final String messageMs;

  const AlertMessage({
    required this.state,
    required this.messageEn,
    required this.messageMs,
  });

  factory AlertMessage.fromRemoteMessage(RemoteMessage message) => AlertMessage(
        state: message.data['state'] as String? ?? 'WATCH',
        messageEn: message.data['message_en'] as String? ?? '',
        messageMs: message.data['message_ms'] as String? ?? '',
      );
}

/// Background handler must be a top-level (or static) function per
/// firebase_messaging's requirements — it runs in its own isolate.
/// Deliberately does nothing beyond letting the OS show the
/// notification; anything needing app state must happen in the
/// foreground handler or when the user taps the notification.
@pragma('vm:entry-point')
Future<void> siagaBackgroundMessageHandler(RemoteMessage message) async {
  developer.log('background message: ${message.data}', name: 'siaga.fcm');
}

/// User-facing notification permission state for the Settings screen.
/// `unavailable` covers both "Firebase isn't configured on this build"
/// and "the platform call itself failed" — both read the same to a user
/// (no push is going to arrive) even though the causes differ.
enum NotificationPermissionStatus { authorized, denied, notDetermined, unavailable }

/// Wraps Firebase Cloud Messaging. Every method degrades to a logged
/// no-op rather than throwing if Firebase wasn't initialized (no
/// google-services.json / GoogleService-Info.plist configured yet) — the
/// booth demo must still run without a live Firebase project, same
/// resilience philosophy as the backend's NullFCMClient (Section 2).
class FcmService {
  bool _available = false;

  bool get isAvailable => _available;

  Future<NotificationPermissionStatus> checkPermissionStatus() async {
    if (!_available) return NotificationPermissionStatus.unavailable;
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      switch (settings.authorizationStatus) {
        case AuthorizationStatus.authorized:
        case AuthorizationStatus.provisional:
          return NotificationPermissionStatus.authorized;
        case AuthorizationStatus.denied:
          return NotificationPermissionStatus.denied;
        case AuthorizationStatus.notDetermined:
          return NotificationPermissionStatus.notDetermined;
      }
    } catch (e) {
      debugPrint('checkPermissionStatus failed: $e');
      return NotificationPermissionStatus.unavailable;
    }
  }

  /// Re-prompts for permission (only has an effect if the OS hasn't
  /// already permanently denied it — same platform limitation any app
  /// has, nothing SIAGA-specific).
  Future<NotificationPermissionStatus> requestPermission() async {
    if (!_available) return NotificationPermissionStatus.unavailable;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional
          ? NotificationPermissionStatus.authorized
          : NotificationPermissionStatus.denied;
    } catch (e) {
      debugPrint('requestPermission failed: $e');
      return NotificationPermissionStatus.unavailable;
    }
  }

  Stream<AlertMessage> get onForegroundAlert =>
      FirebaseMessaging.onMessage.map(AlertMessage.fromRemoteMessage);

  Stream<AlertMessage> get onNotificationOpened =>
      FirebaseMessaging.onMessageOpenedApp.map(AlertMessage.fromRemoteMessage);

  Future<void> init() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      FirebaseMessaging.onBackgroundMessage(siagaBackgroundMessageHandler);
      _available = true;
    } catch (e) {
      // No Firebase project configured yet, or permission plumbing
      // missing on this platform build — log and continue without push.
      debugPrint('FcmService.init failed, continuing without push: $e');
      _available = false;
    }
  }

  Future<void> subscribeToCell(String cellId) async {
    if (!_available) return;
    try {
      await FirebaseMessaging.instance.subscribeToTopic('cell_$cellId');
    } catch (e) {
      debugPrint('subscribeToCell($cellId) failed: $e');
    }
  }

  Future<void> unsubscribeFromCell(String cellId) async {
    if (!_available) return;
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic('cell_$cellId');
    } catch (e) {
      debugPrint('unsubscribeFromCell($cellId) failed: $e');
    }
  }
}
