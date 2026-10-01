/// Registrul jocurilor (port din `registry.js`): adăugarea unui joc = o intrare aici.
/// Jocurile stau câte un fișier pe materie; testele verifică automat fiecare joc din listă.
library;

import '../game.dart';
import '../grades.dart';
import 'emotii.dart';
import 'forme.dart';
import 'matematica.dart';
import 'romana.dart';
import 'social.dart';

export 'emotii.dart';
export 'forme.dart';
export 'matematica.dart';
export 'romana.dart';
export 'social.dart';

const List<GameSpec> allGames = [
  // Limba română
  AlfabetulGame(),
  OpuseGame(),
  OrtografieGame(),
  PovestiGame(),
  // Matematică
  NumaramGame(),
  ComparamGame(),
  AdunamGame(),
  ScademGame(),
  // Forme & logică
  CuloriGame(),
  FormeGame(),
  // Emoții & viață
  EmotiiGame(),
  DaNuGame(),
  CeSimteGame(),
  CeMaAjutaGame(),
  CineStieGame(),
  SituatiiGame(),
];

GameSpec? gameById(String id) {
  for (final g in allGames) {
    if (g.id == id) return g;
  }
  return null;
}

/// Jocurile pentru o clasă, grupate pe materii (în ordinea din [Subject]).
Map<Subject, List<GameSpec>> gamesForGrade(Grade grade) => {
      for (final s in Subject.values)
        if (allGames.any((g) => g.subject == s && g.grades.contains(grade)))
          s: allGames.where((g) => g.subject == s && g.grades.contains(grade)).toList(),
    };
