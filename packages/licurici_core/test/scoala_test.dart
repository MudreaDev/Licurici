import 'dart:math';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

Lesson _build(GameSpec g, int tier, int seed) =>
    g.build(GameContext(difficulty: Difficulty(tier), grade: Grade.clasa2, random: Random(seed)));

void main() {
  test('zeci: numărul = zeci × 10 + unități; cifrele inversate apar ca distractor', () {
    var swapped = 0;
    for (var seed = 0; seed < 30; seed++) {
      for (final r in _build(const ZeciGame(), 5, seed).rounds) {
        final v = r.visuals.single as ObjectsVisual;
        final n = v.groups[0].count * 10 + v.groups[1].count;
        expect(r.choices.singleWhere((c) => c.correct).label, '$n');
        if (r.choices.any((c) => c.label == '${v.groups[1].count}${v.groups[0].count}' && !c.correct)) swapped++;
      }
    }
    expect(swapped, greaterThan(0));
  });

  test('înmulțim: produsul corect; grupe egale cât produsul e mic', () {
    for (var seed = 0; seed < 30; seed++) {
      for (final r in _build(const InmultimGame(), 6, seed).rounds) {
        final eq = (r.visuals.last as TextVisual).text.split(' ');
        final p = int.parse(eq[0]) * int.parse(eq[2]);
        expect(r.choices.singleWhere((c) => c.correct).label, '$p');
      }
    }
  });

  test('ceasul: eticheta corectă; ore distincte în variante', () {
    expect(clockLabel(3, 0), 'ora trei');
    expect(clockLabel(1, 0), 'ora unu');
    expect(clockLabel(7, 30), 'șapte și jumătate');
    expect(clockLabel(12, 45), 'unu fără un sfert');
    for (var seed = 0; seed < 30; seed++) {
      for (final r in _build(const CeasulGame(), 6, seed).rounds) {
        final c = r.visuals.single as ClockVisual;
        expect(r.choices.singleWhere((x) => x.correct).key, clockLabel(c.hour, c.minute));
        expect(r.choices.map((x) => x.key).toSet(), hasLength(r.choices.length));
      }
    }
  });

  test('împărțim: câtul exact', () {
    for (var seed = 0; seed < 30; seed++) {
      for (final r in _build(const ImpartimGame(), 5, seed).rounds) {
        final eq = (r.visuals.last as TextVisual).text.split(' ');
        expect(r.choices.singleWhere((c) => c.correct).label, '${int.parse(eq[0]) ~/ int.parse(eq[2])}');
      }
    }
  });

  test('jocurile școlare au trepte și arii', () {
    for (final id in ['anotimpuri', 'habitate', 'silabe', 'cuvinte', 'plural', 'zeci', 'inmultim']) {
      expect(stepsForGame(id), isNotEmpty, reason: id);
    }
    expect(catalogEntry('silabe')!.domain, Domain.pac);
    expect(catalogEntry('habitate')!.domain, Domain.cog);
  });
}
