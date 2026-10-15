import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  const g = FetchGame();

  test('2 → 6 obiecte, cuvinte cunoscute la început, aceeași grupă de la 4, două cerute de la 6', () {
    expect(g.axesFor(1).objects, 2);
    expect(g.axesFor(5).objects, 6);
    expect(g.axesFor(2).familiarOnly, isTrue);
    expect(g.axesFor(3).familiarOnly, isFalse);
    expect(g.axesFor(6).wanted, 2);
    for (var level = 1; level <= 8; level++) {
      for (var seed = 0; seed < 30; seed++) {
        final l = g.generate(level, seed: seed);
        expect(l.rounds, hasLength(FetchGame.rounds));
        String? last;
        for (final r in l.rounds) {
          expect(r.table, hasLength(l.axes.objects));
          expect(r.table.toSet(), hasLength(r.table.length), reason: 'fără obiecte duble pe masă');
          expect(r.wanted, hasLength(l.axes.wanted));
          for (final w in r.wanted) {
            expect(r.table, contains(w));
          }
          if (l.axes.familiarOnly) expect(r.wanted.every((w) => w.familiar), isTrue);
          expect(r.wanted.first.word, isNot(last), reason: 'nu aceeași cerere de două ori la rând');
          last = r.wanted.first.word;
          expect(r.speak.first, 'Adu-mi');
          if (r.wanted.length == 2) expect(r.speak, ['Adu-mi', r.wanted[0].word, 'și', r.wanted[1].word]);
        }
      }
    }
  });

  test('imaginile de evitat nu apar pe masă', () {
    final avoided = avoidedEmojis({'caini'});
    for (var seed = 0; seed < 30; seed++) {
      for (final r in g.generate(5, seed: seed, avoid: avoided).rounds) {
        expect(r.table.any((w) => avoided.contains(w.emoji)), isFalse);
      }
    }
  });

  test('rezultatul și înregistrarea (confuzia = primul obiect greșit)', () {
    final l = g.generate(3, seed: 2);
    final wrong = l.rounds[1].table.firstWhere((w) => !l.rounds[1].wanted.contains(w));
    final r = FetchResult(l, [
      FetchAnswer(l.rounds[0], wrong: 0, ms: 2000),
      FetchAnswer(l.rounds[1], wrong: 1, ms: 5000, firstWrong: wrong),
    ]);
    expect(r.accuracy, 0.5);
    final rec = SessionRecorder(childId: 'c')..fetchLevel(r);
    expect(rec.trials.last.chosenId, wrong.word);
    expect(rec.trials.last.targetId, l.rounds[1].wanted.first.word);
    expect(rec.trials.first.stepId, 'LRC1');
    expect(catalogEntry('adu-mi')!.domain, Domain.lrc);
  });
}
