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

  test('atribute: corectul are ambele atribute; distractorii doar unul', () {
    for (var seed = 0; seed < 40; seed++) {
      for (final tier in [1, 3, 6]) {
        for (final r in _build(const AtributeGame(), tier, seed).rounds) {
          final correct = r.choices.singleWhere((c) => c.correct);
          expect(r.speak.single, 'Arată ${correct.spoken}');
          expect(r.choices.map((c) => c.key).toSet(), hasLength(r.choices.length));
          if (tier == 1) expect(r.choices, hasLength(2));
          final sizeRound = r.choices.any((c) => c.scale != 1);
          for (final c in r.choices.where((c) => !c.correct)) {
            if (sizeRound) {
              // Același obiect cu altă mărime, sau alt obiect cu aceeași mărime (ori ambele diferite).
              expect(c.art != correct.art || c.scale != correct.scale, isTrue);
            } else {
              expect(c.art, isNot(correct.art));
            }
          }
        }
      }
    }
  });

  test('ce se aude: corectul face sunetul rostit; la tier mare, distractori de la fermă', () {
    for (var seed = 0; seed < 40; seed++) {
      for (final r in _build(const CeSeAudeGame(), 6, seed).rounds) {
        final correct = r.choices.singleWhere((c) => c.correct);
        expect(r.speak.single, 'Cine face ${correct.spoken}?');
      }
    }
    expect(catalogEntry('ce-se-aude')!.domain, Domain.com);
  });

  test('ce îmbrac: distractorii nu se potrivesc niciodată vremii', () {
    for (var seed = 0; seed < 40; seed++) {
      for (final r in _build(const CeImbracGame(), 6, seed).rounds) {
        expect(r.choices.where((c) => c.correct), hasLength(1));
        expect(r.choices.map((c) => c.art).toSet(), hasLength(r.choices.length));
      }
    }
    expect(catalogEntry('ce-imbrac')!.domain, Domain.aut);
  });

  test('peștele din mijloc: răspunsul = direcția peștelui din mijloc; congruent/incongruent', () {
    for (var seed = 0; seed < 40; seed++) {
      for (final tier in [1, 3, 6]) {
        final rounds = _build(const PesteInMijlocGame(), tier, seed).rounds;
        for (final r in rounds) {
          final v = r.visuals.single as FlankerVisual;
          final dir = v.directions[v.center];
          expect(r.choices.singleWhere((c) => c.correct).key, dir < 0 ? 'stanga' : 'dreapta');
          final others = [for (final (i, d) in v.directions.indexed) if (i != v.center) d];
          if (r.stimulusId == 'incongruent') expect(others.every((d) => d == -dir), isTrue);
          if (r.stimulusId == 'congruent') expect(others.every((d) => d == dir), isTrue);
          if (tier == 1) expect(r.stimulusId, 'singur');
        }
        if (tier == 6) {
          expect(rounds.where((r) => r.stimulusId == 'incongruent').length, (rounds.length * 0.5).round());
        }
      }
    }
    expect(catalogEntry('peste-in-mijloc')!.domain, Domain.fex);
  });

  test('jocurile noi au trepte în trasee', () {
    for (final id in ['potriveste', 'arata-mi', 'corpul', 'intrusul']) {
      expect(stepsForGame(id), isNotEmpty, reason: id);
    }
    expect(catalogEntry('arata-mi')!.domain, Domain.lrc);
    expect(catalogEntry('potriveste')!.domain, Domain.pot);
  });
}
