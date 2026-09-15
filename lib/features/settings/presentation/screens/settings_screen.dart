import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../admin/presentation/providers/admin_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';

const _preferenceLabels = {
  'messages': ('Messages', 'Get notified when you receive a new message', Icons.chat_bubble_outline_rounded),
  'connections': ('Connections', 'Get notified about new connection requests', Icons.people_alt_outlined),
  'jobs': ('Jobs', 'Get notified about new job opportunities', Icons.work_outline_rounded),
  'hackathons': ('Hackathons', 'Get notified about upcoming hackathons', Icons.emoji_events_outlined),
  'projects': ('Projects', 'Get notified about new project opportunities', Icons.folder_outlined),
  'mentorship': ('Mentorship', 'Get notified about mentorship opportunities', Icons.school_outlined),
  'local_requests': ('Local requests', 'Get notified about requests near you', Icons.location_on_outlined),
  'meetups': ('Meetups', 'Get notified about upcoming meetups', Icons.groups_outlined),
  'news': ('News', 'Get notified about community news', Icons.description_outlined),
  'community_events': ('Community events', 'Get notified about upcoming events', Icons.calendar_month_outlined),
};

/// Settings — UI redesigned to match the Profile page's premium dark
/// visual language (`HomeStyle`/`GlowBackdrop`). Every toggle, route, and
/// account action below calls the exact same provider it always did;
/// nothing about how preferences are read/written, how blocking works, or
/// how sign-out works has changed.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(notificationPreferencesProvider);
    final email = ref.watch(authStateProvider).valueOrNull?.email;
    final isAdmin = ref.watch(isAdminProvider).valueOrNull ?? false;

    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackdrop()),
          SafeArea(
            child: ResponsiveCenter(
              maxWidth: 480,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(),
                    const SizedBox(height: 8),
                    if (email != null) ...[
                      const _GroupLabel('Account'),
                      _AccountCard(email: email),
                      const SizedBox(height: 22),
                    ],
                    const _GroupLabel(
                      'Notification preferences',
                      subtitle: 'Choose what you want to be notified about',
                    ),
                    prefsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: LinearProgressIndicator(),
                      ),
                      error: (_, __) => const Text('Could not load preferences',
                          style: TextStyle(color: HomeStyle.textSecondary)),
                      data: (prefs) {
                        final values = prefs ?? {};
                        return GradientBorderCard(
                          radius: 20,
                          gradient: LinearGradient(colors: [
                            HomeStyle.blue.withValues(alpha: 0.20),
                            HomeStyle.purple.withValues(alpha: 0.10),
                          ]),
                          child: Column(
                            children: [
                              for (final entry in _preferenceLabels.entries)
                                _PreferenceRow(
                                  icon: entry.value.$3,
                                  title: entry.value.$1,
                                  description: entry.value.$2,
                                  value: values[entry.key] as bool? ?? true,
                                  isLast: entry.key == _preferenceLabels.keys.last,
                                  onChanged: (v) => ref
                                      .read(notificationControllerProvider.notifier)
                                      .updatePreferences({entry.key: v}),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    const _GroupLabel(
                      'Appearance',
                      subtitle: 'Personalize how Communeo looks',
                    ),
                    _ActionCard(
                      icon: Icons.apps_rounded,
                      iconColor: HomeStyle.purple,
                      title: 'App Icon',
                      subtitle: 'Choose how Communeo appears on your home screen.',
                      onTap: () => context.push(RoutePaths.appIconSettings),
                    ),
                    const SizedBox(height: 22),
                    const _GroupLabel(
                      'Privacy & Safety',
                      subtitle: 'Manage your privacy and safety preferences',
                    ),
                    _ActionCard(
                      icon: Icons.face_retouching_natural_outlined,
                      iconColor: HomeStyle.violet,
                      title: 'Profile Photo',
                      subtitle: 'Choose who can see your profile photo',
                      onTap: () => context.push(RoutePaths.profilePhotoPrivacy),
                    ),
                    const SizedBox(height: 10),
                    _ActionCard(
                      icon: Icons.block_outlined,
                      iconColor: HomeStyle.blue,
                      title: 'Blocked users',
                      subtitle: 'Manage who you\'ve blocked',
                      onTap: () => context.push(RoutePaths.blockedUsers),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(height: 22),
                      const _GroupLabel('Moderation'),
                      _ActionCard(
                        icon: Icons.shield_outlined,
                        iconColor: HomeStyle.violet,
                        title: 'Moderation queue',
                        subtitle: 'Review reports (admin/moderator)',
                        onTap: () => context.push(RoutePaths.adminReports),
                      ),
                    ],
                    const SizedBox(height: 22),
                    const _GroupLabel('Account Actions'),
                    _ActionCard(
                      icon: Icons.logout_rounded,
                      iconColor: const Color(0xFFFB7185),
                      title: 'Sign out',
                      subtitle: 'Sign out from your Communeo account',
                      titleColor: const Color(0xFFFB7185),
                      onTap: () => ref.read(authControllerProvider.notifier).signOut(),
                    ),
                    const SizedBox(height: 40),
                    const _BrandFooter(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Row(
        children: [
          _IconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onTap: () => context.pop()),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: MediaQuery.sizeOf(context).width < 360 ? 22 : 25,
                    fontWeight: FontWeight.w800,
                    color: HomeStyle.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                const Text('Customize your experience',
                    style: TextStyle(fontSize: 12.5, color: HomeStyle.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
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
              child: Icon(icon, size: 21, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.title, {this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: HomeStyle.textPrimary)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: const TextStyle(fontSize: 12.5, color: HomeStyle.textSecondary)),
          ],
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.email});

  final String email;

  String get _initials {
    final trimmed = email.trim();
    return trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return GradientBorderCard(
      radius: 18,
      gradient: LinearGradient(
          colors: [HomeStyle.blue.withValues(alpha: 0.22), HomeStyle.purple.withValues(alpha: 0.12)]),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: HomeStyle.brandGradient),
              alignment: Alignment.center,
              child: Text(_initials,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(email,
                      style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  const Text('Account email', style: TextStyle(color: HomeStyle.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    required this.isLast,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: HomeStyle.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w600, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(description, style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 11.5, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: HomeStyle.purple,
            thumbColor: const WidgetStatePropertyAll(Colors.white),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleColor,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color? titleColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GradientBorderCard(
      radius: 18,
      gradient: LinearGradient(colors: [iconColor.withValues(alpha: 0.22), HomeStyle.purple.withValues(alpha: 0.08)]),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: titleColor ?? HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: HomeStyle.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _BrandFooter extends StatelessWidget {
  const _BrandFooter();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Text(
            'Better People\nBrighter Possibilities.',
            textAlign: TextAlign.center,
            style: GoogleFonts.caveat(
              fontSize: 20,
              height: 1.15,
              fontWeight: FontWeight.w600,
              color: HomeStyle.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            AppConstants.appName,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: HomeStyle.textSecondary),
          ),
          const SizedBox(height: 2),
          const Text(
            'PEOPLE  ×  PURPOSE  ×  PROGRESS',
            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, letterSpacing: 1.1, color: HomeStyle.textSecondary),
          ),
        ],
      ),
    );
  }
}
