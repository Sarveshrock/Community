// Renders EventCard with worst-case data (a long title, long host name,
// long city) at every phone width the redesign brief calls out.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:community_app/features/events/domain/entities/event.dart';
import 'package:community_app/features/events/presentation/widgets/event_card.dart';

final _event = CommunityEvent(
  id: 'event-1',
  hostId: 'host-1',
  hostName: 'Alexandria Wolfeschlegelsteinhausenbergerdorff',
  title: 'The Annual International AI, Cloud & Cybersecurity Community Meetup',
  eventType: 'conference',
  mode: 'offline',
  city: 'A Very Long City Name, State',
  startsAt: DateTime.now().add(const Duration(days: 10)),
  isFree: false,
  price: 1999,
  currency: 'INR',
  attendeeCount: 128,
);

Widget _harness(double width) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => Scaffold(body: SizedBox(width: width, child: EventCard(event: _event)))),
    GoRoute(path: '/events/:id', builder: (_, __) => const Scaffold()),
  ]);
  return ProviderScope(child: MaterialApp.router(routerConfig: router));
}

void main() {
  const widths = <String, double>{
    'very small phone (320)': 320,
    'small Android (360)': 360,
    'iPhone SE-ish (375)': 375,
    'iPhone 12/13 (390)': 390,
    'large phone (414)': 414,
    'large phone (430)': 430,
  };

  for (final entry in widths.entries) {
    testWidgets('EventCard lays out with no overflow on ${entry.key}', (tester) async {
      tester.view.physicalSize = Size(entry.value, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness(entry.value));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  }
}
