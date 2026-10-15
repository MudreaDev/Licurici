import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Toate sunetele aplicației (vocea, muzica, apa din acvariu, sunetele scurte) se aud
/// **împreună**. Implicit, pe Android fiecare player cere „audio focus” exclusiv când pornește,
/// iar cel care îl pierde se oprește: un „pop” la atingere sau muzica tăiau vocea la jumătatea
/// propoziției (se auzea doar cuvântul de după, de ex. „apple” la „Engleză”). Cu
/// `mixWithOthers` niciun player nu mai cere focusul.
final AudioContext appAudioContext = AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build();

/// La pornire: contextul comun pentru playerele create de acum încolo.
Future<void> configureAppAudio() async {
  try {
    await AudioPlayer.global.setAudioContext(appAudioContext);
  } on Object catch (e) {
    debugPrint('context audio: $e'); // ex. web — acolo nu există focus
  }
}

/// Un player nou, cu contextul comun (pentru siguranță și per player).
AudioPlayer newAppPlayer() {
  final p = AudioPlayer()..audioCache = AudioCache(prefix: '');
  p.setAudioContext(appAudioContext).catchError((Object e) => debugPrint('context audio: $e'));
  return p;
}
