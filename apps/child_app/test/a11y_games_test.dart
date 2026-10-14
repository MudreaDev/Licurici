import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/features/coloring/drawings_store.dart';
import 'package:licurici/main.dart' show routerProvider;
import 'package:licurici/shared/voice.dart';

import 'layout_test.dart' show loadFonts, settle;

/// Accesibilitatea jocurilor (README §19): tot ce se apasă are o etichetă (cititorul de ecran
/// spune ce e) și e destul de mare. Prin ruterul real, pe tabletă.
void main() {
  setUpAll(loadFonts);
  setUp(() {
    rootBundle.clear();
    svg.cache.clear();
  });

  const paths = [
    '/sortam', '/sortam/la-locul-lui', '/sortam/sortam-emotiile', '/fa-ca-licuriciul', '/regula-se-schimba', '/unde-se-uita', '/la-magazin', '/construieste',
    '/diferente', '/labirint', '/puzzle', '/ce-s-a-schimbat', '/atinge-si-vezi', '/hraneste-pestii', '/toba-magica',
    '/vorbeste', '/cauta', '/pe-rand', '/coloram', '/urmareste-pestele', '/semaforul', '/asteapta/floarea-creste', '/traseaza', '/traseaza/uneste-punctele', '/cucu-bau',
    '/secventa/simon', '/secventa/licuricii', '/album', '/linia-numerelor', '/atinge-rapid', '/reactie/paznicul-farului',
  ];

  for (final path in paths) {
    testWidgets('$path: ținte și etichete', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final handle = tester.ensureSemantics();
      final container = ProviderContainer(
        overrides: [
          voiceProvider.overrideWithValue(const SilentSpeaker()),
          drawingStoreProvider.overrideWithValue(MemoryDrawingStore()),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(routerProvider)..go(path);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(theme: buildTheme(calm: false), routerConfig: router),
        ),
      );
      await settle(tester, 4);
      await tester.pump(const Duration(seconds: 3));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    });
  }
}
