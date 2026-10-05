import 'dart:math';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

Lesson _build(GameSpec g, int tier, int seed) =>
    g.build(GameContext(difficulty: Difficulty(tier), grade: Grade.clasa1, random: Random(seed)));

void main() {
  test('semne: semnul corect; o treime egale', () {
    for (var seed = 0; seed < 40; seed++) {
      for (final tier in [1, 4, 9]) {
        final rounds = _build(const SemneGame(), tier, seed).rounds;
        for (final r in rounds) {
          final eq = (r.visuals.last as TextVisual).text.split('?').map((x) => int.parse(x.trim())).toList();
          final want = eq[0] < eq[1] ? '<' : (eq[0] > eq[1] ? '>' : '=');
          expect(r.choices.singleWhere((c) => c.correct).label, want);
        }
        expect(rounds.where((r) => r.stimulusId == 'egal').length, rounds.length ~/ 3);
      }
    }
  });

  test('numărul lipsă: completează egalitatea', () {
    for (var seed = 0; seed < 40; seed++) {
      for (final r in _build(const LipsaGame(), 5, seed).rounds) {
        final text = (r.visuals.single as TextVisual).text;
        final x = int.parse(r.choices.singleWhere((c) => c.correct).label!);
        final parts = text.replaceAll('?', '$x').split('=');
        final sum = parts[0].split('+').map((p) => int.parse(p.trim())).reduce((a, b) => a + b);
        expect(sum, int.parse(parts[1].trim()));
      }
    }
    expect(catalogEntry('semne')!.domain, Domain.pac);
  });
}
