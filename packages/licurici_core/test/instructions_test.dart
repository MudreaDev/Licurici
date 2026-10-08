import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  const game = InstructionGame();

  test('instrucțiunea spune obiectele în ordine; pe dos cu „Înainte de”', () {
    final mar = objectWords.firstWhere((o) => o.word == 'mărul');
    final minge = objectWords.firstWhere((o) => o.word == 'mingea');
    expect(InstructionGame.phrase([mar]), 'Atinge mărul.');
    expect(InstructionGame.phrase([mar, minge]), 'Atinge mărul, apoi mingea.');
    expect(InstructionGame.phrase([mar, minge], reversed: true), 'Înainte de minge, atinge mărul.');
    // Rostit pe bucăți (câte un clip), cu pauză între pași.
    expect(InstructionGame.pieces([mar, minge]), ['Atinge mărul', 'apoi mingea']);
    expect(InstructionGame.pieces([mar, minge], reversed: true), ['Înainte de minge', 'atinge mărul']);
  });

  test('nivelurile: mai mulți pași, mai multe obiecte, ordine inversă, de ținut minte', () {
    final a = game.axesFor(1), b = game.axesFor(12);
    expect(a.steps, 1);
    expect(b.steps, 3);
    expect(b.objects, greaterThan(a.objects));
    expect(a.familiarOnly, isTrue);
    expect(b.reversed && b.hidden, isTrue);
    for (final level in [1, 4, 8, 12]) {
      final l = game.generate(level, seed: level);
      for (final r in l.rounds) {
        expect(r.order.toSet().length, r.order.length);
        expect(r.order.every((k) => k < r.table.length), isTrue);
        expect(r.table.map((o) => o.word).toSet().length, r.table.length);
        if (level <= 4) expect(r.table.every((o) => o.familiar), isTrue);
        // Fiecare obiect cerut e pomenit în instrucțiune.
        for (final k in r.order) {
          expect(r.says, contains(r.reversedWording && k == r.order.last ? '' : r.table[k].word));
        }
      }
    }
  });

  test('încercarea: curată doar în ordine și fără ajutor; se înregistrează', () {
    final l = game.generate(5, seed: 3);
    final r = l.rounds.first;
    final ok = InstructionAttempt(r, taps: r.order, prompt: PromptLevel.p0);
    final swapped = InstructionAttempt(r, taps: r.order.reversed.toList(), prompt: PromptLevel.p0);
    final helped = InstructionAttempt(r, taps: r.order, prompt: PromptLevel.p2);
    expect(ok.clean, isTrue);
    expect(swapped.clean, isFalse);
    expect(swapped.orderError, isTrue);
    expect(helped.clean, isFalse);
    final res = InstructionResult(l, [ok, swapped, helped]);
    expect(res.accuracy, closeTo(1 / 3, 1e-9));
    final rec = SessionRecorder(childId: 'c')..instructionLevel(res);
    expect(rec.trials.length, 3);
    expect(rec.trials.first.stepId, 'LRC5');
    expect(rec.trials[1].chosenId, r.table[r.order.last].word);
    expect(catalog.firstWhere((e) => e.id == 'asculta-si-fa').domain, Domain.lrc);
  });
}
