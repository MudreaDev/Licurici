import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/aac/aac_screen.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici_core/licurici_core.dart';

import 'layout_test.dart' show devices, loadFonts, settle, shots;

class _Ears implements Speaker {
  final said = <String>[];
  @override
  Future<void> say(List<String> parts) async => said.addAll(parts);
  @override
  Future<void> stop() async {}
}

void main() {
  setUpAll(loadFonts);
  setUp(() {
    rootBundle.clear();
    svg.cache.clear();
  });

  for (final device in ['telefon-mic', 'tableta']) {
    testWidgets('vorbește: fila, poza, propoziția rostită și notată ($device)', (
      tester,
    ) async {
      tester.view.physicalSize = devices[device]!;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final ears = _Ears();
      final container = ProviderContainer(
        overrides: [voiceProvider.overrideWithValue(ears)],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/v',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
          GoRoute(path: '/v', builder: (_, _) => const AacScreen()),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: buildTheme(calm: false),
            routerConfig: router,
          ),
        ),
      );
      await settle(tester, 3);
      // Toate pictogramele filei „Vreau” se văd, fără derulare.
      final vreau = aacBoard.first;
      for (var i = 0; i < vreau.words.length; i++) {
        final r = tester.getRect(find.byKey(ValueKey('aac-word-$i')));
        expect(r.bottom, lessThanOrEqualTo(devices[device]!.height));
        expect(r.shortestSide, greaterThanOrEqualTo(56));
      }
      await tester.tap(find.byKey(const ValueKey('aac-word-0')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(ears.said.last, 'Vreau apă');
      await tester.tap(find.byKey(const ValueKey('aac-tab-simt')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(ears.said.last, 'Mă simt');
      await tester.tap(find.byKey(const ValueKey('aac-word-4')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(ears.said.last, 'Mă simt obosit');
      await tester.tap(find.byKey(const ValueKey('aac-speak')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(ears.said.last, 'Mă simt obosit');
      if (shots) {
        await expectLater(
          find.byType(AacScreen),
          matchesGoldenFile('shots/vorbeste-$device.png'),
        );
      }
      final events = container.read(sessionProvider)!.close()!.events;
      expect(events.where((e) => e.kind == SessionEventKind.request), hasLength(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }
}
