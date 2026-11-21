import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_content/game_content.dart';
import 'package:licurici/main.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici/features/settings/settings.dart';
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
    for (final (game, level) in [
      for (final game in allGames) (game, 1),
      for (final game in allGames.where((game) => {'culori', 'forme', 'potriveste', 'umbre', 'intrusul', 'arata-mi', 'corpul', 'ce-face', 'mingea-rosie', 'unde-e-ursul', 'primul-sunet', 'ce-se-aude', 'da-nu'}.contains(game.id))) (game, 8),
      for (final game in allGames.where((game) => game.id == 'forma-ascunsa')) (game, 14),
      for (final game in allGames.where((game) => game.id == 'pozitii')) (game, 11),
      for (final game in allGames.where((game) => game.id == 'povesti')) (game, 12),
      for (final game in allGames.where((game) => game.id == 'ce-ai-auzit')) (game, 12),
      for (final game in allGames.where((game) => game.id == 'continua-sirul')) (game, 10),
      for (final game in allGames.where((game) => game.id == 'potriveste')) (game, 10),
      for (final game in allGames.where((game) => game.id == 'intrusul')) (game, 10),
      for (final game in allGames.where((game) => game.id == 'umbre')) (game, 10),
      for (final game in allGames.where((game) => {'culori', 'forme'}.contains(game.id))) (game, 10),
      for (final game in allGames.where((game) => game.id == 'arata-mi')) (game, 10),
      for (final game in allGames.where((game) => game.id == 'corpul')) (game, 10),
      for (final game in allGames.where((game) => game.id == 'ce-face')) (game, 10),
      for (final game in allGames.where((game) => {'mingea-rosie', 'unde-e-ursul'}.contains(game.id))) (game, 10),
      for (final game in allGames.where((game) => game.id == 'primul-sunet')) (game, 10),
      for (final game in allGames.where((game) => game.id == 'da-nu')) (game, 10),
      for (final game in allGames.where((game) => game.id == 'ce-se-aude')) (game, 10),
      for (final game in allGames.where((game) => {'anotimpuri', 'habitate'}.contains(game.id))) (game, 9),
      for (final game in allGames.where((game) => {'cum-se-simte', 'cat-de-tare', 'cine-e-prietenul', 'emotii', 'ce-simte', 'ce-ma-ajuta', 'cine-stie', 'situatii'}.contains(game.id))) (game, 10),
      for (final game in allGames.where((game) => game.id == 'peste-in-mijloc')) (game, 9),
    ]) {
      testWidgets('${game.id} pe $device, nivel $level', (tester) async {
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
        if (level > 1) container.read(settingsProvider.notifier).setGameLevel(game.id, level);
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
        if (shots && level == 1) {
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
