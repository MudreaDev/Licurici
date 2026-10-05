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
const uiPhrases = [
  'Bravo',
  'Bravo!',
  'Mai încearcă',
  'Ai terminat! Bravo!',
  // Felinarele (simon)
  'Rândul tău',
  'Atinge-le invers, de la ultimul.',
  'Mai privim o dată',
  'Continuăm',
  'Privește',
  // Fă ca Licurici
  'Privește ce face Licurici.',
  'Acum tu!',
  // Semaforul
  'Atinge felinarul doar când se face verde.',
  'Așteaptă verde.',
  'Acum!',
  // Unde se uită?
  'Ce arată Licurici?',
  // Construiește la fel
  'Fă la fel ca modelul.',
  'Ține minte modelul!',
  // Găsește diferențele
  'Ce e altfel în poza a doua?',
  'Ai găsit toate diferențele!',
  // Labirint
  'Du peștișorul acasă.',
  // Puzzle
  'Pune piesele la locul lor.',
  // Ce s-a schimbat?
  'Privește bine!',
  'Ce s-a schimbat?',
  'Ce a dispărut?',
  // Atinge și vezi
  'Atinge și vezi ce se întâmplă!',
  // Hrănește peștii
  'Du mâncarea la peștele flămând.',
  'Mmm, mulțumesc!',
  // Toba magică
  'Ascultă ritmul lui Licurici.',
  'Bate și tu la fel.',
  'Mai ascultăm o dată.',
  'Unde se uită Licurici?',
  // Check-in-ul de dispoziție și finalul sesiunii
  'Cum te simți?',
  'Ne vedem data viitoare!',
];

void main(List<String> args) {
  final manifestFile = File('../game_content/audio/ro/voice.json');
  final clips = (jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>).keys.toSet();

  final phrases = <String, Set<String>>{}; // frază → jocurile care o folosesc
  void add(String phrase, String gameId) =>
      phrases.putIfAbsent(phrase.trim(), () => {}).add(gameId);

  for (final p in uiPhrases) {
    add(p, 'interfață');
  }
  for (final m in Mood.values) {
    add(m.label, 'dispoziție');
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

  for (final game in reactionGames) {
    for (var level = 1; level <= 30; level++) {
      add(game.generate(level, seed: level).instruction, game.id);
    }
  }

  for (var level = 1; level <= 30; level++) {
    add(const SimonGame().generate(level, seed: level).instruction, 'simon');
  }

  // Jocurile cu ecran propriu (fără runde `choice`).
  for (final t in traceTrips) {
    add(t.says, 'traseaza');
  }
  for (final g in orderGames) {
    add(g.instruction, g.id);
    for (final story in g.stories) {
      add(story.title, g.id);
      for (final step in story.steps) {
        add(step.caption, g.id);
      }
    }
  }
  for (final r in SortRule.values) {
    add(SwitchGame.announce(r), 'regula-se-schimba');
  }
  add('Uită-te la semn: culoare sau formă.', 'regula-se-schimba');
  for (final o in objectWords) {
    add('Găsește ${o.word}.', 'cauta');
    add(o.word, 'cauta');
  }
  for (final c in aacBoard) {
    add(c.starter, 'vorbeste');
    for (final w in c.words) {
      add(aacSentence(c, w), 'vorbeste');
    }
  }
  add(const SortGame().generate(1, seed: 1).instruction, 'sortam');
  add(const MemoryGame().generate(1, seed: 1).instruction, 'perechi');

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
