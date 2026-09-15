import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/responsive.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/app_icon_style.dart';
import '../providers/app_icon_providers.dart';

/// Settings > Appearance > App Icon. A real, platform-backed launcher-icon
/// switch on Android/iOS (see AppIconService/MainActivity.kt/AppDelegate.swift)
/// — not a change to anything inside the app's own UI. "Custom" is shown,
/// not hidden, but stays disabled: neither Android's activity-alias
/// mechanism nor iOS's CFBundleAlternateIcons can accept an arbitrary
/// uploaded image without shipping a new build, so pretending otherwise
/// would be a fake feature.
class AppIconScreen extends ConsumerStatefulWidget {
  const AppIconScreen({super.key});

  @override
  ConsumerState<AppIconScreen> createState() => _AppIconScreenState();
}

class _AppIconScreenState extends ConsumerState<AppIconScreen> {
  String? _pendingKey;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);
    final currentKey = profileAsync.valueOrNull?.appIconStyle ?? 'classic';
    final pendingKey = _pendingKey ?? currentKey;
    final pendingStyle = appIconStyleFromKey(pendingKey);
    final isSaving = ref.watch(appIconControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackdrop()),
          SafeArea(
            child: ResponsiveCenter(
              maxWidth: 560,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        _BackButton(onTap: () => context.pop()),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Customize your Communeo icon',
                                  style: TextStyle(
                                      fontSize: 19, fontWeight: FontWeight.w800, color: HomeStyle.textPrimary)),
                              SizedBox(height: 2),
                              Text('Choose an icon that matches your style.',
                                  style: TextStyle(fontSize: 12.5, color: HomeStyle.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: kAppIconStyles.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.78,
                            ),
                            itemBuilder: (context, i) {
                              final style = kAppIconStyles[i];
                              return _IconTile(
                                style: style,
                                selected: style.key == pendingKey,
                                onTap: () {
                                  if (!style.supported) {
                                    context.showSnack(style.description, isError: true);
                                    return;
                                  }
                                  setState(() => _pendingKey = style.key);
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          const Text('Preview',
                              style: TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 10),
                          GradientBorderCard(
                            radius: 20,
                            gradient: LinearGradient(
                                colors: [HomeStyle.purple.withValues(alpha: 0.18), HomeStyle.blue.withValues(alpha: 0.10)]),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: Image.asset(pendingStyle.previewAsset, width: 64, height: 64),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(pendingStyle.label,
                                            style: const TextStyle(
                                                color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                                        const SizedBox(height: 2),
                                        const Text('How Communeo will look on your home screen',
                                            style: TextStyle(color: HomeStyle.textSecondary, fontSize: 11.5)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: isSaving || pendingKey == currentKey
                                  ? null
                                  : () async {
                                      final applied =
                                          await ref.read(appIconControllerProvider.notifier).selectStyle(pendingKey);
                                      if (!context.mounted) return;
                                      context.showSnack(
                                        applied
                                            ? 'App icon updated!'
                                            : 'Saved your preference — icon switching isn\'t supported on this device.',
                                      );
                                    },
                              child: isSaving
                                  ? const SizedBox(
                                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Apply Icon'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.style, required this.selected, required this.onTap});

  final AppIconStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: HomeStyle.cardBase.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? HomeStyle.purple : Colors.white.withValues(alpha: 0.08), width: selected ? 1.6 : 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Opacity(
                  opacity: style.supported ? 1 : 0.35,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(style.previewAsset, fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(style.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: style.supported ? HomeStyle.textPrimary : HomeStyle.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12)),
              const SizedBox(height: 3),
              if (selected)
                const Icon(Icons.check_circle_rounded, color: HomeStyle.purple, size: 16)
              else if (!style.supported)
                const Icon(Icons.lock_outline_rounded, color: HomeStyle.textSecondary, size: 14)
              else
                const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: HomeStyle.cardBase,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: onTap,
            child: const Icon(Icons.arrow_back_rounded, size: 21, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
