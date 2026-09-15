import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/app_icon_service.dart';
import '../../../profile/presentation/providers/profile_providers.dart';

/// Applies whatever icon style is stored in `profiles.app_icon_style` to
/// *this* device, but only if it isn't already active here — the actual
/// OS-level icon is inherently per-device (there's no way to push it to
/// another device), so a fresh install or a new device re-syncs to the
/// signed-in user's saved preference the first time [HomeScreen] builds.
/// A no-op (never throws, never blocks the UI) on platforms with no native
/// handler for this at all.
final appIconSyncProvider = FutureProvider<void>((ref) async {
  final profile = await ref.watch(myProfileProvider.future);
  if (profile == null) return;
  final activeOnDevice = await AppIconService.getActiveIcon();
  if (activeOnDevice != null && activeOnDevice != profile.appIconStyle) {
    await AppIconService.setIcon(profile.appIconStyle);
  }
});

/// Settings > Appearance > App Icon's mutations: applies the style natively
/// on this device, then persists the preference via the existing generic
/// profile-update path (same as every other profile setting) so it's
/// remembered on future logins/devices.
class AppIconController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Returns whether the icon was actually applied *on this device* — a
  /// `false` here (with the preference still saved) means the platform has
  /// no launcher-icon-switching API at all (see [AppIconService]'s doc
  /// comment), not that the request failed.
  Future<bool> selectStyle(String styleKey) async {
    state = const AsyncLoading();
    final applied = await AppIconService.setIcon(styleKey);
    final saveResult = await AsyncValue.guard(
      () => ref.read(profileControllerProvider.notifier).updateProfile({'app_icon_style': styleKey}),
    );
    state = saveResult;
    return applied;
  }
}

final appIconControllerProvider = AsyncNotifierProvider<AppIconController, void>(AppIconController.new);
