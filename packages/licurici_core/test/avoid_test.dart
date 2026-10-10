import 'dart:math';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  test('categoriile se traduc în imagini; necunoscutele se ignoră', () {
    expect(avoidedEmojis(['caini']), containsAll(['🐶', '🐕']));
    expect(avoidedEmojis(['nu-exista']), isEmpty);
    expect(avoidItems.map((i) => i.id).toSet(), hasLength(avoidItems.length));
  });

  test('nicio rundă rămasă nu arată ceva de evitat, în niciun joc cu alegere', () {
    final avoid = avoidedEmojis(['caini', 'pisici', 'insecte', 'fete-furioase', 'baloane']);
    var removed = 0;
    for (final g in allGames) {
      for (var tier = 1; tier <= 10; tier += 3) {
        final lesson = g.build(GameContext(difficulty: Difficulty(tier), grade: Grade.clasa1, random: Random(tier)));
        final kept = withoutAvoided(lesson, avoid);
        removed += lesson.rounds.length - kept.rounds.length;
        for (final r in kept.rounds) {
          expect(showsAvoided(r, avoid), isFalse, reason: g.id);
        }
      }
    }
    // Filtrul chiar lucrează: în conținut există rundele cu aceste imagini.
    expect(removed, greaterThan(0));
  });

  test('variantele cu selector de variantă (U+FE0F) sunt recunoscute', () {
    final r = ChoiceRound(prompt: 'Care e păianjenul?', choices: const [Choice(art: '🕷️', correct: true), Choice(art: '🍎')]);
    expect(showsAvoided(r, avoidedEmojis(['insecte'])), isTrue);
    expect(showsAvoided(r, avoidedEmojis(['caini'])), isFalse);
  });

  group('celelalte mecanici', () {
    final avoid = avoidedEmojis(['caini', 'pisici', 'insecte', 'fete-furioase', 'baloane', 'animale-mari']);
    bool clean(Iterable<String> art) => !art.any((a) => isAvoided(a, avoid));

    test('jocurile care aleg din tot vocabularul nu mai arată deloc imaginile de evitat', () {
      for (var level = 1; level <= 15; level += 2) {
        for (var seed = 0; seed < 5; seed++) {
          expect(clean(const SearchGame().generate(level, seed: seed, avoid: avoid).art), isTrue, reason: 'cauta $level');
          expect(clean(const ChangeGame().generate(level, seed: seed, avoid: avoid).art), isTrue, reason: 'schimbat $level');
          expect(clean(const GazeGame().generate(level, seed: seed, avoid: avoid).art), isTrue, reason: 'privirea $level');
          expect(clean(const InstructionGame().generate(level, seed: seed, avoid: avoid).art), isTrue, reason: 'asculta $level');
          expect(clean(const SpotDiffGame().generate(level, seed: seed, avoid: avoid).art), isTrue, reason: 'diferente $level');
          expect(clean(const ShopGame().generate(level, seed: seed, avoid: avoid).art), isTrue, reason: 'magazin $level');
        }
      }
      expect(safeWords(avoid).length, lessThan(objectWords.length));
      expect(safeWords(const {}), same(objectWords));
    });

    test('generateAvoiding: alt seed până nu mai e nimic de evitat; null dacă nu se poate', () {
      MemoryLevel memory(Set<String> avoid) =>
          generateAvoiding((s) => const MemoryGame().generate(4, seed: s), (l) => l.art, avoid, seed: 3)!;
      for (var seed = 0; seed < 10; seed++) {
        final level = generateAvoiding((s) => const MemoryGame().generate(4, seed: s), (l) => l.art, avoid, seed: seed);
        expect(level, isNotNull);
        expect(clean(level!.art), isTrue);
        final sort = generateAvoiding((s) => const SortGame().generate(3, seed: s), (l) => l.art, avoid, seed: seed);
        if (sort != null) expect(clean(sort.art), isTrue);
      }
      // Determinist cu seed: aceeași alegere de fiecare dată.
      expect(memory(avoid).cards, memory(avoid).cards);
      // Fără nimic de evitat: primul nivel, neschimbat.
      expect(memory(const {}).seed, 3);
      // Totul de evitat: niciodată „rezervă”.
      expect(generateAvoiding((s) => const MemoryGame().generate(4, seed: s), (l) => l.art, {''}, seed: 3), isNull);
    });
  });
}
