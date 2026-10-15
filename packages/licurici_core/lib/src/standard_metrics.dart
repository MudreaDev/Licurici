/// Metricile standard ale jocurilor măsurabile (README §0.1, planul jocurilor măsurabile;
/// docs/research/07-dificultate-adaptiva.md): fiecare joc are măsura folosită în literatura de
/// specialitate, calculată din încercările salvate (aceleași date pe tabletă, în panou și pe server).
///
/// - Linia numerelor → **PAE** (eroarea procentuală absolută; mai mică = mai bine);
/// - Atinge rapid → **throughput** Fitts (biți/s; mai mare = mai bine);
/// - Stop! → **SSRT** (ms; mai mic = frână mai bună) și cât de des s-a oprit;
/// - Paznicul farului → bărci prinse în prima vs a doua jumătate (**scăderea vigilenței**);
/// - Cât de tare? → **pragul**: cea mai mică diferență de intensitate recunoscută;
/// - Câte sunt? → **subitizarea**: cea mai mare cantitate recunoscută dintr-o privire;
/// - Acum sau mai mult? → cât de des **a așteptat** și cea mai lungă așteptare dusă la capăt;
/// - Ce ai auzit? → precizia pe **perechile minimale**;
/// - Cine e prietenul? → nivelul cel mai greu cu ≥ 75% corect.
library;

import 'dart:math';

import 'games/faces.dart';
import 'trial.dart';

class StandardMetric {
  const StandardMetric({
    required this.gameId,
    required this.name,
    required this.value,
    required this.raw,
    required this.meaning,
    required this.higherIsBetter,
    required this.trials,
  });

  final String gameId;

  /// Numele măsurii (ex. „PAE”).
  final String name;

  /// Valoarea gata de afișat (ex. „12%”, „2,4 biți/s”).
  final String value;

  /// Valoarea numerică (pentru comparații între perioade).
  final double raw;

  /// Ce înseamnă, pe scurt, pentru specialist.
  final String meaning;
  final bool higherIsBetter;

  /// Din câte încercări s-a calculat.
  final int trials;
}

String _num(double x, [int digits = 1]) => x.toStringAsFixed(digits).replaceAll('.', ',');

String _pct(double x) => '${(x * 100).round()}%';

double _median(List<num> xs) {
  final s = [...xs]..sort();
  return s.isEmpty ? 0 : s[s.length ~/ 2].toDouble();
}

/// Metricile standard din [trials] (orice ordine; se grupează pe joc). Jocurile fără destule
/// încercări nu apar.
List<StandardMetric> standardMetrics(Iterable<Trial> trials) {
  final byGame = <String, List<Trial>>{};
  for (final t in trials) {
    byGame.putIfAbsent(t.gameId, () => []).add(t);
  }
  final out = <StandardMetric>[];
  for (final MapEntry(key: game, value: ts) in byGame.entries) {
    final m = switch (game) {
      'linia-numerelor' => _pae(ts),
      'atinge-rapid' => _throughput(ts),
      'stop' => _ssrt(ts),
      'paznicul-farului' => _vigilance(ts),
      'cat-de-tare' => _threshold(ts),
      'cate-sunt' => _subitizing(ts),
      'acum-sau-mai-mult' => _delay(ts),
      'ce-ai-auzit' => _pairs(ts),
      'cine-e-prietenul' => _faces(ts),
      _ => null,
    };
    if (m != null) out.add(m);
  }
  return out;
}

StandardMetric? _pae(List<Trial> ts) {
  final errs = [
    for (final t in ts)
      if (t.stimulusId case final s? when s.startsWith('eroare-')) int.tryParse(s.substring(7)),
  ].whereType<int>().toList();
  if (errs.length < 3) return null;
  final mean = errs.reduce((a, b) => a + b) / errs.length / 100;
  return StandardMetric(
    gameId: 'linia-numerelor',
    name: 'PAE',
    value: _pct(mean),
    raw: mean,
    meaning: 'Eroarea medie pe linia numerelor (cât din linie). Sub 10% la 0–100 = estimare foarte bună.',
    higherIsBetter: false,
    trials: errs.length,
  );
}

StandardMetric? _throughput(List<Trial> ts) {
  final xs = [
    for (final t in ts)
      if (t.correct && (t.difficulty ?? 0) > 0 && (t.latencyMs ?? 0) > 80) t.difficulty! / (t.latencyMs! / 1000),
  ];
  if (xs.length < 5) return null;
  final mean = xs.reduce((a, b) => a + b) / xs.length;
  return StandardMetric(
    gameId: 'atinge-rapid',
    name: 'Throughput (Fitts)',
    value: '${_num(mean)} biți/s',
    raw: mean,
    meaning: 'Viteză și precizie împreună, independent de mărimea țintelor. Crește odată cu controlul motor fin.',
    higherIsBetter: true,
    trials: xs.length,
  );
}

StandardMetric? _ssrt(List<Trial> ts) {
  final go = [for (final t in ts) if (t.stimulusId == 'go' && t.latencyMs != null) t.latencyMs!];
  final stops = [for (final t in ts) if (t.stimulusId == 'stop') t];
  final ssd = [for (final t in stops) if (t.difficulty != null) t.difficulty!];
  if (go.length < 5 || ssd.length < 3) return null;
  final ssrt = max(0.0, _median(go) - ssd.reduce((a, b) => a + b) / ssd.length);
  final stopped = stops.where((t) => t.correct).length / stops.length;
  return StandardMetric(
    gameId: 'stop',
    name: 'SSRT',
    value: '${ssrt.round()} ms · s-a oprit ${_pct(stopped)}',
    raw: ssrt,
    meaning: 'Cât îi trebuie ca să oprească o mișcare pornită (inhibiție). Mai mic = frână mai bună.',
    higherIsBetter: false,
    trials: go.length + stops.length,
  );
}

StandardMetric? _vigilance(List<Trial> ts) {
  final go = [for (final t in ts) if (t.targetId == 'atinge') t];
  if (go.length < 8) return null;
  final half = go.length ~/ 2;
  double rate(Iterable<Trial> xs) => xs.where((t) => t.correct).length / max(1, xs.length);
  final first = rate(go.take(half)), second = rate(go.skip(half));
  return StandardMetric(
    gameId: 'paznicul-farului',
    name: 'Vigilență',
    value: '${_pct(first)} → ${_pct(second)}',
    raw: second - first,
    meaning: 'Bărci prinse în prima vs a doua jumătate a pazei. O scădere mare = atenția obosește repede.',
    higherIsBetter: true,
    trials: go.length,
  );
}

/// Pe nivel: (încercări, corecte), pentru jocurile cu alegere (nivelul = treapta de dificultate).
Map<int, (int, int)> _byLevel(List<Trial> ts) {
  final m = <int, (int, int)>{};
  for (final t in ts) {
    final l = t.level ?? 1;
    final (n, c) = m[l] ?? (0, 0);
    m[l] = (n + 1, c + (t.correct && t.attempts <= 1 ? 1 : 0));
  }
  return m;
}

/// Cel mai greu nivel cu cel puțin [minTrials] încercări și ≥ [ok] corecte din prima.
int? _bestLevel(List<Trial> ts, {double ok = 0.75, int minTrials = 4}) {
  int? best;
  for (final MapEntry(key: l, value: (n, c)) in _byLevel(ts).entries) {
    if (n >= minTrials && c / n >= ok && (best == null || l > best)) best = l;
  }
  return best;
}

StandardMetric? _threshold(List<Trial> ts) {
  final best = _bestLevel(ts);
  if (best == null) return null;
  final gap = CatDeTareGame.gapFor(best);
  return StandardMetric(
    gameId: 'cat-de-tare',
    name: 'Pragul emoției',
    value: 'diferența de ${_pct(gap)}',
    raw: gap,
    meaning: 'Cea mai mică diferență de intensitate a expresiei pe care o recunoaște sigur. Mai mică = mai fin.',
    higherIsBetter: false,
    trials: ts.length,
  );
}

StandardMetric? _subitizing(List<Trial> ts) {
  final byN = <int, (int, int)>{};
  for (final t in ts) {
    final n = int.tryParse((t.stimulusId ?? '').replaceFirst('n-', ''));
    if (n == null) continue;
    final (a, c) = byN[n] ?? (0, 0);
    byN[n] = (a + 1, c + (t.correct && t.attempts <= 1 ? 1 : 0));
  }
  var span = 0;
  for (var n = 1; n <= 9; n++) {
    final (a, c) = byN[n] ?? (0, 0);
    if (a >= 2 && c / a >= 0.8) {
      span = n;
    } else if (a >= 2) {
      break;
    }
  }
  if (byN.values.fold(0, (s, e) => s + e.$1) < 6) return null;
  return StandardMetric(
    gameId: 'cate-sunt',
    name: 'Subitizare',
    value: span == 0 ? 'încă nu' : 'până la $span',
    raw: span.toDouble(),
    meaning: 'Câte obiecte recunoaște dintr-o privire, fără să numere (la copii tipici: 3–4).',
    higherIsBetter: true,
    trials: ts.length,
  );
}

StandardMetric? _delay(List<Trial> ts) {
  if (ts.length < 2) return null;
  final waited = ts.where((t) => t.correct).toList();
  final longest = waited.isEmpty ? 0.0 : waited.map((t) => t.difficulty ?? 0).reduce(max);
  final rate = waited.length / ts.length;
  return StandardMetric(
    gameId: 'acum-sau-mai-mult',
    name: 'Amânarea recompensei',
    value: 'a așteptat ${_pct(rate)}${longest > 0 ? ', cel mult ${longest.round()} s' : ''}',
    raw: rate,
    meaning: 'Cât de des alege și duce la capăt așteptarea pentru o recompensă mai mare (autocontrol).',
    higherIsBetter: true,
    trials: ts.length,
  );
}

StandardMetric? _pairs(List<Trial> ts) {
  final hard = [for (final t in ts) if ((t.level ?? 1) >= 3) t];
  if (hard.length < 4) return null;
  final acc = hard.where((t) => t.correct && t.attempts <= 1).length / hard.length;
  return StandardMetric(
    gameId: 'ce-ai-auzit',
    name: 'Perechi minimale',
    value: _pct(acc),
    raw: acc,
    meaning: 'Deosebește cuvinte care diferă doar prin primul sunet (câine/pâine). Sub 80% = de lucrat cu logopedul.',
    higherIsBetter: true,
    trials: hard.length,
  );
}

StandardMetric? _faces(List<Trial> ts) {
  final best = _bestLevel(ts);
  if (best == null) return null;
  return StandardMetric(
    gameId: 'cine-e-prietenul',
    name: 'Recunoașterea feței',
    value: 'nivelul $best',
    raw: best.toDouble(),
    meaning: 'Recunoaște aceeași persoană cu altă expresie; la niveluri mari, ceilalți copii seamănă tot mai mult.',
    higherIsBetter: true,
    trials: ts.length,
  );
}
