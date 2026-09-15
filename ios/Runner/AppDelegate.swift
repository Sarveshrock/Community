import Flutter
import UIKit

/// Backs Settings > Appearance > App Icon on iOS via the platform's own
/// `UIApplication.setAlternateIconName` (iOS 10.3+) — the one real,
/// Apple-supported way to change a launcher icon at runtime; there's no
/// build-free way to accept an arbitrary *uploaded* image as a new
/// alternate icon (see `AppIconScreen`'s "Custom" tile, disabled for
/// exactly this reason). Alternate icon names below must match
/// `CFBundleAlternateIcons` in Info.plist.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let channelName = "com.communeo.app/app_icon"

  // Keys match `kAppIconStyles` on the Dart side; values match the
  // CFBundleAlternateIcons keys in Info.plist. "classic" has no entry —
  // it's the primary icon, selected by passing `nil`.
  private let alternateIconByStyle: [String: String] = [
    "dark": "AppIcon-Dark",
    "minimal": "AppIcon-Minimal",
    "neon": "AppIcon-Neon",
    "gradient": "AppIcon-Gradient",
    "glass": "AppIcon-Glass",
    "developer": "AppIcon-Developer",
    "gaming": "AppIcon-Gaming",
  ]

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "setAppIcon":
        guard UIApplication.shared.supportsAlternateIcons else {
          result(FlutterError(code: "UNSUPPORTED", message: "This device doesn't support alternate app icons", details: nil))
          return
        }
        guard let args = call.arguments as? [String: Any], let style = args["style"] as? String else {
          result(FlutterError(code: "BAD_ARGS", message: "Missing 'style'", details: nil))
          return
        }
        let name = self.alternateIconByStyle[style] // nil for "classic" -> primary icon
        UIApplication.shared.setAlternateIconName(name) { error in
          if let error = error {
            result(FlutterError(code: "SET_ICON_FAILED", message: error.localizedDescription, details: nil))
          } else {
            result(true)
          }
        }
      case "getActiveAppIcon":
        let current = UIApplication.shared.alternateIconName
        let style = self.alternateIconByStyle.first(where: { $0.value == current })?.key ?? "classic"
        result(style)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
