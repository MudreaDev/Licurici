/// Parametrii pe joc pe care îi alege specialistul (ADR-025, `GameConfig`): descriși ca date,
/// ca panoul să-și construiască formularul din ei și tableta să-i aplice la fel în toate jocurile.
/// Deocamdată parametrii comuni tuturor jocurilor adaptive: de unde pornește și până unde urcă.
library;

import 'development.dart';

class GameParam {
  const GameParam(this.id, this.label, this.help, {this.min = 1, this.max = 20});

  /// Cheia din plan (`levels` / `maxLevels` pe server).
  final String id;
  final String label;
  final String help;
  final int min;
  final int max;
}

const startLevelParam = GameParam(
  'start',
  'Pornește de la',
  'Nivelul cu care începe jocul data viitoare. Apoi jocul se adaptează singur.',
);

const maxLevelParam = GameParam(
  'max',
  'Nu urcă peste',
  'Plafonul de dificultate: jocul rămâne adaptiv, dar nu trece de acest nivel '
      '(de exemplu, până se consolidează treapta).',
);

const gameParams = [startLevelParam, maxLevelParam];

/// Nivelul permis, ținând cont de plafon (null = fără plafon) și de minimul 1.
int capLevel(int level, int? max) {
  final l = level < 1 ? 1 : level;
  return max != null && l > max ? max : l;
}

/// Transferul între jocuri înrudite (aceeași treaptă): prima dată când copilul deschide
/// [gameId], pornește cu 2 niveluri sub cel mai mare nivel atins într-un joc frate — prudent,
/// ca să înceapă cu reușite. null = nimic de transferat (niciun frate peste nivelul 2).
int? transferredLevel(String gameId, Map<String, int> levels) {
  final siblings = {
    for (final s in stepsForGame(gameId))
      for (final g in s.games)
        if (g != gameId) g,
  };
  var best = 0;
  for (final g in siblings) {
    final l = levels[g] ?? 0;
    if (l > best) best = l;
  }
  return best >= 3 ? best - 2 : null;
}

