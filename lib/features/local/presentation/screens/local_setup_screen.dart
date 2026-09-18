import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/form_section_card.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/entities/local_entities.dart';
import '../providers/local_providers.dart';

const _activityOptions = [
  'Coffee',
  'Walk',
  'Dinner',
  'Gaming',
  'Movie',
  'City exploration',
  'Conversation',
  'Shared hobbies'
];

/// Local profile setup (spec section 33). Entirely separate from the
/// professional profile — no company/role fields here, only what makes a
/// casual 1-to-1 meetup comfortable.
class LocalSetupScreen extends ConsumerStatefulWidget {
  const LocalSetupScreen({super.key});

  @override
  ConsumerState<LocalSetupScreen> createState() => _LocalSetupScreenState();
}

class _LocalSetupScreenState extends ConsumerState<LocalSetupScreen> {
  final _cityController = TextEditingController();
  final _areaController = TextEditingController();
  final _bioController = TextEditingController();
  bool _enabled = false;
  double _radiusKm = 5;
  final Set<String> _activities = {};
  bool _hydrated = false;
  bool _resolvingLocation = false;

  void _hydrate(LocalProfile? profile) {
    if (_hydrated) return;
    if (profile != null) {
      _cityController.text = profile.approximateCity ?? '';
      _areaController.text = profile.approximateArea ?? '';
      _bioController.text = profile.bio ?? '';
      _enabled = profile.enabled;
      _radiusKm = profile.preferredRadiusKm.toDouble();
      _activities.addAll(profile.activityPreferences);
    }
    _hydrated = true;
  }

  /// Approximate (2-decimal, ~1km-fuzzed) device coordinates, or null if
  /// permission/service was unavailable — an error is already shown to the
  /// user in that case. `get_local_candidates()` refuses to return anyone
  /// until `profiles.approx_latitude`/`approx_longitude` are set (privacy
  /// gate: you can't see nearby people until you've shared your own
  /// approximate position), so enabling Local discovery without this would
  /// silently never work.
  Future<(double, double)?> _resolveApproximateLocation() async {
    setState(() => _resolvingLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          context.showSnack('Turn on device location to enable Local discovery',
              isError: true);
        }
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          context.showSnack(
              'Location permission is required to enable Local discovery',
              isError: true);
        }
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low), // approximate only, by design
      );
      // Round to 2 decimals (matches profiles.approx_latitude/longitude's
      // numeric(6,2) column, ~1km precision) — fuzz it before it even
      // leaves the device.
      return (
        double.parse(position.latitude.toStringAsFixed(2)),
        double.parse(position.longitude.toStringAsFixed(2)),
      );
    } catch (_) {
      if (mounted) {
        context.showSnack('Could not determine your location', isError: true);
      }
      return null;
    } finally {
      if (mounted) setState(() => _resolvingLocation = false);
    }
  }

  Future<void> _save() async {
    double? lat;
    double? lng;
    if (_enabled) {
      final location = await _resolveApproximateLocation();
      if (location == null) return;
      (lat, lng) = location;
    }

    final success =
        await ref.read(localControllerProvider.notifier).saveLocalProfile(
              {
                'enabled': _enabled,
                'approximate_city': _cityController.text.trim().isEmpty
                    ? null
                    : _cityController.text.trim(),
                'approximate_area': _areaController.text.trim().isEmpty
                    ? null
                    : _areaController.text.trim(),
                'preferred_radius_km': _radiusKm.round(),
                'bio': _bioController.text.trim().isEmpty
                    ? null
                    : _bioController.text.trim(),
              },
              activities: _activities.toList(),
              interests: const [],
            );

    if (success && lat != null && lng != null) {
      await ref.read(profileControllerProvider.notifier).updateProfile({
        'approx_latitude': lat,
        'approx_longitude': lng,
      });
    }

    if (success && mounted) {
      context.showSnack('Local profile saved');
      context.pop();
    } else if (mounted) {
      context.showSnack('Could not save', isError: true);
    }
  }

  @override
  void dispose() {
    _cityController.dispose();
    _areaController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localProfileAsync = ref.watch(myLocalProfileProvider);
    final isSaving =
        ref.watch(localControllerProvider).isLoading || _resolvingLocation;

    return Scaffold(
      backgroundColor: HomeStyle.background,
      appBar: AppBar(
        backgroundColor: HomeStyle.background,
        title: const Text('Local Settings',
            style: TextStyle(color: HomeStyle.textPrimary)),
        iconTheme: const IconThemeData(color: HomeStyle.textPrimary),
      ),
      body: localProfileAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => Center(
            child: Text(e.toString(),
                style: const TextStyle(color: HomeStyle.textSecondary))),
        data: (profile) {
          _hydrate(profile);
          return ResponsiveCenter(
            maxWidth: 560,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FormSectionCard(
                    icon: Icons.near_me_outlined,
                    title: 'Local discovery',
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Enable Local discovery',
                                    style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: HomeStyle.textPrimary)),
                                SizedBox(height: 2),
                                Text(
                                    'Appear to compatible people nearby for 1-to-1 meetups',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: HomeStyle.textSecondary)),
                              ],
                            ),
                          ),
                          Switch(
                            value: _enabled,
                            onChanged: (v) => setState(() => _enabled = v),
                            activeThumbColor: Colors.white,
                            activeTrackColor: AppColors.localAccent,
                            inactiveThumbColor: HomeStyle.textSecondary,
                            inactiveTrackColor:
                                Colors.white.withValues(alpha: 0.10),
                          ),
                        ],
                      ),
                    ],
                  ),
                  FormSectionCard(
                    icon: Icons.place_outlined,
                    title: 'Where you are',
                    children: [
                      TextField(
                        controller: _cityController,
                        style: const TextStyle(color: HomeStyle.textPrimary),
                        decoration: darkInputDecoration('City'),
                      ),
                      TextField(
                        controller: _areaController,
                        style: const TextStyle(color: HomeStyle.textPrimary),
                        decoration: darkInputDecoration('Neighborhood / area'),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Search radius: ${_radiusKm.round()} km',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: HomeStyle.textPrimary)),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: AppColors.localAccent,
                              inactiveTrackColor:
                                  Colors.white.withValues(alpha: 0.12),
                              thumbColor: AppColors.localAccent,
                              overlayColor:
                                  AppColors.localAccent.withValues(alpha: 0.2),
                              valueIndicatorColor: AppColors.localAccent,
                            ),
                            child: Slider(
                              value: _radiusKm,
                              min: 1,
                              max: 25,
                              divisions: 24,
                              label: '${_radiusKm.round()} km',
                              onChanged: (v) => setState(() => _radiusKm = v),
                            ),
                          ),
                        ],
                      ),
                      TextField(
                        controller: _bioController,
                        maxLines: 3,
                        style: const TextStyle(color: HomeStyle.textPrimary),
                        decoration:
                            darkInputDecoration('A little about you (casual)'),
                      ),
                    ],
                  ),
                  FormSectionCard(
                    icon: Icons.local_activity_outlined,
                    title: 'What are you up for?',
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final activity in _activityOptions)
                            _ActivityChip(
                              label: activity,
                              selected: _activities.contains(activity),
                              onTap: () => setState(() {
                                _activities.contains(activity)
                                    ? _activities.remove(activity)
                                    : _activities.add(activity);
                              }),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: isSaving ? null : _save,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.localAccent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Save',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ActivityChip extends StatelessWidget {
  const _ActivityChip(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.localAccent.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
                color: selected
                    ? AppColors.localAccent
                    : Colors.white.withValues(alpha: 0.12)),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.localAccent : HomeStyle.textSecondary)),
        ),
      ),
    );
  }
}
