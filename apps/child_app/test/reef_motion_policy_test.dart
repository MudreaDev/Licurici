import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/features/aquarium/aquarium_dock.dart';
import 'package:licurici/features/aquarium/aquarium_screen.dart';
import 'package:licurici/features/aquarium/aquarium_store.dart';
import 'package:licurici/features/aquarium/reef_life.dart';
import 'package:licurici/features/aquarium/reef_night.dart';
import 'package:licurici/features/aquarium/reef_particle_budget.dart';
import 'package:licurici/features/aquarium/reef_scene.dart';
import 'package:licurici/features/settings/settings.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici_core/licurici_core.dart';

import 'layout_test.dart' show settleUntil;

void main() {
  test('bugetul comun al particulelor nu depășește 40', () {
    expect(ReefParticleBudget.total, lessThanOrEqualTo(40));
  });

  testWidgets('raftul respectă modul fără mișcare și ținta minimă', (tester) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final picture = ui.PictureRecorder();
    Canvas(picture).drawRect(const Rect.fromLTWH(0, 0, 8, 8), Paint()..color = Colors.blue);
    final art = await picture.endRecording().toImage(8, 8);
    addTearDown(art.dispose);
    final species = fishSpecies.first;
    final fish = OwnedFish(AquariumEntry(id: 'a', species: species.id, created: DateTime(2026)), species, art);

    Widget screen(bool movement) => ProviderScope(child: MaterialApp(home: Scaffold(
      body: Center(child: FishShelf(fish: [fish], picked: 'a', onPick: (_) {}, movement: movement)),
    )));
    await tester.pumpWidget(screen(false));
    expect(find.byType(Animate), findsNothing);
    final size = tester.getSize(find.byKey(const ValueKey('shelf-a')));
    expect(size.width, greaterThanOrEqualTo(64));
    expect(size.height, greaterThanOrEqualTo(64));
    await tester.pumpWidget(screen(true));
    expect(find.byType(Animate), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('particulele din toate straturile se opresc în modul calm', (tester) async {
    final time = ValueNotifier(0.0);
    final chest = ReefChest();
    addTearDown(time.dispose);
    addTearDown(chest.dispose);
    await tester.pumpWidget(MaterialApp(home: SizedBox(
      width: 640, height: 360,
      child: ReefScene(ambient: time, chest: chest, particles: false, child: const SizedBox()),
    )));
    final painters = tester.widgetList<CustomPaint>(find.byType(CustomPaint)).map((w) => w.painter).toList();
    expect(painters.whereType<ReefAmbiencePainter>().single.particles, isFalse);
    expect(painters.whereType<ReefFrontPainter>().single.particles, isFalse);
    final night = ValueNotifier(1.0);
    final finger = ValueNotifier<Offset?>(null);
    addTearDown(night.dispose);
    addTearDown(finger.dispose);
    final withParticles = ReefNightPainter(time: time, night: night, finger: finger, chest: chest);
    final calm = ReefNightPainter(time: time, night: night, finger: finger, chest: chest, particles: false);
    expect(calm.shouldRepaint(withParticles), isTrue);
  });

  testWidgets('indiciul și pușculița nu se mișcă în modul calm', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: [
      settingsProvider.overrideWith(() => SettingsNotifier(const AppSettings(calm: true))),
      aquariumStoreProvider.overrideWithValue(MemoryAquariumStore()),
      voiceProvider.overrideWithValue(const SilentSpeaker()),
    ]);
    addTearDown(container.dispose);
    final router = GoRouter(initialLocation: '/acvariu', routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/acvariu', builder: (_, _) => const AquariumScreen()),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: router)));
    await settleUntil(tester, find.byKey(const ValueKey('feed')));
    await tester.runAsync(() => container.read(aquariumProvider.future));
    await tester.pump();
    final hint = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_GiftHint');
    final purse = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_StarPurse');
    expect(hint, findsOneWidget);
    expect(purse, findsOneWidget);
    expect(find.descendant(of: hint, matching: find.byType(Animate)), findsNothing);
    expect(find.descendant(of: purse, matching: find.byType(Animate)), findsNothing);
    container.read(settingsProvider.notifier).toggleCalm();
    await tester.pump();
    expect(find.descendant(of: hint, matching: find.byType(Animate)), findsOneWidget);
    expect(find.descendant(of: purse, matching: find.byType(Animate)), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
