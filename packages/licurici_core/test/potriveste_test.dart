import 'dart:io';
import 'dart:math';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

final byEmoji = {for (final s in objects.items) s.emoji: s};
final gen = PotrivesteGenerator();
const axes = PotrivesteGenerator.axes;

Stimulus sampleOf(ChoiceRound r) => byEmoji[(r.visuals.single as EmojiVisual).emoji]!;
Stimulus correctOf(ChoiceRound r) => byEmoji[r.choices.singleWhere((c) => c.correct).art]!;
List<Stimulus> distractorsOf(ChoiceRound r) => [
      for (final c in r.choices)
        if (!c.correct) byEmoji[c.art]!,
    ];

/// Respectă [s] regula modului față de modelul [m]? (verificarea independentă de generator)
bool matches(MatchMode mode, Stimulus m, Stimulus s) => switch (mode) {
      MatchMode.identic => s.emoji == m.emoji,
      MatchMode.neidentic => s.concept == m.concept,
      MatchMode.culoare => s.color != null && s.color == m.color,
      MatchMode.forma => s.shape != null && s.shape == m.shape,
      MatchMode.categorie => s.category == m.category,
    };

/// Numele fișierului OpenMoji (ca în `game_content`, fără dependența de Flutter).
String openMojiName(String emoji) => emoji.runes
    .where((cp) => cp != 0xFE0F)
    .map((cp) => cp.toRadixString(16).toUpperCase().padLeft(4, '0'))
    .join('-');

void main() {
  test('banca de stimuli: ilustrațiile există, fiecare mod are modele', () {
    final files = Directory('../game_content/art/openmoji')
        .listSync()
        .map((f) => f.uri.pathSegments.last)
        .toSet();
    for (final s in objects.items) {
      expect(files, contains('${openMojiName(s.emoji)}.svg'), reason: '${s.emoji} ${s.concept}');
    }
    for (final mode in MatchMode.values) {
      expect(gen.samples(mode).length, greaterThanOrEqualTo(4), reason: '$mode');
    }
    expect(objects.multiDrawn.length, greaterThanOrEqualTo(15));
  });

  test('10 000 de seed-uri pe tot spațiul de axe: un singur răspuns corect, fără ambiguități', () {
    final points = axes.grid();
    var checked = 0;
    for (var seed = 0; seed < 10000; seed++) {
      final mode = MatchMode.values[seed % MatchMode.values.length];
      final point = {
        ...points[(seed ~/ MatchMode.values.length) % points.length],
        ...PotrivesteGenerator.fixedFor(mode),
      };
      final r = gen.round(mode, point, seed);
      final why = '$mode $point seed=$seed';
      final m = sampleOf(r);
      final c = correctOf(r);

      expect(r.choices, hasLength(point['variante']), reason: why);
      expect(r.choices.map((c) => c.art).toSet(), hasLength(r.choices.length), reason: 'duplicat: $why');
      expect(matches(mode, m, c), isTrue, reason: 'corectul nu respectă regula: $why');
      if (mode != MatchMode.identic) expect(c.emoji, isNot(m.emoji), reason: 'neidentic: $why');
      if (mode == MatchMode.forma) expect(c.color, isNot(m.color), reason: why);
      final concepts = <String>{c.concept};
      for (final d in distractorsOf(r)) {
        expect(matches(mode, m, d), isFalse, reason: 'distractor ambiguu ${d.emoji}: $why');
        expect(concepts.add(d.concept), isTrue, reason: 'concept repetat ${d.concept}: $why');
      }
      // eticheta: nivelul se poate reproduce și e legat de treaptă
      expect(r.tag!.seed, seed);
      expect(r.tag!.axes, point);
      expect(r.tag!.stepId, PotrivesteGenerator.stepFor(mode, point));
      expect(r.tag!.stimulusId, m.emoji);
      checked++;
    }
    expect(checked, 10000);
  });

  test('determinism: același (mod, axe, seed) → exact aceeași rundă', () {
    for (var seed = 0; seed < 500; seed++) {
      for (final mode in MatchMode.values) {
        final point = {'variante': 4, 'asemanare': seed % 4, ...PotrivesteGenerator.fixedFor(mode)};
        final a = gen.round(mode, point, seed);
        final b = PotrivesteGenerator().round(mode, point, seed);
        expect(PotrivesteGenerator.keyOf(a), PotrivesteGenerator.keyOf(b));
      }
    }
  });

  test('asemănarea distractorilor crește cu axa „asemanare”', () {
    for (final mode in MatchMode.values) {
      final attrs = PotrivesteGenerator.similarityAttrs(mode);
      final means = <double>[];
      for (final level in [0, 1, 2, 3]) {
        var sum = 0, n = 0;
        for (var seed = 0; seed < 400; seed++) {
          final r = gen.round(mode, {'variante': 4, 'asemanare': level, ...PotrivesteGenerator.fixedFor(mode)}, seed);
          for (final d in distractorsOf(r)) {
            sum += d.similarity(sampleOf(r), attrs);
            n++;
          }
        }
        means.add(sum / n);
      }
      for (var i = 1; i < means.length; i++) {
        expect(means[i], greaterThanOrEqualTo(means[i - 1] - 1e-9), reason: '$mode $means');
      }
      expect(means.last, greaterThan(means.first), reason: '$mode $means');
    }
  });

  test('dificultatea crește monoton pe axe; treptele urmează modul', () {
    double d(int v, int a, int n) => axes.difficultyOf({'variante': v, 'asemanare': a, 'neidentic': n});
    expect(d(3, 0, 0), greaterThan(d(2, 0, 0)));
    expect(d(2, 1, 0), greaterThan(d(2, 0, 0)));
    expect(d(2, 0, 1), greaterThan(d(2, 0, 0)));
    expect(PotrivesteGenerator.stepFor(MatchMode.identic, {'variante': 2}), 'POT1');
    expect(PotrivesteGenerator.stepFor(MatchMode.identic, {'variante': 4}), 'POT2');
    expect(PotrivesteGenerator.stepFor(MatchMode.neidentic, {'variante': 4}), 'POT4');
    expect(PotrivesteGenerator.stepFor(MatchMode.forma, {'variante': 4}), 'POT5');
    expect(PotrivesteGenerator.stepFor(MatchMode.categorie, {'variante': 4}), 'POT6');
  });

  test('sesiune lungă: fără combinații repetate, corectul nu stă de 3 ori la rând pe loc', () {
    final rnd = Random(3);
    final history = ExposureHistory();
    final positions = <int>[];
    final keys = <String>{};
    for (var i = 0; i < 300; i++) {
      final mode = MatchMode.values[i % MatchMode.values.length];
      final point = {'variante': 3, 'asemanare': 1, ...PotrivesteGenerator.fixedFor(mode)};
      final r = gen.next(mode, point, rnd, history: history, positions: positions);
      expect(keys.add(PotrivesteGenerator.keyOf(r)), isTrue, reason: 'repetat la runda $i');
      final pos = r.choices.indexWhere((c) => c.correct);
      if (positions.length >= 2) {
        expect(pos == positions[positions.length - 1] && pos == positions[positions.length - 2], isFalse);
      }
      positions.add(pos);
      // runda se reproduce din seed-ul salvat, fără istoric
      expect(PotrivesteGenerator.keyOf(gen.round(mode, point, r.tag!.seed)), PotrivesteGenerator.keyOf(r));
    }
  });

  test('jocul în registru: modurile se deblochează cu tier-ul', () {
    expect(PotrivesteGame.modesFor(1), [MatchMode.identic]);
    expect(PotrivesteGame.modesFor(5), MatchMode.values);
    final lesson = const PotrivesteGame().build(
      GameContext(difficulty: const Difficulty(6), grade: Grade.gradinita, random: Random(1)),
    );
    expect(lesson.rounds.map((r) => r.tag!.config['mod']).toSet().length, greaterThan(1));
    expect(lesson.art, isNotEmpty);
  });
}
