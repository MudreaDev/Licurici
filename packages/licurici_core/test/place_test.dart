import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  const game = PlaceGame();

  test('locurile cerute există pe scenă, sunt diferite și se potrivesc reperului', () {
    for (var level = 1; level <= 7; level++) {
      for (var seed = 0; seed < 40; seed++) {
        final l = game.generate(level, seed: seed);
        expect(l.rounds, hasLength(PlaceGame.rounds));
        for (final r in l.rounds) {
          expect(r.spots.length, greaterThanOrEqualTo(2));
          expect(r.spots.every((s) => PlaceGame.fits(s, r.landmark)), isTrue);
          expect(r.spots.every(l.axes.relations.contains), isTrue);
          expect(r.tasks.every((t) => r.spots.contains(t.relation)), isTrue);
          expect(r.tasks.map((t) => t.relation).toSet(), hasLength(r.tasks.length));
          expect(r.tasks.map((t) => t.word).toSet(), hasLength(r.tasks.length));
          expect(r.tasks, hasLength(level >= 5 ? 2 : 1));
        }
      }
    }
  });

  test('nivelul 1: doar pe / sub, la masă; „deasupra” cere genitivul', () {
    final l = game.generate(1, seed: 4);
    expect(l.rounds.every((r) => r.landmark == Landmark.masa), isTrue);
    expect(Relation.deasupra.at(Landmark.masa), 'deasupra mesei');
    expect(Relation.inauntru.at(Landmark.cutie), 'în cutie');
    final r = l.rounds.first;
    expect(r.speak.single, startsWith('Pune ${r.tasks.first.word} '));
  });

  test('nivelul 5: o propoziție cu două obiecte', () {
    final r = game.generate(5, seed: 1).rounds.first;
    expect(r.speak, hasLength(3));
    expect(r.speak[1], 'și');
  });

  test('rezultat: stele, nivelul următor și încercările salvate', () {
    final l = game.generate(3, seed: 2);
    final answers = [
      for (final (i, r) in l.rounds.indexed)
        PlaceAnswer(r, wrong: i == 0 ? 1 : 0, ms: 2000, firstWrong: i == 0 ? r.spots.firstWhere((s) => s != r.tasks.first.relation) : null),
    ];
    final result = PlaceResult(l, answers);
    expect(result.stars, 3);
    expect(result.suggestedNextLevel(3), 4);
    final rec = SessionRecorder(childId: 'c', clock: () => DateTime(2026, 10, 16));
    rec.placeLevel(result);
    final t = rec.trials;
    expect(t, hasLength(PlaceGame.rounds));
    expect(t.first.correct, isFalse);
    expect(t.first.stepId, 'LRC6');
    expect(t.first.chosenId, isNotNull);
    expect(t.first.targetId, l.rounds.first.tasks.first.relation.at(l.rounds.first.landmark));
  });
}
