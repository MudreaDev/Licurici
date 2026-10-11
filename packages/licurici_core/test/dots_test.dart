import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  test('desenele: puncte distincte, cele închise se termină unde au început', () {
    for (final f in dotFigures) {
      final marks = dotMarks(f);
      expect(marks, hasLength(f.dots), reason: f.id);
      expect(marks.toSet(), hasLength(f.dots), reason: '${f.id}: două puncte în același loc');
      expect(f.dots, inInclusiveRange(3, 12));
    }
  });

  test('nivelul limitează câte puncte are un desen; nivelurile mari aduc desene noi', () {
    for (var level = 1; level <= 12; level++) {
      final l = const DotsGame().generate(level, seed: level);
      expect(l.paths, hasLength(const DotsGame().axesFor(level).paths));
      expect(l.paths.every((p) => p.figure!.dots <= maxDotsFor(level)), isTrue, reason: 'nivelul $level');
      expect(l.paths.map((p) => p.figure!.id).toSet(), hasLength(l.paths.length), reason: 'fără repetări');
    }
    expect(const DotsGame().generate(10, seed: 1).paths.map((p) => p.figure!.dots).reduce((a, b) => a > b ? a : b), greaterThan(8));
  });

  test('un deget care urmează linia termină desenul, fără ieșiri', () {
    for (final f in dotFigures) {
      final path = TracePath(index: 0, shape: TraceShape.line, points: dotPathPoints(f), trip: const TraceTrip('✏️', '⭐', ''), figure: f);
      final t = TraceTracker(path, width: 0.12, aspect: 1.75);
      expect(t.down(path.points.first.x, path.points.first.y), isTrue);
      for (final p in path.points) {
        t.move(p.x, p.y);
      }
      expect(t.done, isTrue, reason: f.id);
      expect(t.exits, 0, reason: f.id);
    }
  });

  test('înregistrarea: încercările sunt ale jocului, pe treptele de motricitate', () {
    final level = const DotsGame().generate(2, seed: 4);
    final rec = SessionRecorder(childId: 'c');
    rec.traceLevel(TraceResult(level, [for (final p in level.paths) TraceRun(path: p, completed: true, exits: 0, meanDeviation: 0.1)]));
    final trials = rec.close()!.trials;
    expect(trials, hasLength(level.paths.length));
    expect(trials.every((t) => t.gameId == 'uneste-punctele' && t.stepId.startsWith('MOT') && t.level == 2), isTrue);
  });
}
