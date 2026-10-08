import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/features/aquarium/coloring_screen.dart';
import 'package:licurici/features/coloring/color_play_screen.dart';
import 'package:licurici/features/coloring/coloring_pages.dart';
import 'package:licurici/features/coloring/drawings_store.dart';
import 'package:licurici/shared/voice.dart';

import 'layout_test.dart' show devices, loadFonts, settle, settleUntil, shots;

void main() {
  setUpAll(loadFonts);
  setUp(() {
    rootBundle.clear();
    svg.cache.clear();
  });

  for (final device in ['telefon-mic', 'tableta']) {
    testWidgets('colorăm: aleg casa, o colorez, apare în ramă și se păstrează ($device)', (tester) async {
      tester.view.physicalSize = devices[device]!;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = MemoryDrawingStore();
      final container = ProviderContainer(
        overrides: [
          voiceProvider.overrideWithValue(const SilentSpeaker()),
          drawingStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/coloram',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
          GoRoute(path: '/coloram', builder: (_, _) => const ColorPlayScreen()),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(theme: buildTheme(calm: false), routerConfig: router),
        ),
      );
      await settleUntil(tester, find.byKey(const ValueKey('species-casa')));
      for (final p in picturePages) {
        final r = tester.getRect(find.byKey(ValueKey('species-${p.id}')));
        expect(r.bottom, lessThanOrEqualTo(tester.view.physicalSize.height));
      }
      if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/coloram-alege-$device.png'));
      await tester.tap(find.byKey(const ValueKey('species-casa')));
      await settleUntil(tester, find.byKey(const ValueKey('sheet')));
      await tester.tap(find.byKey(const ValueKey('fill')));
      final sheet = tester.getRect(find.byKey(const ValueKey('sheet')));
      Offset at(double x, double y) => sheet.topLeft + Offset(x, y) * (sheet.width / 1000);
      // Cerul, peretele, acoperișul, iarba, soarele.
      for (final (color, x, y) in [(5, 100.0, 300.0), (1, 360.0, 450.0), (0, 460.0, 220.0), (3, 200.0, 570.0), (2, 860.0, 110.0)]) {
        await tester.tap(find.byKey(ValueKey('color-$color')));
        await settle(tester, 1);
        await tester.tapAt(at(x, y));
        await settle(tester, 3);
      }
      if (shots) await expectLater(find.byType(ColoringScreen), matchesGoldenFile('shots/coloram-casa-$device.png'));
      await tester.tap(find.byKey(const ValueKey('done')));
      await settleUntil(tester, find.byKey(const ValueKey('draw-again')));
      expect(tester.takeException(), isNull);
      expect((await store.load()).single.page, 'casa');
      await tester.tap(find.byKey(const ValueKey('draw-again')));
      await settleUntil(tester, find.byKey(const ValueKey('species-floare')));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }

  testWidgets('toate paginile de colorat se desenează', (tester) async {
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final p in picturePages) {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ColoredBox(color: Colors.white, child: CustomPaint(painter: _Page(p), size: Size.infinite)),
        ),
      );
      expect(tester.takeException(), isNull);
      if (shots) await expectLater(find.byType(CustomPaint).last, matchesGoldenFile('shots/pagina-${p.id}.png'));
    }
  });
}

class _Page extends CustomPainter {
  _Page(this.page);

  final ColoringPage page;

  @override
  void paint(Canvas canvas, Size size) => page.paintLines(canvas);

  @override
  bool shouldRepaint(_Page old) => old.page != page;
}
