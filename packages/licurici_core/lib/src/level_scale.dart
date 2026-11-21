/// Scara comună a nivelurilor (calibrarea dificultății între jocuri, ADR-027,
/// docs/research/07-dificultate-adaptiva.md §6).
///
/// Problema: fiecare joc are nivelurile lui. „Construiește” atinge dificultatea maximă la
/// nivelul 7, „Felinarele” abia la 25; jocurile cu alegere au treptele `Difficulty.tier`, care se
/// plafonează la 7. Un rating Elo pe treaptă care amestecă aceste scări ar trata nivelul 7 din
/// ambele jocuri ca fiind la fel de greu.
///
/// Soluția: fiecare joc își declară **plafonul** — nivelul de la care axele lui nu mai cresc.
/// Pe scara comună, nivelul 1 al oricărui joc valorează [LevelScale.base] (1000), iar plafonul
/// valorează [LevelScale.top] (1400); între ele, liniar. Peste plafon jocul nu mai devine mai
/// greu, deci nici dificultatea pe scară nu mai crește.
library;

import 'dart:math';

class LevelScale {
  const LevelScale(this.plateau) : assert(plateau >= 2);

  /// Nivelul de la care jocul nu mai devine mai greu (toate axele la maxim).
  final int plateau;

  static const double base = 1000;
  static const double top = 1400;

  /// Dificultatea pe scara rating-ului pentru [level].
  double difficultyOf(int level) {
    final t = ((level - 1) / (plateau - 1)).clamp(0.0, 1.0);
    return base + (top - base) * t;
  }

  /// Cel mai mare nivel al jocului cu dificultatea ≤ [difficulty] (cel puțin 1, cel mult plafonul).
  int levelAt(double difficulty) {
    final t = ((difficulty - base) / (top - base)).clamp(0.0, 1.0);
    return max(1, min(plateau, 1 + (t * (plateau - 1) + 1e-9).floor()));
  }
}

/// Jocurile cu alegere: treapta `Difficulty.tier` atinge 5 variante la 6 și 8 runde la 7.
const choiceScale = LevelScale(7);

/// Jocurile cu o nouă treaptă la 8: minute apropiate sau distractori numerici apropiați.
const extendedChoiceGames = {
  'numaram', 'adunam', 'scadem', 'numarul-lipsa', 'inmultim', 'impartim',
  'bani', 'tabla', 'probleme', 'cate-sunt', 'ceasul', 'culori', 'forme', 'potriveste', 'umbre', 'intrusul',
  'arata-mi', 'corpul', 'ce-face', 'mingea-rosie', 'unde-e-ursul', 'primul-sunet', 'ce-se-aude', 'da-nu', 'continua-sirul',
};

/// Plafonul fiecărui joc cu niveluri proprii, citit din funcția lui `axesFor` / generator
/// (testul `level_scale_test.dart` cere ca orice joc nou din catalog să apară aici sau să fie
/// un joc cu alegere). Jocurile fără niveluri (creație, AAC, respirație) nu produc rating.
const gameScales = <String, LevelScale>{
  // reacție
  'pescarul': LevelScale(21), // până la 24 de apariții
  'prinde-licuriciul': LevelScale(23), // până la 22 de apariții pentru atenția susținută
  'paznicul-farului': LevelScale(20), // distractori mai frecvenți, apoi apariții mai scurte
  // secvențe
  'simon': LevelScale(28), // secvențe de până la 11 pași
  'licuricii': LevelScale(28), // secvențe de până la 11 pași
  // memorie, sortare, căutare
  'perechi': LevelScale(17),
  'sortam': LevelScale(12),
  'la-locul-lui': LevelScale(12),
  'sortam-emotiile': LevelScale(12),
  'cauta': LevelScale(19),
  'cucu-bau': LevelScale(18),
  'ce-s-a-schimbat': LevelScale(19),
  'diferente': LevelScale(19), // 16 obiecte la 13, 10 diferențe la 19
  'la-magazin': LevelScale(10),
  // construcție, puzzle, labirint
  'construieste': LevelScale(14),
  'linia-numerelor': LevelScale(8), // 0–100 fără repere la 8
  'atinge-rapid': LevelScale(9), // bula de 0,07 la 9 (distanța se oprește la 9)
  'stop': LevelScale(13), // 36 de încercări, 30% opriri
  'turnul': LevelScale(11), // 8 inele la 11, diferența minimă la 9
  'adu-mi': LevelScale(10), // șase obiecte pe masă, până la patru cerute
  'pune-ursul': LevelScale(9), // până la patru obiecte și poziții într-o cerere
  'oglinda': LevelScale(14), // până la șapte atingeri în secvență
  'memorie-sunete': LevelScale(13), // până la 9 perechi
  'coloreaza-ce-auzi': LevelScale(11), // până la patru obiecte și culori
  'acum-sau-mai-mult': LevelScale(13), // până la 6 oferte
  'puzzle': LevelScale(15), // 6 × 4 fără model la 15
  'labirint': LevelScale(13), // până la cinci labirinturi 10 × 6
  // atenție comună, imitație, ritm
  'unde-se-uita': LevelScale(10),
  'fa-ca-licuriciul': LevelScale(13),
  'toba-magica': LevelScale(17),
  'urmareste-pestele': LevelScale(20),
  // funcții executive
  'regula-se-schimba': LevelScale(14),
  'semaforul': LevelScale(14),
  'floarea-creste': LevelScale(14),
  'pe-rand': LevelScale(14),
  // limbaj
  'asculta-si-fa': LevelScale(15),
  // motricitate și scris
  'traseaza': LevelScale(10),
  'uneste-punctele': LevelScale(10),
  'hraneste-pestii': LevelScale(12), // viteza crește până la 12
  'atinge-si-vezi': LevelScale(10),
  'scriem-cifrele': LevelScale(10),
  'scriem-literele': LevelScale(10),
  // ordonare (rutine, povești, seriere, propoziții): 5 pași la nivelul 7
  'pasii-rutinei': LevelScale(7),
  'ce-urmeaza': LevelScale(11),
  'mare-mic': LevelScale(11),
  'orarul-meu': LevelScale(7),
  'spune-propozitia': LevelScale(13),
  // explorările: exemple suplimentare la nivelul 3
  'explorare-stiinte': LevelScale(4),
  'explorare-istorie': LevelScale(3),
  'explorare-viata': LevelScale(3),
};

/// Jocurile fără niveluri de dificultate (nu produc încercări notate cu nivel).
const unleveledGames = {'respira', 'colorare', 'vorbeste'};

/// Scara jocului [gameId]; jocurile cu alegere (și orice joc nedeclarat) folosesc [choiceScale].
LevelScale scaleFor(String gameId) => gameScales[gameId] ??
    (gameId == 'forma-ascunsa' ? const LevelScale(14) : (gameId == 'povesti' || gameId == 'ce-ai-auzit') ? const LevelScale(12) : (gameId == 'potriveste' || gameId == 'intrusul' || gameId == 'umbre' || gameId == 'culori' || gameId == 'forme' || gameId == 'arata-mi' || gameId == 'corpul' || gameId == 'ce-face' || gameId == 'mingea-rosie' || gameId == 'unde-e-ursul' || gameId == 'primul-sunet' || gameId == 'da-nu' || gameId == 'ce-se-aude' || gameId == 'continua-sirul') ? const LevelScale(10) : gameId == 'pozitii' ? const LevelScale(11) :
    ({'cum-se-simte', 'cat-de-tare', 'cine-e-prietenul', 'emotii', 'ce-simte', 'ce-ma-ajuta', 'cine-stie', 'situatii'}.contains(gameId) ? const LevelScale(10) : {'anotimpuri', 'habitate', 'peste-in-mijloc'}.contains(gameId) ? const LevelScale(9) : (extendedChoiceGames.contains(gameId) ? const LevelScale(8) : choiceScale)));
