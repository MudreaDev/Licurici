import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_content/game_content.dart';
import 'package:licurici/main.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici_core/licurici_core.dart';

import 'layout_test.dart' show devices, loadFonts, settle, settleUntil, shots;

/// Fiecare joc `choice` se deschide și prima rundă încape pe telefonul mic și pe tabletă
/// (orice depășire de layout pică testul). Cu `SHOTS=true` scrie și capturi.
void main() {
  setUpAll(loadFonts);
  setUp(() {
    rootBundle.clear();
    svg.cache.clear();
  });

  for (final device in ['telefon-mic', 'tableta']) {
    for (final game in allGames) {
      testWidgets('${game.id} pe $device', (tester) async {
        tester.view.physicalSize = devices[device]!;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final container = ProviderContainer(
          overrides: [
            voiceProvider.overrideWithValue(const SilentSpeaker()),
            voiceManifestProvider.overrideWith(
              (ref) => VoiceManifest(const {}),
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const LicuriciApp(),
          ),
        );
        await settleUntil(tester, find.byKey(const ValueKey('domain-ATN')));
        container.read(routerProvider).go('/joc/${game.id}');
        // „Cum te simți?” apare doar la primul joc pornit de pe ecranul principal.
        final mood = find.byKey(const ValueKey('mood-bucuros'));
        final firstChoice = find.byKey(const ValueKey('choice-0'));
        for (
          var i = 0;
          i < 60 && mood.evaluate().isEmpty && firstChoice.evaluate().isEmpty;
          i++
        ) {
          await settle(tester, 1);
        }
        if (mood.evaluate().isNotEmpty) await tester.tap(mood);
        await settleUntil(tester, firstChoice);
        if (shots) {
          await expectLater(
            find.byType(LicuriciApp),
            matchesGoldenFile('shots/joc-${game.id}-$device.png'),
          );
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 10));
      });
    }
  }
}
