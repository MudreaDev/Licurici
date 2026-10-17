import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/mirror/mirror_screen.dart';
import 'package:licurici/shared/stimulus_art.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici_core/licurici_core.dart';

import 'layout_test.dart' show devices, loadFonts, settle, shots;

void main() {
  // Cu portretele pictate încărcate: atingerile folosesc geometria măsurată pe fiecare copil.
  setUpAll(() async {
    await loadFonts();
    await IllustrationIndex.load();
  });
  setUp(() {
    rootBundle.clear();
    svg.cache.clear();
  });

  test('pe fiecare copil pictat, fiecare parte a feței e recunoscută în punctul ei', () {
    for (final look in paintedLooks) {
      for (final part in FacePart.values) {
        for (final side in part.paired ? const [-1, 1] : const [null]) {
          final c = partCenter(part, side, look);
          expect(c.dx, inInclusiveRange(0, 1));
          expect(c.dy, inInclusiveRange(0, 1));
          expect(touchAt(c, look), MirrorTouch(part, side), reason: '${look.paintedId} ${part.name} $side');
        }
      }
    }
  });

  for (final (device, level) in [('telefon-mic', 1), ('tableta', 4), ('telefon-mic', 6)]) {
    testWidgets('Oglinda pictată: nivelul $level pe $device, o atingere greșită, apoi la fel ca Licurici', (tester) async {
      tester.view.physicalSize = devices[device]!;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())]);
      addTearDown(container.dispose);
      container.read(mirrorLevelProvider.notifier).setLevel(level);
      final router = GoRouter(
        initialLocation: '/t',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
          GoRoute(path: '/t', builder: (_, _) => const MirrorScreen(seed: 3)),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: MaterialApp.router(theme: buildTheme(calm: false), routerConfig: router)),
      );
      await tester.pump(const Duration(seconds: 5));
      if (shots) await expectLater(find.byType(MirrorScreen), matchesGoldenFile('shots/oglinda-pictata-$device-$level.png'));
      final l = const MirrorGame().generate(level, seed: 3);
      Future<void> touch(MirrorTouch t, FaceLook look) async {
        final rect = tester.getRect(find.byKey(const ValueKey('mirror-face')));
        final c = partCenter(t.part, t.side ?? -1, look);
        await tester.tapAt(rect.topLeft + Offset(c.dx * rect.width, c.dy * rect.height));
        await tester.pump(const Duration(milliseconds: 200));
      }

      for (final (i, r) in l.rounds.indexed) {
        // Demonstrația lui Licurici.
        await tester.pump(const Duration(seconds: 6));
        if (i == 0) {
          final wrong = FacePart.values.firstWhere((p) => p != r.touches.first.part);
          await touch(MirrorTouch(wrong, wrong.paired ? -1 : null), r.mirror);
          if (shots) await expectLater(find.byType(MirrorScreen), matchesGoldenFile('shots/oglinda-pictata-atinsa-$device-$level.png'));
        }
        for (final t in r.touches) {
          await touch(t, r.mirror);
        }
        await tester.pump(const Duration(seconds: 2));
      }
      await settle(tester, 10);
      expect(find.text('Încă o dată'), findsOneWidget);
      final trials = container.read(sessionProvider)!.trials;
      expect(trials.map((t) => t.correct), [false, true, true, true, true]);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    });
  }
}
