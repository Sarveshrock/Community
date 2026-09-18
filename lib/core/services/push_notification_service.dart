import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../routing/app_router.dart';

const _androidChannelId = 'communeo_default';
const _androidChannelName = 'Communeo';
const _androidChannelDescription =
    'Messages, connections, and other activity on Communeo';

/// Runs entirely in a fresh background isolate (Android only) when a push
/// arrives while the app is backgrounded/terminated — `Firebase.initializeApp`
/// has to be called again here because nothing from the foreground isolate
/// carries over. The system tray notification itself is already posted by
/// the OS/FCM for any message with a `notification` payload (which is all
/// `send-notification` ever sends, see the edge function); this handler
/// exists only as the hook `firebase_messaging` requires to allow that.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// Phone-notification-bar delivery for the same events already shown in the
/// in-app Notifications screen (spec section 47's other half). The backend
/// side of this already existed — `send-notification` writes the in-app row
/// and best-effort pushes via FCM to every token in `device_tokens` — the
/// piece that was missing was a client that ever put a real token there.
///
/// Deliberately fails soft everywhere: a device/build with no Firebase
/// project wired up (no `google-services.json` / `GoogleService-Info.plist`,
/// see README) sees [initialize] catch the native init error and return,
/// leaving every other method a no-op — the app runs exactly as it did
/// before this feature existed, it just never gets a token to register.
class PushNotificationService {
  PushNotificationService._();

  static bool _initialized = false;
  static bool get isAvailable => _initialized;

  static final _localNotifications = FlutterLocalNotificationsPlugin();

  /// Set by [pushNotificationSyncProvider] once a user is signed in — kept
  /// as a single mutable field (not an added stream listener) so re-running
  /// that provider on every rebuild can't accumulate duplicate listeners.
  static void Function(String token)? _onTokenRefreshHandler;

  static String get platformLabel {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'other';
    }
  }

  /// Call once, before `runApp` — see `main.dart`.
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp();
    } catch (e, st) {
      // No Firebase project configured on this build. Expected on a fresh
      // checkout that hasn't followed the README's push-notification setup
      // yet — not a bug, so this stays a debug log, not a crash.
      debugPrint('PushNotificationService: Firebase unavailable, push notifications disabled ($e)');
      debugPrintStack(stackTrace: st);
      return;
    }
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const androidChannel = AndroidNotificationChannel(
      _androidChannelId,
      _androidChannelName,
      description: _androidChannelDescription,
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permission is requested once, below, via FirebaseMessaging itself
        // — asking again here would show iOS's system prompt twice.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );

    // iOS shows the system banner for a foregrounded app natively once this
    // is set; Android has no equivalent and needs the local-notification
    // shown by hand in `_handleForegroundMessage` below.
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_navigateForMessage);
    FirebaseMessaging.instance.onTokenRefresh
        .listen((token) => _onTokenRefreshHandler?.call(token));

    // The app was launched (from terminated, not just backgrounded) by the
    // user tapping a push — land them where that notification points
    // instead of the default landing screen.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _navigateForMessage(initialMessage);
  }

  static void setTokenRefreshHandler(void Function(String token) handler) {
    _onTokenRefreshHandler = handler;
  }

  /// Prompts for notification permission (a no-op on Android 12 and below,
  /// where none is needed) and returns the FCM token to register, or null if
  /// permission was denied or Firebase isn't configured on this build.
  static Future<String?> requestPermissionAndGetToken() async {
    if (!_initialized) return null;
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return null;
    }
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('PushNotificationService: could not obtain FCM token ($e)');
      return null;
    }
  }

  /// Used to unregister this device's token on sign-out (before the session
  /// actually ends — `device_tokens`' RLS needs `auth.uid()` to still
  /// resolve for the delete to be allowed).
  static Future<String?> currentToken() async {
    if (!_initialized) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (defaultTargetPlatform == TargetPlatform.iOS) return;
    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          channelDescription: _androidChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static void _onLocalNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _navigateForData(data);
    } catch (_) {
      // Malformed/unknown payload — nothing to route to.
    }
  }

  static void _navigateForMessage(RemoteMessage message) =>
      _navigateForData(message.data);

  /// Mirrors `NotificationsScreen`'s in-app tap targets (see
  /// `notifications_screen.dart`) so a push and its in-app row always open
  /// the same place. Anything not recognized falls back to the Notifications
  /// list itself rather than doing nothing.
  static void _navigateForData(Map<String, dynamic> data) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      // First frame hasn't rendered yet (cold start via `getInitialMessage`)
      // — try again once it has, rather than dropping the navigation.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _navigateForData(data));
      return;
    }

    final type = data['type'] as String? ?? '';
    final postId = data['post_id'] as String?;
    final offerId = data['offer_id'] as String?;
    final chatRoute =
        type == 'message' ? RoutePaths.chatRouteForMessageData(data) : null;

    final router = GoRouter.of(context);
    if (chatRoute != null) {
      router.push(chatRoute);
    } else if (postId != null) {
      router.push(RoutePaths.postDetailOf(postId));
    } else if (type.startsWith('referral_') && offerId != null) {
      router.push(RoutePaths.referralOfferDetailOf(offerId));
    } else if (type.startsWith('interview_practice_')) {
      router.push(RoutePaths.myInterviewPracticeRequests);
    } else {
      router.push(RoutePaths.notifications);
    }
  }
}
