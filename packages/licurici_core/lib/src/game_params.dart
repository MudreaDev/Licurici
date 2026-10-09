/// Parametrii pe joc pe care îi alege specialistul (ADR-025, `GameConfig`): descriși ca date,
/// ca panoul să-și construiască formularul din ei și tableta să-i aplice la fel în toate jocurile.
/// Deocamdată parametrii comuni tuturor jocurilor adaptive: de unde pornește și până unde urcă.
library;

import 'catalog.dart';
import 'development.dart';

class GameParam {
  const GameParam(this.id, this.label, this.help, {this.min = 1, this.max = 20, this.kinds});

  /// Cheia din plan (`levels` / `maxLevels` pe server).
  final String id;
  final String label;
  final String help;
  final int min;
  final int max;

  /// Pentru ce tipuri de joc are sens (null = toate jocurile adaptive).
  final Set<GameKind>? kinds;

  bool appliesTo(GameKind kind) => kinds == null || kinds!.contains(kind);
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

const roundsParam = GameParam(
  'rounds',
  'Runde, cel mult',
  'Câte runde are cel mult o tură de joc: mai puține pentru o atenție scurtă '
      '(altfel, câte dă nivelul — între 4 și 8).',
  min: 3,
  max: 8,
  kinds: {
    GameKind.choice,
    GameKind.build,
    GameKind.change,
    GameKind.feed,
    GameKind.gaze,
    GameKind.imitation,
    GameKind.listen,
    GameKind.order,
    GameKind.puzzle,
    GameKind.search,
    GameKind.shell,
    GameKind.shop,
  },
);

/// Câte runde rămân după alegerea specialistului (poate doar scurta tura, niciodată sub 1).
int cappedRounds(int total, int? cap) => cap == null || cap >= total ? total : (cap < 1 ? 1 : cap);

const gameParams = [startLevelParam, maxLevelParam, roundsParam];

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

