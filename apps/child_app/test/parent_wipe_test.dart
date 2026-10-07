import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/aquarium/aquarium_store.dart';
import 'package:licurici/features/parent/parent_screen.dart';
import 'package:licurici/features/settings/settings.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici_core/licurici_core.dart';

import 'layout_test.dart' show devices, loadFonts, settle;

void main() {
  setUpAll(loadFonts);

  testWidgets('pentru părinți: datele de pe tabletă se șterg doar după confirmare', (tester) async {
    tester.view.physicalSize = devices['tableta']!;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sessions = MemorySessionStore();
    final record = demoChildren().first.sessions.first;
    await sessions.save(SessionRecord.fromJson({...record.toJson(), 'childId': localChildId}));
    final aquarium = MemoryAquariumStore();
    await aquarium.save([AquariumEntry(id: 'p1', species: 'clovn', created: DateTime(2026))], drawing: ('p1', Uint8List(4)));
    final container = ProviderContainer(
      overrides: [
        voiceProvider.overrideWithValue(const SilentSpeaker()),
        sessionStoreProvider.overrideWithValue(sessions),
        aquariumStoreProvider.overrideWithValue(aquarium),
      ],
    );
    addTearDown(container.dispose);
    container.read(settingsProvider.notifier)
      ..addStars(5)
      ..awardSticker();
    final router = GoRouter(routes: [GoRoute(path: '/', builder: (_, _) => const ParentScreen())]);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: buildTheme(calm: false), routerConfig: router),
      ),
    );
    await settle(tester, 3);
    expect(find.byKey(ValueKey('session-${record.id}')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('wipe-device')));
    await settle(tester, 2);
    expect(await sessions.all(), hasLength(1)); // doar dialogul
    await tester.tap(find.byKey(const ValueKey('wipe-confirm')));
    await settle(tester, 4);

    expect(await sessions.all(), isEmpty);
    expect(await aquarium.load(), isEmpty);
    final s = container.read(settingsProvider);
    expect(s.stickers, isEmpty);
    expect(s.stars, AppSettings.startStars);
    expect(find.byKey(ValueKey('session-${record.id}')), findsNothing);
    expect(find.text('Datele de pe tabletă au fost șterse.'), findsOneWidget);
  });
}
