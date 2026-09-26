// Acoperirea vocii: ce fraze rostesc jocurile și care nu au încă un clip audio.
//
//   dart run tool/voice_coverage.dart            # raport
//   dart run tool/voice_coverage.dart --write    # scrie lista în game_content/audio/ro/lipsa.txt
//
// Lista „lipsă” e intrarea pentru generatorul de voce (README §16, ADR-016).
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:licurici_core/licurici_core.dart';

/// Fraze rostite de interfață (în afara jocurilor).
const uiPhrases = ['Bravo', 'Mai încearcă', 'Ai terminat! Bravo!'];

void main(List<String> args) {
  final manifestFile = File('../game_content/audio/ro/voice.json');
  final clips = (jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>).keys.toSet();

  final phrases = <String, Set<String>>{}; // frază → jocurile care o folosesc
  void add(String phrase, String gameId) =>
      phrases.putIfAbsent(phrase.trim(), () => {}).add(gameId);

  for (final p in uiPhrases) {
    add(p, 'interfață');
  }
  for (final game in allGames) {
    for (final tier in [1, 2, 3, 4, 5, 6, 8, 12]) {
      for (var seed = 0; seed < 60; seed++) {
        final ctx = GameContext(difficulty: Difficulty(tier), grade: game.grades.first, random: Random(seed));
        for (final r in game.generate(ctx).rounds) {
          for (final s in r.speak) {
            add(s, game.id);
          }
          for (final c in r.choices) {
            if (c.spoken case final s?) add(s, game.id);
          }
        }
      }
    }
  }

  final missing = phrases.keys.where((p) => !clips.contains(p)).toList()..sort();
  final covered = phrases.length - missing.length;
  stdout.writeln('Fraze rostite: ${phrases.length} · cu voce: $covered · lipsă: ${missing.length}');
  for (final p in missing) {
    stdout.writeln('  ✗ $p   (${phrases[p]!.join(', ')})');
  }
  if (args.contains('--write')) {
    File('../game_content/audio/ro/lipsa.txt').writeAsStringSync('${missing.join('\n')}\n');
    stdout.writeln('Scris: game_content/audio/ro/lipsa.txt');
  }
}
