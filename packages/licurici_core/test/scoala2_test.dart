import 'dart:math';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

Lesson _build(GameSpec g, int tier, int seed) =>
    g.build(GameContext(difficulty: Difficulty(tier), grade: Grade.clasa3, random: Random(seed)));

String _correct(ChoiceRound r) => r.choices.singleWhere((c) => c.correct).label!;

void main() {
  test('banii: răspunsul = suma bancnotelor; bancnotele mari apar abia la niveluri mai sus', () {
    for (var seed = 0; seed < 30; seed++) {
      for (final tier in [1, 4, 8]) {
        for (final r in _build(const BaniGame(), tier, seed).rounds) {
          final notes = (r.visuals.single as MoneyVisual).notes;
          expect(_correct(r), '${notes.reduce((a, b) => a + b)} lei');
          expect(notes.every(BaniGame.notesFor(tier).contains), isTrue);
          // De la mare la mic, cum le numără un adult.
          expect(notes, orderedEquals([...notes]..sort((a, b) => b - a)));
        }
      }
    }
    expect(BaniGame.notesFor(1).contains(50), isFalse);
    expect(BaniGame.notesFor(8).contains(50), isTrue);
  });

  test('tabla: produsul corect; distractorii sunt din „tabla vecină”', () {
    var neighbour = 0;
    for (var seed = 0; seed < 30; seed++) {
      for (final r in _build(const TablaGame(), 8, seed).rounds) {
        final eq = (r.visuals.single as TextVisual).text.split(' ');
        final a = int.parse(eq[0]), b = int.parse(eq[2]);
        expect(a, inInclusiveRange(2, 10));
        expect(b, inInclusiveRange(2, 10));
        expect(_correct(r), '${a * b}');
        if (r.choices.any((c) => c.label == '${a * (b + 1)}' && !c.correct)) neighbour++;
      }
    }
    expect(neighbour, greaterThan(0));
  });

  test('probleme: răspunsul se potrivește cu numerele din text; fără rezultate negative', () {
    final kinds = <String>{};
    for (var seed = 0; seed < 30; seed++) {
      for (final r in _build(const ProblemeGame(), 5, seed).rounds) {
        final text = (r.visuals.last as SceneVisual).text;
        final n = RegExp(r'\d+').allMatches(text).map((m) => int.parse(m[0]!)).toList();
        final want = switch (r.stimulusId) {
          'plus' => n[0] + n[1],
          'minus' => n[0] - n[1],
          _ => n[0] * n[1],
        };
        kinds.add(r.stimulusId!);
        expect(want, greaterThanOrEqualTo(0));
        expect(_correct(r), '$want');
      }
    }
    expect(kinds, {'plus', 'minus', 'ori'});
  });

  test('ce fel de cuvânt: cele trei feluri, mereu în aceeași ordine', () {
    for (var seed = 0; seed < 20; seed++) {
      for (final r in _build(const GramaticaGame(), 3, seed).rounds) {
        expect(r.choices.map((c) => c.id), ['substantiv', 'verb', 'adjectiv']);
        expect(r.speak.last, (r.visuals.last as TextVisual).text);
      }
    }
  });

  test('trecut: mereu un lucru vechi și unul nou', () {
    for (var seed = 0; seed < 20; seed++) {
      for (final r in _build(const TrecutGame(), 3, seed).rounds) {
        expect(r.choices, hasLength(2));
        expect(r.choices.where((c) => c.correct), hasLength(1));
      }
    }
  });

  test('engleză: cuvântul se rostește cu voce englezească (prefixul en:), variantele sunt cuvinte englezești', () {
    final en = {for (final w in englishWords) w.$2};
    for (var seed = 0; seed < 20; seed++) {
      for (final r in _build(const EnglezaGame(), 6, seed).rounds) {
        expect(r.speak.last, 'en:${_correct(r)}');
        expect(r.choices.every((c) => en.contains(c.label)), isTrue);
      }
    }
  });
}
