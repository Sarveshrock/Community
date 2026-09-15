// Renders the redesigned (dark, animated) Intent Matches screen at every
// phone size this session's redesigns test at, and locks down the new
// AI-rationale/compatibility-breakdown rendering added for the "AI-Powered
// Intent Matching" hackathon centerpiece — while confirming a match with no
// AI rationale (i.e. no AI_PROVIDER configured server-side) still renders
// correctly using only the deterministic reasons[]/score.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:community_app/core/models/skill.dart';
import 'package:community_app/features/intents/presentation/providers/intent_providers.dart';
import 'package:community_app/features/intents/presentation/screens/intent_matches_screen.dart';

final _intent = UserIntent(
  id: 'intent-1',
  profileId: 'priya-1',
  intentType: IntentType.findCofounder,
  title: 'Looking for a technical co-founder',
  experienceLevel: ExperienceLevel.advanced,
  visibility: IntentVisibility.public,
  expiresAt: DateTime.now().add(const Duration(days: 90)),
  createdAt: DateTime.now(),
);

const _strongMatch = MatchResult(
  candidateId: 'rahul-1',
  score: 92,
  fullName: 'Rahul Verma',
  currentRole: 'Backend Engineer',
  reasons: ['They have the skills you need: Node.js, PostgreSQL, AWS', 'Shared interest in Startups'],
  matchedSkills: ['Node.js', 'PostgreSQL', 'AWS'],
  aiRationale: 'Rahul has exactly the backend skills you need for your fintech co-founder search.',
  scoreBreakdown: {'skills': 1.0, 'interests': 0.67, 'experience': 1.0, 'availability': 1.0},
);

const _weakerMatch = MatchResult(
  candidateId: 'ananya-1',
  score: 38,
  fullName: 'Ananya Iyer',
  currentRole: 'Data Scientist',
  reasons: ['They have the skills you need: AWS'],
  matchedSkills: ['AWS'],
  scoreBreakdown: {'skills': 0.33, 'interests': 0.0, 'experience': 0.5, 'availability': 0.0},
);

const _communityRecommendation = IntentRecommendation(
  recommendationType: RecommendationType.community,
  targetId: 'community-1',
  title: 'AI Builders',
  score: 78,
  reasons: ['Rahul is a member.', '2 more of your connections are also a member.'],
  aiRationale: 'Rahul is a member of AI Builders, which matches the backend skills your Intent needs.',
);

const _eventRecommendationNoRationale = IntentRecommendation(
  recommendationType: RecommendationType.event,
  targetId: 'event-1',
  title: 'AI Hackathon 2026',
  score: 61,
  reasons: ['Rahul is attending.'],
);

Widget _harness({
  required List<MatchResult> matches,
  List<IntentRecommendation>? recommendations,
}) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const IntentMatchesScreen(intentId: 'intent-1')),
    GoRoute(path: '/people/:id', builder: (_, __) => const Scaffold(body: Text('Person'))),
    GoRoute(path: '/communities/:id', builder: (_, __) => const Scaffold(body: Text('Community'))),
    GoRoute(path: '/events/:id', builder: (_, __) => const Scaffold(body: Text('Event'))),
  ]);
  return ProviderScope(
    overrides: [
      intentDetailProvider('intent-1').overrideWith((ref) async => _intent),
      intentMatchesProvider('intent-1').overrideWith((ref) async => matches),
      if (recommendations != null)
        intentRecommendationsProvider('intent-1').overrideWith((ref) async => recommendations),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  const phoneSizes = <String, Size>{
    'very small phone (320x568)': Size(320, 568),
    'small Android (360x800)': Size(360, 800),
    'iPhone SE-ish (375x812)': Size(375, 812),
    'iPhone 12/13 (390x844)': Size(390, 844),
    'large phone (414x896)': Size(414, 896),
    'large phone (430x932)': Size(430, 932),
  };

  for (final entry in phoneSizes.entries) {
    testWidgets('Intent Matches lays out with no overflow on ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness(matches: const [_strongMatch, _weakerMatch]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200)); // let entrance/score animations settle

      expect(tester.takeException(), isNull);
      expect(find.text('Matches'), findsOneWidget);
      expect(find.text('Rahul Verma'), findsOneWidget);
      expect(find.text('Ananya Iyer'), findsOneWidget);
    });
  }

  testWidgets('shows the real AI rationale when present, promoted above the raw reasons', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(matches: const [_strongMatch]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.textContaining('exactly the backend skills you need'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsWidgets);
  });

  testWidgets('a match with no AI rationale still renders correctly via deterministic reasons', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(matches: const [_weakerMatch]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

    expect(tester.takeException(), isNull);
    expect(find.text('Ananya Iyer'), findsOneWidget);
    // No rationale card for this one (weaker match has no aiRationale).
    expect(find.textContaining('exactly the backend skills'), findsNothing);

    await tester.tap(find.text('See match details'));
    await tester.pump();
    expect(find.textContaining('They have the skills you need: AWS'), findsOneWidget);
  });

  testWidgets('shows the compatibility breakdown bars for each score component', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(matches: const [_strongMatch]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('Skills'), findsOneWidget);
    expect(find.text('Interests'), findsOneWidget);
    expect(find.text('Experience'), findsOneWidget);
    expect(find.text('Availability'), findsOneWidget);
  });

  testWidgets('an empty match list shows the empty state, not a broken layout', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(matches: const []));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('No matches yet'), findsOneWidget);
  });

  group('"Because of this match" — cross-entity recommendations', () {
    testWidgets('shows a "Because of this match" section with community/event cards', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness(
        matches: const [_strongMatch],
        recommendations: const [_communityRecommendation, _eventRecommendationNoRationale],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));

      expect(tester.takeException(), isNull);
      expect(find.text('Because of this match'), findsOneWidget);
      expect(find.text('AI Builders'), findsOneWidget);
      expect(find.text('AI Hackathon 2026'), findsOneWidget);
      expect(find.text('Explore'), findsOneWidget);
      expect(find.text('View Event'), findsOneWidget);
    });

    testWidgets('promotes the real AI rationale, and falls back to the first grounded reason without one', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness(
        matches: const [_strongMatch],
        recommendations: const [_communityRecommendation, _eventRecommendationNoRationale],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));

      expect(find.textContaining('matches the backend skills your Intent needs'), findsOneWidget);
      expect(find.text('Rahul is attending.'), findsOneWidget);
    });

    testWidgets('"Why am I seeing this?" expands to show every grounded reason', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness(
        matches: const [_strongMatch],
        recommendations: const [_communityRecommendation],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));

      await tester.ensureVisible(find.text('Why am I seeing this?'));
      await tester.pump();
      await tester.tap(find.text('Why am I seeing this?'));
      await tester.pump();

      expect(find.text('Rahul is a member.'), findsOneWidget);
      expect(find.text('2 more of your connections are also a member.'), findsOneWidget);
    });

    testWidgets('tapping a recommendation card navigates to its detail route', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness(
        matches: const [_strongMatch],
        recommendations: const [_communityRecommendation],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));

      await tester.ensureVisible(find.text('Explore'));
      await tester.pump();
      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();

      expect(find.text('Community'), findsOneWidget);
    });

    testWidgets('no recommendations (e.g. no AI provider / network layer failed) hides the section entirely', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness(matches: const [_strongMatch], recommendations: const []));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));

      expect(tester.takeException(), isNull);
      expect(find.text('Because of this match'), findsNothing);
    });

    testWidgets('recommendations provider erroring never breaks the person-matches list above it', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, __) => const IntentMatchesScreen(intentId: 'intent-1')),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          intentDetailProvider('intent-1').overrideWith((ref) async => _intent),
          intentMatchesProvider('intent-1').overrideWith((ref) async => const [_strongMatch]),
          intentRecommendationsProvider('intent-1').overrideWith((ref) async => throw Exception('network layer down')),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));

      expect(tester.takeException(), isNull);
      expect(find.text('Rahul Verma'), findsOneWidget);
      expect(find.text('Because of this match'), findsNothing);
    });
  });
}
