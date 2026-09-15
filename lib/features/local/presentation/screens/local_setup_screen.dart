import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/loading_state.dart';
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
      appBar: AppBar(title: const Text('Local Settings')),
      body: localProfileAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (profile) {
          _hydrate(profile);
          return ResponsiveCenter(
            maxWidth: 560,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: AppColors.localAccent,
                    title: const Text('Enable Local discovery'),
                    subtitle: const Text(
                        'Appear to compatible people nearby for 1-to-1 meetups'),
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                  const Divider(height: 32),
                  TextField(
                      controller: _cityController,
                      decoration: const InputDecoration(labelText: 'City')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _areaController,
                      decoration: const InputDecoration(
                          labelText: 'Neighborhood / area')),
                  const SizedBox(height: 16),
                  Text('Search radius: ${_radiusKm.round()} km',
                      style: context.textStyles.titleSmall),
                  Slider(
                    value: _radiusKm,
                    min: 1,
                    max: 25,
                    divisions: 24,
                    activeColor: AppColors.localAccent,
                    label: '${_radiusKm.round()} km',
                    onChanged: (v) => setState(() => _radiusKm = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bioController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: 'A little about you (casual)',
                        alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 20),
                  Text('What are you up for?',
                      style: context.textStyles.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final activity in _activityOptions)
                        FilterChip(
                          label: Text(activity),
                          selected: _activities.contains(activity),
                          selectedColor:
                              AppColors.localAccent.withValues(alpha: 0.2),
                          onSelected: (selected) => setState(() {
                            selected
                                ? _activities.add(activity)
                                : _activities.remove(activity);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.localAccent),
                      onPressed: isSaving ? null : _save,
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Save'),
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
