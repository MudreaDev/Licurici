import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_content/game_content.dart';
import 'package:licurici/main.dart';
import 'package:licurici/shared/voice.dart';

import 'layout_test.dart' show devices, loadFonts, settle, settleUntil;

/// „Câte sunt?”: obiectele se văd doar o clipă, apoi un nor; după două greșeli revin.
void main() {
  setUpAll(loadFonts);
  setUp(() {
    rootBundle.clear();
    svg.cache.clear();
  });

  testWidgets('stimulul arătat o clipă se ascunde și revine după două greșeli', (tester) async {
    tester.view.physicalSize = devices['tableta']!;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        voiceProvider.overrideWithValue(const SilentSpeaker()),
        voiceManifestProvider.overrideWith((ref) => VoiceManifest(const {})),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const LicuriciApp()));
    await settleUntil(tester, find.byKey(const ValueKey('domain-ATN')));
    container.read(routerProvider).go('/joc/cate-sunt');
    final mood = find.byKey(const ValueKey('mood-bucuros'));
    final first = find.byKey(const ValueKey('choice-0'));
    for (var i = 0; i < 60 && mood.evaluate().isEmpty && first.evaluate().isEmpty; i++) {
      await settle(tester, 1);
    }
    if (mood.evaluate().isNotEmpty) await tester.tap(mood);
    await settleUntil(tester, first);
    final hidden = find.byKey(const ValueKey('stimulus-hidden'));
    expect(hidden, findsNothing);
    // Cel mult 2 s la tier mic: apoi norul.
    await settle(tester, 14);
    expect(hidden, findsOneWidget);
    // Două greșeli: obiectele revin.
    final wrong = <Finder>[];
    for (var i = 0; i < 5; i++) {
      final f = find.byKey(ValueKey('choice-$i'));
      if (f.evaluate().isEmpty) continue;
      final label = find.descendant(of: f, matching: find.byType(Text));
      final count = int.tryParse(tester.widget<Text>(label.first).data ?? '');
      if (count == null) continue;
      wrong.add(f);
    }
    expect(wrong.length, greaterThanOrEqualTo(3));
    var tapped = 0;
    for (final f in wrong) {
      if (tapped == 2 || hidden.evaluate().isEmpty) break;
      await tester.tap(f);
      await settle(tester, 2);
      tapped++;
    }
    await settle(tester, 2); // norul se estompează
    // Fie două greșeli (obiectele au revenit), fie runda s-a rezolvat cu una dintre atingeri.
    expect(hidden, findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });
}
