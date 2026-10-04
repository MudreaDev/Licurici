import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  const game = ChangeGame();

  test('exact o schimbare, de tipul cerut; celulele nu se suprapun', () {
    for (var level = 1; level <= 14; level++) {
      for (var seed = 0; seed < 30; seed++) {
        final l = game.generate(level, seed: seed);
        for (final r in l.rounds) {
          expect(l.axes.kinds, contains(r.kind));
          expect(r.before, hasLength(l.axes.items));
          final cellsAfter = r.after.map((i) => i.cell).toList();
          expect(cellsAfter.toSet(), hasLength(cellsAfter.length));
          expect(cellsAfter.every((c) => c < r.cols * r.rows), isTrue);
          final b = {for (final i in r.before) '${i.cell}${i.object.emoji}'};
          final a = {for (final i in r.after) '${i.cell}${i.object.emoji}'};
          switch (r.kind) {
            case ChangeKind.appear:
              expect(a.difference(b), hasLength(1));
              expect(b.difference(a), isEmpty);
              expect(r.after.last.object, r.target);
            case ChangeKind.replace:
              expect(a.difference(b), hasLength(1));
              expect(b.difference(a), hasLength(1));
              expect(r.after.any((i) => i.object == r.target), isTrue);
              expect(r.before.any((i) => i.object == r.target), isFalse);
            case ChangeKind.disappear:
              expect(b.difference(a), hasLength(1));
              expect(a.difference(b), isEmpty);
              expect(r.options, contains(r.target));
              expect(r.options.where((o) => r.before.any((i) => i.object == o)), [r.target]);
          }
        }
      }
    }
  });

  test('progresia: apare → înlocuit → dispărut; mai multe obiecte, mai puțin timp', () {
    expect(game.axesFor(1).kinds, [ChangeKind.appear]);
    expect(game.axesFor(5).kinds, contains(ChangeKind.replace));
    expect(game.axesFor(8).kinds, contains(ChangeKind.disappear));
    expect(game.axesFor(1).items, 3);
    expect(game.axesFor(30).items, 8);
    expect(game.axesFor(30).lookMs, 2500);
  });

  test('înregistrarea', () {
    final l = game.generate(8, seed: 3);
    final rec = SessionRecorder(childId: 'c')
      ..changeLevel(ChangeResult(l, [
        ChangeAnswer(l.rounds[0], correct: true, ms: 1800),
        ChangeAnswer(l.rounds[1], correct: false, chosen: 'mărul'),
      ]));
    expect(rec.trials.first.stimulusSet, l.rounds[0].kind.name);
    expect(rec.trials.last.chosenId, 'mărul');
    expect(rec.trials.first.stepId, 'ATN5');
    expect(catalogEntry('ce-s-a-schimbat')!.domain, Domain.atn);
  });
}
