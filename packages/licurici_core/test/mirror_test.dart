import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  const game = MirrorGame();

  test('atingerile: din părțile nivelului, fără aceeași atingere de două ori la rând', () {
    for (var level = 1; level <= 7; level++) {
      final axes = game.axesFor(level);
      for (var seed = 0; seed < 40; seed++) {
        final l = game.generate(level, seed: seed);
        expect(l.rounds, hasLength(MirrorGame.rounds));
        for (final r in l.rounds) {
          expect(r.touches, hasLength(axes.touches));
          expect(r.touches.every((t) => axes.parts.contains(t.part)), isTrue);
          expect(r.touches.every((t) => (t.side != null) == (axes.sided && t.part.paired)), isTrue);
          for (var i = 1; i < r.touches.length; i++) {
            expect(r.touches[i], isNot(r.touches[i - 1]));
          }
          expect(r.mirror == r.model, !axes.otherChild);
        }
      }
    }
  });

  test('latura contează doar de la nivelul 4', () {
    const any = MirrorTouch(FacePart.ochi);
    const left = MirrorTouch(FacePart.ochi, -1);
    expect(any.accepts(const MirrorTouch(FacePart.ochi, 1)), isTrue);
    expect(left.accepts(const MirrorTouch(FacePart.ochi, 1)), isFalse);
    expect(left.accepts(const MirrorTouch(FacePart.ochi, -1)), isTrue);
    expect(any.accepts(const MirrorTouch(FacePart.nas)), isFalse);
    expect(left.id, 'ochiul-stanga');
  });

  test('încercările salvate: treapta după numărul de atingeri, ajutorul ca P4', () {
    final l = game.generate(3, seed: 2);
    final answers = [
      for (final (i, r) in l.rounds.indexed)
        MirrorAnswer(r, wrong: i == 0 ? 2 : 0, ms: 3000, firstWrong: i == 0 ? const MirrorTouch(FacePart.par) : null, modelRepeated: i == 0),
    ];
    final result = MirrorResult(l, answers);
    expect(result.stars, 3);
    final rec = SessionRecorder(childId: 'c')..mirrorLevel(result);
    expect(rec.trials.first.stepId, 'IMI2');
    expect(rec.trials.first.promptLevel, PromptLevel.p4);
    expect(rec.trials.first.chosenId, 'părul');
    expect(rec.trials.last.correct, isTrue);
  });
}
