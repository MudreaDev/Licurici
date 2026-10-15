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
  // Acvariul
  'Ți-am adus un pește!',
  'Colorează și tu unul.',
  'Uite! Peștele tău înoată în acvariu!',
  'Alege un pește.',
  'Colorează peștele cum vrei tu.',
  // Harta cu felinare
  'Ai aprins un felinar nou!',
  'Joacă-te și aprinzi felinarele.',
  'Uite câte felinare ai aprins!',
  // Ascultă și fă
  'Ascultă bine și atinge în aceeași ordine.',
  'Mai ascultă o dată.',
  'Uite, în ordinea asta.',
  // Scriem cifrele / literele (modelul)
  'Uite așa.',
  // Rândul meu, rândul tău
  'Construim un turn. Pe rând: o dată tu, o dată eu.',
  'Rândul tău.',
  'Acum e rândul meu.',
  'Așteaptă rândul tău.',
  'Spune-mi când e rândul meu.',
  'E rândul meu?',
  'Am construit împreună!',
  'Atinge cubul tău.',
  // Colorăm
  'Alege un desen.',
  'Colorează cum vrei tu.',
  'Ce desen frumos!',
  'Joacă un joc și câștigi stele pentru mâncare.',
  'Ține degetul pe apă: peștii vin la tine.',
  'Atinge cufărul cu comori!',
  'Noapte bună, peștișori!',
  'Bună dimineața, peștișori!',
  'Îl caut pe peștele tău.',
  'Nu văd fișa. Fă poza de sus, cu toată foaia.',
  'Încearcă o poză mai clară.',
  'Bravo',
  'Bravo!',
  'Mai încearcă',
  'Ai terminat! Bravo!',
  // Linia numerelor, Atinge rapid
  'Atinge locul numărului pe linie.',
  'Unde stă numărul',
  'Uite unde stă.',
  'Sparge bulele cât de repede poți.',
  // Stop!
  'Atinge felinarul când e verde. Când se face roșu, oprește-te!',
  'Data viitoare te oprești.',
  // Turnul
  'Pune inelele pe rând: întâi cel mai mare.',
  'Caută cel mai mare inel.',
  // Adu-mi
  'Adu-mi',
  'și',
  'Mulțumesc',
  // Acum sau mai mult?
  'O stea acum sau trei stele dacă aștepți?',
  'O stea acum sau două stele dacă aștepți?',
  'Bine. Așteptăm împreună.',
  'Poftim steaua ta!',
  // Urmărește peștele
  'Urmărește peștele!',
  'Acesta e peștele tău. Urmărește-l!',
  'Urmărește-l!',
  'Atinge peștele!',
  'Unde e peștele tău?',
  'Așteaptă să se oprească.',
  'Uite-l pe al tău!',
  // Felinarele (simon)
  'Rândul tău',
  'Atinge-le invers, de la ultimul.',
  'Mai privim o dată',
  'Continuăm',
  'Privește',
  // Fă ca Licurici
  'Privește ce face Licurici.',
  'Acum tu!',
  // Semaforul, Floarea crește
  'Atinge felinarul doar când se face verde.',
  'Așteaptă verde.',
  'Atinge floarea doar când s-a deschis de tot.',
  'Așteaptă să se deschidă.',
  'Acum!',
  // Unde se uită?
  'Ce arată Licurici?',
  // La magazin
  'Cumpără ce e pe listă.',
  'Asta nu e pe listă.',
  'Ai cumpărat tot!',
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

  for (final p in [...uiPhrases, ...Praise.all]) {
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
    add(const SpatialSpanGame().generate(level, seed: level).instruction, 'licuricii');
  }

  // Jocurile cu ecran propriu (fără runde `choice`).
  for (final t in traceTrips) {
    add(t.says, 'traseaza');
  }
  // Ascultă și fă: rostit pe bucăți, deci câte un clip pe obiect și formă.
  for (final o in objectWords) {
    for (final other in [objectWords.first, objectWords.last]) {
      for (final rev in [false, true]) {
        for (final piece in InstructionGame.pieces([o, other], reversed: rev)) {
          add(piece, 'asculta-si-fa');
        }
        for (final piece in InstructionGame.pieces([other, o], reversed: rev)) {
          add(piece, 'asculta-si-fa');
        }
      }
    }
  }
  for (final g in writingGames) {
    for (final glyph in g.allGlyphs) {
      add(g.instructionFor(glyph), g.id);
      add(g.praiseFor(glyph), g.id);
    }
  }
  for (final g in orderGames) {
    add(g.instruction, g.id);
    for (final story in g.stories) {
      add(story.title, g.id);
      for (final step in story.steps) {
        add(step.caption, g.id);
      }
      if (g.sentence) {
        for (var k = 2; k <= story.steps.length; k++) {
          add(orderSentence(story.steps.take(k).toList()), g.id);
        }
      }
    }
  }
  for (final r in SortRule.values) {
    add(SwitchGame.announce(r), 'regula-se-schimba');
  }
  add('Uită-te la semn: culoare sau formă.', 'regula-se-schimba');
  // Explorările: povestea fiecărei opriri, instrucțiunea sortării, finalul.
  for (final e in exploreEpisodes) {
    add(e.outro, e.id);
    for (final st in e.stops) {
      add(st.intro, e.id);
      add(st.instruction, e.id);
    }
  }
  add('Alege o oprire pe hartă.', 'explorare');
  add('Bravo! Alege altă oprire.', 'explorare');
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
  // Pune ursulețul: fiecare obiect, la fiecare loc al fiecărui reper (și ca a doua jumătate).
  for (final (_, w) in PlaceGame.things) {
    for (final l in Landmark.values) {
      for (final r in Relation.values) {
        if (!PlaceGame.fits(r, l)) continue;
        add('Pune $w ${r.at(l)}', 'pune-ursul');
        add('$w ${r.at(l)}', 'pune-ursul');
      }
    }
  }
  add(DotsGame.says, 'uneste-punctele');
  for (final f in dotFigures) {
    add(f.name, 'uneste-punctele');
  }
  for (final g in sortGames) {
    add(g.instruction, g.id);
  }
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
