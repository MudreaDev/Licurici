import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  const game = ShellGame();

  test('răspunsul urmărește paharul cu obiectul prin toate mutările', () {
    const r = ShellRound(
      thing: HiddenThing('⚽', 'mingea'),
      start: 0,
      swaps: [(0, 1), (1, 2), (0, 2)],
    );
    // 0 → 1 → 2 → 0
    expect(r.answer, 0);
  });

  test('nivelurile: 2 → 4 pahare, 0 → 8 mutări, mutări valide, reproductibil', () {
    expect(game.axesFor(1).cups, 2);
    expect(game.axesFor(1).swaps, 0);
    expect(game.axesFor(14).swaps, 8);
    expect(game.axesFor(14).cups, 4);
    for (var l = 1; l <= 20; l++) {
      final level = game.generate(l, seed: l);
      expect(level.rounds, hasLength(ShellGame.roundsPerLevel));
      for (final r in level.rounds) {
        expect(r.start, inInclusiveRange(0, level.axes.cups - 1));
        for (final (a, b) in r.swaps) {
          expect(a, isNot(b));
          expect([a, b], everyElement(inInclusiveRange(0, level.axes.cups - 1)));
        }
      }
      expect(game.generate(l, seed: l).rounds.map((r) => r.answer),
          level.rounds.map((r) => r.answer));
    }
  });

  test('scor, nivelul următor și încercările cu dificultatea = nr. de mutări', () {
    final level = game.generate(6, seed: 2);
    final picks = [
      for (var i = 0; i < level.rounds.length; i++)
        ShellPick(i, i == 0 ? (level.rounds[0].answer + 1) % level.axes.cups : level.rounds[i].answer,
            ms: 1200),
    ];
    final r = ShellResult(level, picks);
    expect(r.accuracy, 0.8);
    expect(r.stars, 3);
    expect(r.suggestedNextLevel(6), 7);
    final rec = SessionRecorder(childId: 'c', clock: () => DateTime(2026, 10, 3));
    rec.shellLevel(r);
    final t = rec.trials;
    expect(t, hasLength(5));
    expect(t.first.correct, isFalse);
    expect(t.first.stepId, 'COG2');
    expect(t.first.difficulty, level.rounds.first.swaps.length.toDouble());
    expect(t.first.chosenId, startsWith('pahar-'));
  });

  test('în catalog: aria COG, ruta /cucu-bau', () {
    final e = catalogEntry('cucu-bau')!;
    expect(e.domain, Domain.cog);
    expect(e.route, '/cucu-bau');
  });
}
