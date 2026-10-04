import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_content/game_content.dart';

import '../features/settings/settings.dart';

/// Sunetele interfeței (generate din cod: `tools/audio/gen_sfx.py`). Nu există sunet de
/// „greșit” (README §15.1).
enum Sfx {
  /// Atingerea unui buton sau card.
  tap,

  /// Răspuns corect.
  correct,

  /// O stea câștigată la final.
  star,

  /// Abțibildul nou.
  sticker,
}

abstract interface class SoundEffects {
  /// Sunet de interfață — tăcut în modul calm (stimulare senzorială mai mică).
  void play(Sfx sfx);

  /// Nota felinarului cu indexul dat (0..5 → do re mi sol la do', pentatonica: orice
  /// secvență sună armonios). Face parte din joc, deci se aude și în modul calm, mai încet.
  void note(int degree);

  /// Toba [which] (0 = joasă, 1 = înaltă) — sunetul jocului „Toba magică”; ca notele, se
  /// aude și în modul calm, mai încet.
  void drum(int which);
}

class SilentSfx implements SoundEffects {
  const SilentSfx();
  @override
  void play(Sfx sfx) {}
  @override
  void note(int degree) {}
  @override
  void drum(int which) {}
}

/// Câteva playere refolosite pe rând, în modul cu latență mică: sunetele scurte se pot
/// suprapune (ex. două note la rând) fără să se taie una pe alta.
class _Sfx implements SoundEffects {
  _Sfx(this._ref);

  final Ref _ref;
  final _pool = <AudioPlayer>[];
  int _next = 0;

  AudioPlayer _player() {
    if (_pool.length < 4) {
      final p = AudioPlayer()..audioCache = AudioCache(prefix: '');
      // Latența mică există doar pe Android/iOS; pe web modul implicit e deja rapid.
      if (!kIsWeb) p.setPlayerMode(PlayerMode.lowLatency).catchError((_) {});
      _pool.add(p);
      return p;
    }
    return _pool[_next++ % _pool.length];
  }

  void _play(String name, double volume) {
    try {
      final p = _player();
      p
          .play(
            AssetSource('packages/$contentPackage/audio/sfx/$name.wav'),
            volume: volume,
          )
          .catchError((Object e) => debugPrint('sunet $name: $e'));
    } on Object catch (e) {
      // fără audio (ex. browser înainte de prima atingere) — jocul continuă în liniște
      debugPrint('sunet $name: $e');
    }
  }

  @override
  void play(Sfx sfx) {
    if (_ref.read(settingsProvider).calm) return;
    _play(sfx.name, sfx == Sfx.tap ? 0.5 : 0.8);
  }

  @override
  void note(int degree) => _play(
    'note_${degree % 6}',
    _ref.read(settingsProvider).calm ? 0.45 : 0.8,
  );

  @override
  void drum(int which) => _play(
    'drum_${which % 2}',
    _ref.read(settingsProvider).calm ? 0.45 : 0.85,
  );

  void dispose() {
    for (final p in _pool) {
      p.dispose();
    }
  }
}

final sfxProvider = Provider<SoundEffects>((ref) {
  // În testele de widget nu există pluginul audio.
  if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
    return const SilentSfx();
  }
  final sfx = _Sfx(ref);
  ref.onDispose(sfx.dispose);
  return sfx;
});
