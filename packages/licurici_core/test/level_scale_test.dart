import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

/// Ce face un nivel greu, pe axele reale ale fiecărui joc (citite din `axesFor` / generator).
/// Plafonul declarat în `gameScales` trebuie să fie exact nivelul de la care semnătura nu se mai
/// schimbă: altfel scara comună ar trata ca „mai greu” un nivel identic (sau invers).
final Map<String, String Function(int)> axesSignature = {
  'pescarul': (l) {
    final a = const PescarulGame().axesFor(l);
    return '${a.count} ${a.gapMs} ${a.visibleMs} ${a.noGoRatio} ${a.similarity} ${a.sizeFactor} ${a.edgeBias} ${a.moving}';
  },
  'paznicul-farului': (l) {
    final a = const PaznicFaruluiGame().axesFor(l);
    return '${a.count} ${a.gapMs} ${a.visibleMs} ${a.noGoRatio} ${a.similarity} ${a.sizeFactor} ${a.edgeBias} ${a.driftRange}';
  },
  'prinde-licuriciul': (l) {
    final a = const PrindeLicuriciulGame().axesFor(l);
    return '${a.count} ${a.gapMs} ${a.visibleMs} ${a.sizeFactor} ${a.edgeBias} ${a.driftRange}';
  },
  'simon': (l) {
    final a = const SimonGame().axesFor(l);
    return '${a.pads} ${a.length} ${a.onMs} ${a.gapMs} ${a.reverse} ${a.withSound}';
  },
  'licuricii': (l) {
    final a = const SpatialSpanGame().axesFor(l);
    return '${a.pads} ${a.length} ${a.onMs} ${a.gapMs} ${a.reverse} ${a.withSound}';
  },
  'perechi': (l) {
    final a = const MemoryGame().axesFor(l);
    return '${a.pairs} ${a.similar}';
  },
  for (final g in sortGames)
    g.id: (l) {
      final a = g.axesFor(l);
      return '${a.bins} ${a.perBin}';
    },
  'cauta': (l) {
    final a = const SearchGame().axesFor(l);
    return '${a.items} ${a.similar}';
  },
  'cucu-bau': (l) {
    final a = const ShellGame().axesFor(l);
    return '${a.cups} ${a.swaps} ${a.swapMs}';
  },
  'ce-s-a-schimbat': (l) {
    final a = const ChangeGame().axesFor(l);
    return '${a.items} ${a.lookMs} ${a.kinds.length}';
  },
  'diferente': (l) => '${const SpotDiffGame().differencesFor(l)} ${const SpotDiffGame().itemsFor(l)} ${l >= 6}',
  'la-magazin': (l) => '${const ShopGame().listFor(l)} ${const ShopGame().shelfFor(l)} ${l >= 6}',
  'construieste': (l) {
    final a = const BuildGame().axesFor(l);
    return '${a.cols} ${a.rows} ${a.distractors} ${a.hideModelMs}';
  },
  'puzzle': (l) {
    final a = const PuzzleGame().axesFor(l);
    return '${a.cols} ${a.rows} ${a.model}';
  },
  'labirint': (l) => '${const MazeGame().sizeFor(l)}',
  'linia-numerelor': (l) => '${const NumberLineGame().axesFor(l).toJson()}',
  'atinge-rapid': (l) => '${const FittsGame().sizeFor(l).toStringAsFixed(3)} ${const FittsGame().reachFor(l).toStringAsFixed(3)}',
  'unde-se-uita': (l) {
    final a = const GazeGame().axesFor(l);
    return '${a.cue} ${a.similar}';
  },
  'fa-ca-licuriciul': (l) {
    final a = const ImitationGame().axesFor(l);
    return '${a.objects} ${a.actions} ${a.drag}';
  },
  'toba-magica': (l) {
    final a = const RhythmGame().axesFor(l);
    return '${a.beats} ${a.uneven} ${a.drums}';
  },
  'urmareste-pestele': (l) {
    final a = const TrackGame().axesFor(l);
    return '${a.fish} ${a.similarity} ${a.speed} ${a.swimMs} ${a.waypoints} ${a.depth}';
  },
  'regula-se-schimba': (l) {
    final a = const SwitchGame().axesFor(l);
    return '${a.blocks} ${a.perBlock} ${a.mixed}';
  },
  for (final g in waitGames)
    g.id: (l) {
      final a = g.axesFor(l);
      return '${a.trials} ${a.minWaitMs} ${a.maxWaitMs} ${a.flickers}';
    },
  'pe-rand': (l) {
    final a = const TurnGame().axesFor(l);
    return '${a.towers} ${a.blocks} ${a.waitMs} ${a.childFirst} ${a.passTurn} ${a.hesitate}';
  },
  'asculta-si-fa': (l) {
    final a = const InstructionGame().axesFor(l);
    return '${a.steps} ${a.objects} ${a.familiarOnly} ${a.reversed} ${a.hidden}';
  },
  'uneste-punctele': (l) {
    final a = const DotsGame().axesFor(l);
    return '${a.width} ${a.guide} ${a.paths}';
  },
  'traseaza': (l) {
    final a = const TraceGame().axesFor(l);
    return '${a.shapes} ${a.width} ${a.guide} ${a.paths}';
  },
  'hraneste-pestii': (l) {
    final a = const FeedGame().axesFor(l);
    return '${a.size} ${a.speed} ${a.fish}';
  },
  'atinge-si-vezi': (l) => '${const CauseGame().countFor(l)}',
  for (final g in writingGames)
    g.id: (l) {
      final a = g.axesFor(l);
      return '${a.pool.length} ${a.width} ${a.guide} ${a.glyphs}';
    },
  for (final g in orderGames)
    g.id: (l) => '${g.stepsFor(l)} ${g.distractorsFor(l)} ${g.roundsFor(l)}',
};

void main() {
  group('LevelScale', () {
    test('nivelul 1 = 1000, plafonul = 1400, peste plafon nu mai crește', () {
      const s = LevelScale(10);
      expect(s.difficultyOf(1), LevelScale.base);
      expect(s.difficultyOf(10), LevelScale.top);
      expect(s.difficultyOf(30), LevelScale.top);
      for (var l = 1; l < 10; l++) {
        expect(s.difficultyOf(l + 1), greaterThan(s.difficultyOf(l)));
      }
    });

    test('levelAt e inversul lui difficultyOf', () {
      for (final p in [2, 6, 7, 10, 16, 25]) {
        final s = LevelScale(p);
        for (var l = 1; l <= p; l++) {
          expect(s.levelAt(s.difficultyOf(l)), l, reason: 'plafon $p, nivelul $l');
        }
      }
    });

    test('același punct relativ pe scară = aceeași dificultate, indiferent de joc', () {
      // Jumătatea drumului spre plafon la „Construiește” (7) și la „Felinarele” (25).
      expect(scaleFor('construieste').difficultyOf(4), scaleFor('simon').difficultyOf(13));
      expect(scaleFor('construieste').difficultyOf(7), scaleFor('simon').difficultyOf(25));
    });
  });

  test('fiecare joc din catalog are scara declarată (sau e cu alegere, sau fără niveluri)', () {
    for (final e in catalog) {
      final ok = gameScales.containsKey(e.id) || e.kind == GameKind.choice || unleveledGames.contains(e.id);
      expect(ok, isTrue, reason: '${e.id}: declară plafonul în gameScales (level_scale.dart)');
    }
  });

  test('jocurile cu alegere: treapta atinge maximul la plafonul declarat', () {
    String sig(int tier) => '${Difficulty(tier).optionCount} ${Difficulty(tier).roundCount}';
    expect(sig(choiceScale.plateau), sig(choiceScale.plateau + 10));
    expect(sig(choiceScale.plateau - 1), isNot(sig(choiceScale.plateau)));
  });

  group('plafonul declarat = nivelul de la care axele nu mai cresc', () {
    test('fiecare joc cu niveluri are o semnătură a axelor în test', () {
      final missing = gameScales.keys.where((id) => !axesSignature.containsKey(id) && !id.startsWith('explorare-'));
      expect(missing, isEmpty);
    });
    for (final MapEntry(key: id, value: sig) in axesSignature.entries) {
      test(id, () {
        final p = gameScales[id]!.plateau;
        for (var extra = 1; extra <= 15; extra++) {
          expect(sig(p + extra), sig(p), reason: '$id: nivelul ${p + extra} e mai greu decât plafonul $p');
        }
        expect(sig(p - 1), isNot(sig(p)), reason: '$id: plafonul real e sub $p');
      });
    }
  });

  test('rating-ul: nivelul de plafon valorează la fel în orice joc', () {
    Trial t(String game, int level) => Trial(
          stepId: 'X',
          gameId: game,
          correct: true,
          promptLevel: PromptLevel.p0,
          level: level,
          at: DateTime.utc(2026),
        );
    expect(t('construieste', 7).ratingDifficulty, t('simon', 25).ratingDifficulty);
    expect(t('simon', 7).ratingDifficulty, lessThan(t('construieste', 7).ratingDifficulty));
  });
}
