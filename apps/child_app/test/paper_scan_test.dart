import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/features/aquarium/aquarium_screen.dart';
import 'package:licurici/features/aquarium/aquarium_store.dart';
import 'package:licurici/features/aquarium/fish_art.dart';
import 'package:licurici/features/aquarium/paper_scan_flow.dart';
import 'package:licurici/features/aquarium/paper_sheet.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici_core/licurici_core.dart';

import 'layout_test.dart' show devices, loadFonts, settle, settleUntil, shots;

/// O „fotografie”: fișa colorată (corp roșu), puțin rotită, pe o masă maro, PNG.
Future<Uint8List> _photo(FishSpecies s, {bool withSheet = true}) async {
  const w = 1600, h = 1200;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec)..drawRect(const Rect.fromLTWH(0, 0, w + 0.0, h + 0.0), Paint()..color = const Color(0xFF7A5A3C));
  if (withSheet) {
    c
      ..translate(130, 170)
      ..rotate(0.05)
      ..scale(4.4);
    paintPaperSheet(c, s);
    c
      ..translate(PaperSheet.boxLeft, PaperSheet.boxTop)
      ..scale(PaperSheet.boxScale)
      ..drawPath(curvePath(s.body), Paint()..color = const Color(0xFFDC2828));
    paintLineArt(c, s);
  }
  final img = await rec.endRecording().toImage(w, h);
  final png = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  img.dispose();
  return png;
}

void main() {
  setUpAll(loadFonts);
  setUp(() {
    rootBundle.clear();
    svg.cache.clear();
  });

  test('fișele PDF se construiesc pentru toate modelele', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final pdf = await buildSheetsPdf(fishSpecies);
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    expect(pdf.length, greaterThan(10000));
  });

  for (final device in ['telefon-mic', 'tableta']) {
    testWidgets('peștele de pe hârtie: poza fișei → peștele intră în acvariu ($device)', (tester) async {
      tester.view.physicalSize = devices[device]!;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final species = fishSpeciesById('inger')!;
      final photos = [
        (await tester.runAsync(() => _photo(species, withSheet: false)))!,
        (await tester.runAsync(() => _photo(species)))!,
      ];
      final container = ProviderContainer(
        overrides: [
          voiceProvider.overrideWithValue(const SilentSpeaker()),
          aquariumStoreProvider.overrideWithValue(MemoryAquariumStore()),
          photoSourceProvider.overrideWithValue(() async => photos.removeAt(0)),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/acvariu',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
          GoRoute(path: '/acvariu', builder: (_, _) => const AquariumScreen()),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(theme: buildTheme(calm: false), routerConfig: router),
        ),
      );
      await settleUntil(tester, find.byKey(const ValueKey('scan-paper')));
      await tester.runAsync(() => container.read(aquariumProvider.future));

      // Prima poză nu are fișă: Licurici spune blând ce să facem; încercăm din nou.
      await tester.tap(find.byKey(const ValueKey('scan-paper')));
      await settleUntil(tester, find.byKey(const ValueKey('scan-retry')));
      if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/scanare-problema-$device.png'));
      await tester.tap(find.byKey(const ValueKey('scan-retry')));
      for (var i = 0; i < 80 && (container.read(aquariumProvider).value?.length ?? 0) < 2; i++) {
        await settle(tester, 1);
      }
      final fish = container.read(aquariumProvider).value!;
      expect(fish, hasLength(2));
      expect(fish.last.species.id, 'inger');
      await settle(tester, 30);
      if (shots) await expectLater(find.byType(AquariumScreen), matchesGoldenFile('shots/scanare-$device.png'));
      expect(tester.takeException(), isNull);
    });
  }
}
