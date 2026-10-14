import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:licurici/app/nav_memory.dart';
import 'package:licurici/features/settings/settings.dart';
import 'package:licurici/main.dart';
import 'package:licurici/shared/music.dart';
import 'package:game_content/game_content.dart';
import 'package:licurici/shared/voice.dart';

/// Vocea care ține minte de câte ori a fost oprită.
class _Ears implements Speaker {
  int stops = 0;
  final said = <String>[];
  @override
  Future<void> say(List<String> parts) async => said.addAll(parts);
  @override
  Future<void> stop() async => stops++;
}

void main() {
  test('rutele de joc și locurile care nu sunt jocuri', () {
    for (final p in ['/', '/arie/pot', '/acvariu', '/acvariu/coloreaza', '/album', '/harta', '/parinte']) {
      expect(isGameRoute(p), isFalse, reason: p);
    }
    for (final p in ['/joc/potriveste', '/perechi', '/secventa/simon', '/exploreaza/x/oprire/1']) {
      expect(isGameRoute(p), isTrue, reason: p);
    }
  });

  testWidgets('lista își păstrează poziția: controlerul nou pornește de unde a rămas', (tester) async {
    final memory = NavMemory()..enterMenu('/arie/pot');
    expect(memory.menu, '/arie/pot');
    final first = memory.controllerFor('/arie/pot');
    await tester.pumpWidget(
      MaterialApp(
        home: ListView(
          controller: first,
          scrollDirection: Axis.horizontal,
          children: [for (var i = 0; i < 40; i++) SizedBox(width: 200, child: Text('$i'))],
        ),
      ),
    );
    first.jumpTo(900);
    await tester.pump();
    expect(memory.offset('/arie/pot'), 900);
    await tester.pumpWidget(const SizedBox());
    first.dispose();
    final again = memory.controllerFor('/arie/pot');
    expect(again.initialScrollOffset, 900);
    expect(memory.controllerFor('/').initialScrollOffset, 0);
    again.dispose();
  });

  test('muzica: tace unde sunetul e sarcina și în acvariu; mai încet cât vorbește Licurici', () {
    for (final p in ['/acvariu', '/secventa/simon', '/toba-magica', '/asculta-si-fa', '/joc/ce-se-aude', '/joc/primul-sunet']) {
      expect(musicPausedOn(p), isTrue, reason: p);
    }
    for (final p in ['/', '/arie/pot', '/joc/potriveste', '/respira']) {
      expect(musicPausedOn(p), isFalse, reason: p);
    }
    expect(musicVolume(calm: false, speaking: true), lessThan(musicVolume(calm: false, speaking: false)));
    expect(musicVolume(calm: true, speaking: false), lessThan(musicVolume(calm: false, speaking: false)));
    expect(musicVolume(calm: false, speaking: false), lessThanOrEqualTo(0.25));
  });

  test('setările muzicii se păstrează; implicit pornită, toate piesele pe rând', () {
    expect(const AppSettings().music, isTrue);
    expect(AppSettings.fromJson(const {}).musicTrack, MusicTrack.all);
    final s = const AppSettings().copyWith(music: false, musicTrack: MusicTrack.valuri);
    final back = AppSettings.fromJson(s.toJson());
    expect(back.music, isFalse);
    expect(back.musicTrack, MusicTrack.valuri);
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(settingsProvider.notifier).applyMusic(false, 'gradina');
    expect(c.read(settingsProvider).music, isFalse);
    expect(c.read(settingsProvider).musicTrack, MusicTrack.gradina);
    c.read(settingsProvider.notifier).applyMusic(true, 'necunoscuta');
    expect(c.read(settingsProvider).musicTrack, MusicTrack.gradina);
  });

  testWidgets('vocea tace imediat ce copilul iese dintr-un ecran', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final ears = _Ears();
    final c = ProviderContainer(
      overrides: [
        voiceProvider.overrideWithValue(ears),
        voiceManifestProvider.overrideWith((ref) => VoiceManifest(const {})),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MediaQuery(
          data: MediaQueryData(disableAnimations: true, size: Size(1280, 900)),
          child: LicuriciApp(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    final router = c.read(routerProvider);
    router.go('/arie/pot');
    await tester.pump(const Duration(milliseconds: 100));
    final before = ears.stops;
    router.go('/');
    await tester.pump(const Duration(milliseconds: 100));
    expect(ears.stops, before + 1);
    // Aceeași rută din nou (ex. reconstruire): nu se mai oprește nimic.
    router.go('/');
    await tester.pump(const Duration(milliseconds: 100));
    expect(ears.stops, before + 1);
    await tester.pumpWidget(const SizedBox());
  });
}
