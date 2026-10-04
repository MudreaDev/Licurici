import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  const game = SearchGame();

  test('ținta apare exact o dată; obiectele nu ies din zonă și nu se suprapun', () {
    for (var level = 1; level <= 16; level++) {
      for (var seed = 0; seed < 30; seed++) {
        final l = game.generate(level, seed: seed);
        expect(l.rounds, hasLength(l.axes.rounds));
        for (final r in l.rounds) {
          expect(r.items, hasLength(l.axes.items));
          expect(r.items.where((i) => i.object.emoji == r.target.emoji), hasLength(1));
          expect(r.cols * r.rows, greaterThanOrEqualTo(r.items.length));
          for (final it in r.items) {
            expect(it.x, inExclusiveRange(0, 1));
            expect(it.y, inExclusiveRange(0, 1));
          }
          // Câte unul pe celulă: centrele sunt la cel puțin ~0.7 celule unul de altul.
          for (var a = 0; a < r.items.length; a++) {
            for (var b = a + 1; b < r.items.length; b++) {
              final dx = (r.items[a].x - r.items[b].x) * r.cols;
              final dy = (r.items[a].y - r.items[b].y) * r.rows;
              expect(dx * dx + dy * dy, greaterThan(0.69 * 0.69 - 1e-9));
            }
          }
        }
        // Țintele diferă de la o rundă la alta.
        expect(l.rounds.map((r) => r.target.emoji).toSet(), hasLength(l.rounds.length));
      }
    }
  });

  test('dificultatea: mai multe obiecte, apoi distractori din aceeași grupă', () {
    expect(game.axesFor(1).items, 4);
    expect(game.axesFor(30).items, 25);
    expect(game.axesFor(4).similar, isFalse);
    expect(game.axesFor(5).similar, isTrue);
    var same = 0, total = 0;
    for (var seed = 0; seed < 20; seed++) {
      for (final r in game.generate(8, seed: seed).rounds) {
        for (final it in r.items.where((i) => i.object.emoji != r.target.emoji)) {
          total++;
          if (it.object.group == r.target.group) same++;
        }
      }
    }
    expect(same / total, greaterThan(0.5));
    for (final r in game.generate(2, seed: 1).rounds) {
      expect(r.items.where((i) => i.object != r.target).every((i) => i.object.group != r.target.group), isTrue);
    }
  });

  test('înregistrarea: dificultatea = numărul de obiecte (panta căutării)', () {
    final l = game.generate(6, seed: 2);
    final rec = SessionRecorder(childId: 'c')
      ..searchLevel(SearchResult(l, [
        SearchFind(l.rounds[0], ms: 2500),
        SearchFind(l.rounds[1], ms: 4000, wrongTaps: 1, firstWrong: 'vaca'),
      ]));
    expect(rec.trials.first.difficulty, l.axes.items.toDouble());
    expect(rec.trials.first.latencyMs, 2500);
    expect(rec.trials.last.chosenId, 'vaca');
    expect(rec.trials.last.correct, isFalse);
    expect(catalogEntry('cauta')!.domain, Domain.atn);
  });
}
