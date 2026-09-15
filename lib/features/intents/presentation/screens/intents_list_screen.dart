import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/form_section_card.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../providers/intent_providers.dart';
import '../widgets/intent_card.dart';

/// Browse what other members currently want to accomplish (spec-extension:
/// Intent System). Declaring your own intent happens from My Intents / the
/// Create menu, not here — this is the discovery side. Search/type/skill
/// filters are applied client-side over [publicIntentsProvider] (which
/// already returns exactly what RLS allows this viewer to see) — see
/// [IntentFilters].
class IntentsListScreen extends ConsumerWidget {
  const IntentsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intentsAsync = ref.watch(filteredPublicIntentsProvider);
    final filters = ref.watch(intentFiltersProvider);

    return Scaffold(
      backgroundColor: HomeStyle.background,
      appBar: AppBar(
        backgroundColor: HomeStyle.background,
        title: const Text('Intents', style: TextStyle(color: HomeStyle.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'My intents',
            onPressed: () => context.push(RoutePaths.myIntents),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RoutePaths.newIntent),
        icon: const Icon(Icons.add),
        label: const Text('New intent'),
      ),
      body: ResponsiveCenter(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                style: const TextStyle(color: HomeStyle.textPrimary),
                decoration: darkInputDecoration('Search intents', suffixIcon: const Icon(Icons.search, color: HomeStyle.textSecondary)),
                onChanged: (v) =>
                    ref.read(intentFiltersProvider.notifier).update((f) => f.copyWith(searchText: v)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ChoiceChip(
                      label: const Text('All types'),
                      selected: filters.type == null,
                      onSelected: (_) => ref.read(intentFiltersProvider.notifier).update((f) => f.copyWith(type: () => null)),
                    ),
                    for (final t in IntentType.values) ...[
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(t.label),
                        selected: filters.type == t,
                        onSelected: (_) =>
                            ref.read(intentFiltersProvider.notifier).update((f) => f.copyWith(type: () => t)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(publicIntentsProvider),
                child: intentsAsync.when(
                  loading: () => const SkeletonList(),
                  error: (e, _) =>
                      ErrorState(message: e.toString(), onRetry: () => ref.invalidate(publicIntentsProvider)),
                  data: (intents) {
                    if (intents.isEmpty) {
                      return EmptyState(
                        icon: Icons.flag_outlined,
                        title: filters.isActive ? 'No intents match your filters' : 'No active intents yet',
                        message: filters.isActive ? null : 'Be the first to declare what you want to accomplish.',
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      itemCount: intents.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final it = intents[i];
                        return IntentCard(intent: it, onTap: () => context.push(RoutePaths.intentDetailOf(it.id)));
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
