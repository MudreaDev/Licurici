import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/features/games/sequence/simon_screen.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici_core/licurici_core.dart';

import 'layout_test.dart' show devices, shots;
import 'praise_finders.dart';

class _Game extends SpatialSpanGame {
  final levels = <SequenceLevel>[];
  @override
  SequenceLevel generate(int level, {int? seed}) {
    final result = super.generate(level, seed: 5);
    levels.add(result);
    return result;
  }
}

void main() {
  for (final device in ['telefon-mic', 'tableta']) {
    testWidgets('licuricii din grădină: florile împrăștiate, aceeași ordine, nivelul crește ($device)', (tester) async {
      tester.view.physicalSize = devices[device]!;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final game = _Game();
      final router = GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => SimonScreen(game: game, initialLevel: 4))],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())],
          child: MaterialApp.router(
            theme: buildTheme(calm: true),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Începem'));
      await tester.pump();
      final level = game.levels.last;
      expect(level.positions, isNotNull);
      // Florile sunt toate pe ecran și nu se suprapun.
      final rects = [for (var i = 0; i < level.pads.length; i++) tester.getRect(find.byKey(ValueKey('simon-pad-$i')))];
      final screen = Offset.zero & tester.view.physicalSize;
      for (final (i, r) in rects.indexed) {
        expect(screen.contains(r.center), isTrue);
        for (final o in rects.skip(i + 1)) {
          expect(r.overlaps(o.deflate(o.width * 0.2)), isFalse);
        }
      }
      await tester.pump(const Duration(milliseconds: 450));
      for (var k = 0; k < level.sequence.length; k++) {
        await tester.pump(Duration(milliseconds: level.axes.onMs ~/ 2));
        if (k == 0 && shots) await expectLater(find.byType(SimonScreen), matchesGoldenFile('shots/licuricii-$device.png'));
        await tester.pump(Duration(milliseconds: level.axes.onMs - level.axes.onMs ~/ 2));
        await tester.pump(Duration(milliseconds: level.axes.gapMs));
      }
      for (final index in level.expected) {
        await tester.tap(find.byKey(ValueKey('simon-pad-$index')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));
      }
      expect(findPraise(), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(game.levels.last.level, 5);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
