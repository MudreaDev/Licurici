import 'dart:io';
import 'dart:math';

import 'package:licurici_core/licurici_core.dart';
import 'package:licurici_core/src/games/social_content.dart';
import 'package:test/test.dart';

Lesson _build(GameSpec g, int tier, int seed) =>
    g.build(GameContext(difficulty: Difficulty(tier), grade: Grade.gradinita, random: Random(seed)));

String _openMoji(String emoji) => emoji.runes
    .where((cp) => cp != 0xFE0F)
    .map((cp) => cp.toRadixString(16).toUpperCase().padLeft(4, '0'))
    .join('-');

void main() {
  test('toate ilustrațiile jocurilor (inclusiv reaction) au SVG OpenMoji', () {
    final missing = <String>{};
    // Fețele desenate din cod (`face:…`) nu au fișier.
    bool has(String e) => FaceSpec.isFace(e) || File('../game_content/art/openmoji/${_openMoji(e)}.svg').existsSync();
    for (final g in allGames) {
      if (!has(g.emoji)) missing.add('${g.id}: ${g.emoji}');
      for (final tier in [1, 3, 5, 8]) {
        for (var seed = 0; seed < 25; seed++) {
          for (final a in _build(g, tier, seed).art) {
            if (!has(a)) missing.add('${g.id}: $a');
          }
        }
      }
    }
    for (final g in reactionGames) {
      for (final a in {g.emoji, ...g.generate(20, seed: 1).art, ...g.generate(1, seed: 1).art}) {
        if (!has(a)) missing.add('${g.id}: $a');
      }
      for (var lvl = 1; lvl <= 20; lvl++) {
        for (final a in g.generate(lvl, seed: lvl).art) {
          if (!has(a)) missing.add('${g.id}: $a');
        }
      }
    }
    // Cardul fiecărui joc din catalog (orice mecanică) are rezervă OpenMoji.
    for (final e in catalog) {
      if (!has(e.emoji)) missing.add('${e.id}: ${e.emoji}');
    }
    expect(missing, isEmpty);
  });

  group('ce-simte', () {
    test('la tier mic doar emoțiile de bază; răspunsul corect se potrivește cu situația', () {
      for (var seed = 0; seed < 100; seed++) {
        for (final r in _build(const CeSimteGame(), 1, seed).rounds) {
          final correct = r.choices.singleWhere((c) => c.correct);
          final e = feltEmotions.firstWhere((e) => e.emoji == correct.art);
          expect(e.minTier, 1);
          final scene = (r.visuals.whereType<SceneVisual>().single).text;
          final names = characters.map((c) => c.name);
          expect(
            e.situations.any((s) => names.any((n) => s.replaceAll('{n}', n) == scene)),
            isTrue,
            reason: scene,
          );
        }
      }
    });

    test('acordul pe gen: fetele primesc forma de feminin', () {
      for (var seed = 0; seed < 60; seed++) {
        for (final r in _build(const CeSimteGame(), 6, seed).rounds) {
          if (r.prompt.startsWith('Cum se simte Ana') || r.prompt.startsWith('Cum se simte Sofia')) {
            for (final c in r.choices) {
              expect(feltEmotions.map((e) => e.fem), contains(c.label));
            }
          }
        }
      }
    });

    test('de la tier 4 apar și întrebări despre cauză', () {
      final prompts = [for (var s = 0; s < 10; s++) ..._build(const CeSimteGame(), 4, s).rounds.map((r) => r.prompt)];
      expect(prompts.any((p) => p.startsWith('De ce')), isTrue);
      final low = [for (var s = 0; s < 10; s++) ..._build(const CeSimteGame(), 2, s).rounds.map((r) => r.prompt)];
      expect(low.any((p) => p.startsWith('De ce')), isFalse);
    });
  });

  test('ce-mă-ajută: corectul e mereu o strategie bună, distractorii mereu nepotriviți', () {
    final good = {for (final l in helpfulStrategies.values) ...l.map((s) => s.label)};
    final bad = unhelpfulStrategies.map((s) => s.label).toSet();
    for (final tier in [1, 4, 8]) {
      for (var seed = 0; seed < 60; seed++) {
        for (final r in _build(const CeMaAjutaGame(), tier, seed).rounds) {
          for (final c in r.choices) {
            expect(c.correct ? good : bad, contains(c.label));
          }
          expect(r.prompt, anyOf('Ce o poate ajuta?', 'Ce îl poate ajuta?'));
        }
      }
    }
  });

  group('cine-știe', () {
    test('credința falsă: răspunsul e locul INIȚIAL; la control, locul FINAL', () {
      var beliefs = 0, controls = 0;
      for (var seed = 0; seed < 80; seed++) {
        for (final r in _build(const CineStieGame(), 3, seed).rounds) {
          if (!r.prompt.startsWith('Unde')) continue;
          final story = r.speak;
          final correct = r.choices.singleWhere((c) => c.correct).label!.toLowerCase();
          if (r.prompt.startsWith('Unde va căuta')) {
            beliefs++;
            expect(story[0], contains(correct), reason: story.join(' '));
          } else {
            controls++;
            expect(story[2], contains(correct), reason: story.join(' '));
          }
          // Cele două locuri din poveste sunt diferite.
          expect(story[0].split(' ').last, isNot(story[2].split(' ').last));
        }
      }
      expect(beliefs, greaterThan(0));
      expect(controls, greaterThan(0));
    });

    test('accesul la informație: știe cel care a ascuns', () {
      for (var seed = 0; seed < 50; seed++) {
        for (final r in _build(const CineStieGame(), 1, seed).rounds) {
          final hider = r.speak.first.split(' ').first;
          expect(r.choices.singleWhere((c) => c.correct).label, hider);
        }
      }
    });

    test('conținut neașteptat de la tier 5: răspunsul e ce scrie pe cutie', () {
      var seen = 0;
      for (var seed = 0; seed < 30; seed++) {
        for (final r in _build(const CineStieGame(), 6, seed).rounds) {
          if (!r.prompt.startsWith('Ce crede')) continue;
          seen++;
          final box = trickBoxes.firstWhere((b) => r.speak.first.contains(b.name));
          expect(r.choices.singleWhere((c) => c.correct).label, box.expected);
        }
      }
      expect(seen, greaterThan(0));
    });
  });

  test('situații: complexitatea crește cu tier-ul', () {
    Set<String> questions(int tier) => {
          for (var s = 0; s < 40; s++) ..._build(const SituatiiGame(), tier, s).rounds.map((r) => r.prompt),
        };
    final level1 = socialScenarios.where((s) => s.level == 1).map((s) => s.question).toSet();
    expect(level1.containsAll(questions(1)), isTrue);
    expect(questions(6).difference(level1), isNotEmpty);
  });
}
