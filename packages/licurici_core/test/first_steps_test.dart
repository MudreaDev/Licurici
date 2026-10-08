import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  test('fiecare întrebare are trepte, iar literele și numerele nu se amestecă', () {
    for (final q in firstStepQuestions) {
      expect(q.steps, isNotEmpty, reason: q.id);
    }
    final pacl = firstStepQuestions.firstWhere((q) => q.id == 'pacl').steps.map((s) => s.id);
    expect(pacl.every((id) => id.startsWith('PAC-L')), isTrue);
    final pacn = firstStepQuestions.firstWhere((q) => q.id == 'pacn').steps.map((s) => s.id);
    expect(pacn.every((id) => id.startsWith('PAC-N')), isTrue);
  });

  test('„Încă nu” ascunde doar jocurile grele ale ariei; „Da” pornește mai sus; fără răspuns nu schimbă nimic', () {
    expect(firstStepsPlan(const {}).hidden, isEmpty);
    final p = firstStepsPlan(const {'pacl': FirstStepAnswer.notYet, 'emo': FirstStepAnswer.yes});
    expect(p.hidden, contains('ortografie'));
    expect(p.hidden, isNot(contains('alfabetul'))); // prima treaptă rămâne
    expect(p.levels['emotii'], 3);
    expect(p.hidden.intersection({'emotii', 'ce-simte'}), isEmpty);
  });

  test('un joc folosit și de o arie unde copilul se descurcă nu se ascunde', () {
    final p = firstStepsPlan(const {'fex': FirstStepAnswer.notYet, 'pot': FirstStepAnswer.sometimes});
    // `perechi` e pe FEX5 (grea), dar și pe altă treaptă? Regula generală: dacă apare în keep, rămâne.
    for (final g in p.hidden) {
      expect(firstStepQuestions.firstWhere((q) => q.id == 'pot').steps.expand((s) => s.games), isNot(contains(g)));
    }
  });
}
