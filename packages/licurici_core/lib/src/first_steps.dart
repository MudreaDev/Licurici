/// „Primii pași” (plan §5, pasul 1 — varianta fără specialist): câteva întrebări pentru părinte
/// despre ce face copilul **acum**, din care aplicația **propune** setul de pornire: ce jocuri
/// vede copilul și de la ce nivel pornesc. **Nu e o evaluare clinică** și nu se salvează
/// răspunsurile — doar propunerea, pe care părintele o poate schimba oricând („Jocurile
/// copilului”) și pe care un specialist o poate înlocui.
///
/// Regula, pe fiecare întrebare (o arie sau o parte a ei, în ordinea treptelor):
/// - „Încă nu” → rămân doar jocurile primelor două trepte; cele mai grele se ascund deocamdată;
/// - „Uneori” → toate jocurile, de la început;
/// - „Da, singur” → toate jocurile; ale primelor trepte pornesc mai sus (nivelul 3).
library;

import 'catalog.dart';
import 'development.dart';

enum FirstStepAnswer { notYet, sometimes, yes }

class FirstStepQuestion {
  const FirstStepQuestion(this.id, this.text, this.stepPrefix);

  final String id;

  /// Întrebarea, pe înțelesul părintelui.
  final String text;

  /// Treptele la care se referă (prefixul id-ului: `ATN`, `PAC-N`, `PAC-L`…).
  final String stepPrefix;

  /// Treptele vizate, în ordinea traseului.
  List<Step> get steps => [
    for (final l in ladders)
      for (final s in l.steps)
        if (_matches(s.id)) s,
  ];

  bool _matches(String id) {
    if (!id.startsWith(stepPrefix)) return false;
    // `PAC` singur nu înghite `PAC-N`/`PAC-L`; `PAC-N` nu înghite `PAC-NN`.
    final rest = id.substring(stepPrefix.length);
    return rest.isEmpty || RegExp(r'^[0-9]').hasMatch(rest);
  }
}

const firstStepQuestions = [
  FirstStepQuestion('atn', 'Se uită la ce apare pe ecran și urmărește un lucru care se mișcă?', 'ATN'),
  FirstStepQuestion('imi', 'Imită un gest simplu după tine (bate din palme, face „pa”)?', 'IMI'),
  FirstStepQuestion('pot', 'Potrivește două lucruri la fel (două mingi, două mere)?', 'POT'),
  FirstStepQuestion('lrc', 'Arată obiectul când îl numești („arată mingea”)?', 'LRC'),
  FirstStepQuestion('com', 'Cere ce vrea — cu cuvinte, gesturi sau imagini?', 'COM'),
  FirstStepQuestion('cog', 'Pune lucrurile în grupe (animale cu animale, fructe cu fructe)?', 'COG'),
  FirstStepQuestion('emo', 'Recunoaște pe o față dacă cineva e bucuros sau trist?', 'EMO'),
  FirstStepQuestion('fex', 'Poate aștepta câteva secunde un semnal sau rândul lui?', 'FEX'),
  FirstStepQuestion('aut', 'Știe pașii unei rutine (de exemplu, spălatul pe mâini)?', 'AUT'),
  FirstStepQuestion('mot', 'Trasează cu degetul sau cu creionul o linie de la un punct la altul?', 'MOT'),
  FirstStepQuestion('pacn', 'Numără obiecte până la 5?', 'PAC-N'),
  FirstStepQuestion('pacl', 'Recunoaște literele?', 'PAC-L'),
];

/// Propunerea: jocurile de ascuns (deocamdată) și nivelul de pornire pe joc.
class FirstStepsPlan {
  const FirstStepsPlan(this.hidden, this.levels);

  final Set<String> hidden;
  final Map<String, int> levels;
}

/// Câte trepte de la începutul unei arii rămân vizibile la „Încă nu”.
const _entrySteps = 2;

FirstStepsPlan firstStepsPlan(Map<String, FirstStepAnswer> answers) {
  final hideCandidates = <String>{};
  final keep = <String>{};
  final levels = <String, int>{};
  for (final q in firstStepQuestions) {
    final a = answers[q.id];
    if (a == null) continue;
    final steps = q.steps;
    for (final (i, s) in steps.indexed) {
      final entry = i < _entrySteps;
      switch (a) {
        case FirstStepAnswer.notYet:
          (entry ? keep : hideCandidates).addAll(s.games);
        case FirstStepAnswer.sometimes:
          keep.addAll(s.games);
        case FirstStepAnswer.yes:
          keep.addAll(s.games);
          if (entry) {
            for (final g in s.games) {
              levels[g] = 3;
            }
          }
      }
    }
  }
  // Un joc folosit și de o treaptă de început (sau de o arie unde copilul se descurcă) rămâne.
  final known = {for (final e in catalog) e.id};
  final hidden = {for (final g in hideCandidates) if (!keep.contains(g) && known.contains(g)) g};
  return FirstStepsPlan(hidden, {for (final e in levels.entries) if (known.contains(e.key)) e.key: e.value});
}
