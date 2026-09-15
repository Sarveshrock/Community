import 'package:flutter/services.dart';

/// The only place that talks to the native side of Feature 1 (Settings >
/// Appearance > App Icon) — a thin hand-written platform channel, not a
/// pulled-in plugin, since the actual mechanism (Android
/// activity-alias toggling, iOS `setAlternateIconName`) is a few lines of
/// native code each; see MainActivity.kt / AppDelegate.swift.
///
/// Android and iOS are the only platforms with any launcher-icon-switching
/// API at all — web/desktop/Linux/Windows/macOS Flutter targets have no
/// native handler registered for this channel at all, which surfaces here
/// as a [MissingPluginException]. Rather than pretending the icon changed,
/// every method just reports failure so the caller can say so honestly;
/// the chosen style is still persisted (`profiles.app_icon_style`) so it's
/// ready to apply next time the user opens Communeo on a supported device.
class AppIconService {
  AppIconService._();

  static const _channel = MethodChannel('com.communeo.app/app_icon');

  static Future<bool> setIcon(String styleKey) async {
    try {
      final ok = await _channel.invokeMethod<bool>('setAppIcon', {'style': styleKey});
      return ok ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// The style currently active *on this device* per the OS, independent of
  /// whatever preference is stored server-side — used on launch to decide
  /// whether a re-apply is actually needed.
  static Future<String?> getActiveIcon() async {
    try {
      return await _channel.invokeMethod<String>('getActiveAppIcon');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
