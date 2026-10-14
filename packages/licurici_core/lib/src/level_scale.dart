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

/// Plafonul fiecărui joc cu niveluri proprii, citit din funcția lui `axesFor` / generator
/// (testul `level_scale_test.dart` cere ca orice joc nou din catalog să apară aici sau să fie
/// un joc cu alegere). Jocurile fără niveluri (creație, AAC, respirație) nu produc rating.
const gameScales = <String, LevelScale>{
  // reacție
  'pescarul': LevelScale(16), // viteza și proporția no-go cresc până la 16
  'prinde-licuriciul': LevelScale(14),
  'paznicul-farului': LevelScale(10), // durata, ritmul și mărimea se opresc la 10
  // secvențe
  'simon': LevelScale(25), // span 7 la 19, ordinea inversă de la 19, fără sunet de la 25
  'licuricii': LevelScale(19),
  // memorie, sortare, căutare
  'perechi': LevelScale(13),
  'sortam': LevelScale(10),
  'la-locul-lui': LevelScale(10),
  'sortam-emotiile': LevelScale(10),
  'cauta': LevelScale(14),
  'cucu-bau': LevelScale(14),
  'ce-s-a-schimbat': LevelScale(11),
  'diferente': LevelScale(13), // 16 obiecte la 13, 6 diferențe de la 11
  'la-magazin': LevelScale(10),
  // construcție, puzzle, labirint
  'construieste': LevelScale(7),
  'linia-numerelor': LevelScale(8), // 0–100 fără repere la 8
  'atinge-rapid': LevelScale(9),
  'stop': LevelScale(9), // 32 de încercări, 30% opriri, fereastra de 0,9 s la 9 // bula de 0,07 la 9 (distanța se oprește la 9)
  'puzzle': LevelScale(11), // 4 × 4 fără model la 11
  'labirint': LevelScale(9), // 10 × 6 la 9
  // atenție comună, imitație, ritm
  'unde-se-uita': LevelScale(6),
  'fa-ca-licuriciul': LevelScale(8),
  'toba-magica': LevelScale(9),
  'urmareste-pestele': LevelScale(14),
  // funcții executive
  'regula-se-schimba': LevelScale(7),
  'semaforul': LevelScale(10),
  'floarea-creste': LevelScale(10),
  'pe-rand': LevelScale(12),
  // limbaj
  'asculta-si-fa': LevelScale(11),
  // motricitate și scris
  'traseaza': LevelScale(10),
  'uneste-punctele': LevelScale(10),
  'hraneste-pestii': LevelScale(12), // viteza crește până la 12
  'atinge-si-vezi': LevelScale(6),
  'scriem-cifrele': LevelScale(10),
  'scriem-literele': LevelScale(10),
  // ordonare (rutine, povești, seriere, propoziții): 5 pași la nivelul 7
  'pasii-rutinei': LevelScale(7),
  'ce-urmeaza': LevelScale(7),
  'mare-mic': LevelScale(7),
  'orarul-meu': LevelScale(7),
  'spune-propozitia': LevelScale(7),
  // explorările: opririle sunt sortări cu nivel prestabilit (scara „Sortăm”)
  'explorare-stiinte': LevelScale(10),
  'explorare-istorie': LevelScale(10),
  'explorare-viata': LevelScale(10),
};

/// Jocurile fără niveluri de dificultate (nu produc încercări notate cu nivel).
const unleveledGames = {'respira', 'colorare', 'vorbeste'};

/// Scara jocului [gameId]; jocurile cu alegere (și orice joc nedeclarat) folosesc [choiceScale].
LevelScale scaleFor(String gameId) => gameScales[gameId] ?? choiceScale;
