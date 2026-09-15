/// The 8 real, switchable launcher-icon styles (Settings > Appearance >
/// App Icon) — each backed by an actual bundled icon asset on both
/// platforms (Android `activity-alias` entries in AndroidManifest.xml,
/// iOS `CFBundleAlternateIcons` in Info.plist; see `AppIconService` for the
/// platform channel that activates one). `key` is what's persisted to
/// `profiles.app_icon_style` and passed across the platform channel — it
/// must match the native side's style-key maps exactly.
class AppIconStyle {
  const AppIconStyle({
    required this.key,
    required this.label,
    required this.description,
    this.supported = true,
  });

  final String key;
  final String label;
  final String description;

  /// False only for "custom": true dynamic launcher icons can't accept an
  /// arbitrary uploaded image without shipping a new build (both Android's
  /// activity-alias and iOS's CFBundleAlternateIcons require icon images to
  /// already be compiled into the app), so it's shown, not hidden, but
  /// disabled with an honest explanation rather than faked.
  final bool supported;

  /// `assets/app_icons/<key>.png` — a preview generated from the exact same
  /// image used for the real launcher icon, so what's shown here is never
  /// out of sync with what actually gets applied.
  String get previewAsset => 'assets/app_icons/$key.png';
}

const kAppIconStyles = <AppIconStyle>[
  AppIconStyle(key: 'classic', label: 'Classic', description: 'The default Communeo look.'),
  AppIconStyle(key: 'dark', label: 'Dark', description: 'A moodier, all-dark take.'),
  AppIconStyle(key: 'minimal', label: 'Minimal', description: 'Clean line-art on white.'),
  AppIconStyle(key: 'neon', label: 'Neon', description: 'Glowing neon on black.'),
  AppIconStyle(key: 'gradient', label: 'Gradient', description: 'A bolder, warmer gradient.'),
  AppIconStyle(key: 'glass', label: 'Glass', description: 'A soft, frosted-glass finish.'),
  AppIconStyle(key: 'developer', label: 'Developer', description: 'For the terminal-and-code crowd.'),
  AppIconStyle(key: 'gaming', label: 'Gaming', description: 'Bold, angular, and electric.'),
  AppIconStyle(
    key: 'custom',
    label: 'Custom',
    description: 'Requires a future app update — not supported on this platform yet.',
    supported: false,
  ),
];

AppIconStyle appIconStyleFromKey(String? key) =>
    kAppIconStyles.firstWhere((s) => s.key == key, orElse: () => kAppIconStyles.first);
