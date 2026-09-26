import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_content/game_content.dart';

import '../features/settings/settings.dart';

final voiceManifestProvider = FutureProvider<VoiceManifest>((ref) => VoiceManifest.load());

/// Ce poate rosti aplicația. Interfață separată ca testele să poată folosi o voce „mută”.
abstract interface class Speaker {
  Future<void> say(List<String> parts);
  Future<void> stop();
}

/// Tăcere — pentru teste și pentru platformele fără audio.
class SilentSpeaker implements Speaker {
  const SilentSpeaker();
  @override
  Future<void> say(List<String> parts) async {}
  @override
  Future<void> stop() async {}
}

/// Voce naturală RO din clipuri pre-generate (ADR-16). Rostește fragmente în ordine;
/// o cerere nouă o anulează pe cea în curs. Fragmentele fără clip sunt sărite.
class Voice implements Speaker {
  Voice(this._ref) {
    _player.audioCache = AudioCache(prefix: '');
  }

  final Ref _ref;
  final AudioPlayer _player = AudioPlayer();
  int _generation = 0;

  @override
  Future<void> say(List<String> parts) async {
    final generation = ++_generation;
    await _player.stop();
    if (!_ref.read(settingsProvider).voice) return;
    final manifest = _ref.read(voiceManifestProvider).value;
    if (manifest == null) return;
    for (final part in parts) {
      if (generation != _generation) return;
      final asset = manifest.assetFor(part);
      if (asset == null) continue;
      final done = _player.onPlayerComplete.first;
      try {
        await _player.play(AssetSource(asset));
        await done.timeout(const Duration(seconds: 8));
      } on Object {
        return; // audio indisponibil (ex. browser fără interacțiune) — jocul continuă fără voce
      }
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
    await _player.stop();
  }

  void dispose() => _player.dispose();
}

final voiceProvider = Provider<Speaker>((ref) {
  ref.watch(voiceManifestProvider);
  final voice = Voice(ref);
  ref.onDispose(voice.dispose);
  return voice;
});
