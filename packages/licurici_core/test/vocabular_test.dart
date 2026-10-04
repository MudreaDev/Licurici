import 'dart:math';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

Lesson _build(GameSpec g, int tier, int seed) =>
    g.build(GameContext(difficulty: Difficulty(tier), grade: Grade.gradinita, random: Random(seed)));

ObjectWord _word(String emoji) => objectWords.firstWhere((o) => o.emoji == emoji);

void main() {
  test('potrivește: corectul e chiar obiectul arătat; tier 1 = două variante (POT1)', () {
    for (var seed = 0; seed < 40; seed++) {
      for (final tier in [1, 3, 6]) {
        for (final r in _build(const PotrivesteGame(), tier, seed).rounds) {
          final shown = (r.visuals.single as EmojiVisual).emoji;
          expect(r.choices.singleWhere((c) => c.correct).art, shown);
          if (tier == 1) expect(r.choices, hasLength(2));
        }
      }
    }
  });

  test('potrivește: de la tier 4 distractorii vin din aceeași grupă', () {
    var same = 0, total = 0;
    for (var seed = 0; seed < 40; seed++) {
      for (final r in _build(const PotrivesteGame(), 6, seed).rounds) {
        final target = _word(r.choices.singleWhere((c) => c.correct).art!);
        for (final c in r.choices.where((c) => !c.correct)) {
          total++;
          if (_word(c.art!).group == target.group) same++;
        }
      }
    }
    expect(same / total, greaterThan(0.6));
  });

  test('arată-mi: la început doar cuvinte foarte cunoscute; numele rostit = corectul', () {
    for (var seed = 0; seed < 40; seed++) {
      for (final r in _build(const ArataMiGame(), 1, seed).rounds) {
        expect(r.choices.every((c) => _word(c.art!).familiar), isTrue);
        final correct = r.choices.singleWhere((c) => c.correct);
        expect(r.speak.single, 'Arată ${correct.spoken}');
      }
      final rounds = _build(const ArataMiGame(), 1, seed).rounds;
      for (var i = 1; i < rounds.length; i++) {
        expect(rounds[i].prompt, isNot(rounds[i - 1].prompt), reason: 'aceeași țintă de două ori la rând');
      }
    }
  });

  test('intrusul: exact un obiect din altă grupă, restul din aceeași', () {
    for (var seed = 0; seed < 40; seed++) {
      for (final tier in [1, 4, 8]) {
        for (final r in _build(const IntrusulGame(), tier, seed).rounds) {
          final intruder = _word(r.choices.singleWhere((c) => c.correct).art!);
          final rest = r.choices.where((c) => !c.correct).map((c) => _word(c.art!)).toList();
          expect(rest.map((o) => o.group).toSet(), hasLength(1));
          expect(intruder.group, isNot(rest.first.group));
          expect(rest.length, (1 + tier).clamp(2, 4));
        }
      }
    }
  });

  test('umbre: alternează „găsește umbra” (variante siluete) cu „al cui e umbra?”', () {
    for (var seed = 0; seed < 30; seed++) {
      final rounds = _build(const UmbreGame(), 5, seed).rounds;
      for (final (i, r) in rounds.indexed) {
        final correct = r.choices.singleWhere((c) => c.correct);
        if (i.isEven) {
          expect(r.choices.every((c) => c.silhouette), isTrue);
          expect((r.visuals.single as EmojiVisual).emoji, correct.art);
        } else {
          expect(r.choices.any((c) => c.silhouette), isFalse);
          expect((r.visuals.single as SilhouetteVisual).emoji, correct.art);
        }
      }
    }
    expect(stepsForGame('umbre').single.id, 'POT3');
  });

  test('jocurile noi au trepte în trasee', () {
    for (final id in ['potriveste', 'arata-mi', 'corpul', 'intrusul']) {
      expect(stepsForGame(id), isNotEmpty, reason: id);
    }
    expect(catalogEntry('arata-mi')!.domain, Domain.lrc);
    expect(catalogEntry('potriveste')!.domain, Domain.pot);
  });
}
