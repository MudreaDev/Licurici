/// Registrul jocurilor (port din `registry.js`): adăugarea unui joc = o intrare aici.
/// Jocurile stau câte un fișier pe materie; testele verifică automat fiecare joc din listă.
library;

import '../game.dart';
import '../grades.dart';
import 'calendar.dart';
import 'emotii.dart';
import 'faces.dart';
import 'hidden_shape.dart';
import 'forme.dart';
import 'logica.dart';
import 'matematica.dart';
import 'romana.dart';
import 'scoala.dart';
import 'scoala2.dart';
import 'listening.dart';
import 'siblings.dart';
import 'subitizing.dart';
import 'social.dart';
import 'vocabular.dart';

export 'calendar.dart';
export 'emotii.dart';
export 'faces.dart';
export 'hidden_shape.dart';
export 'forme.dart';
export 'logica.dart';
export 'matematica.dart';
export 'romana.dart';
export 'scoala.dart';
export 'scoala2.dart';
export 'listening.dart';
export 'siblings.dart';
export 'subitizing.dart';
export 'social.dart';
export 'vocabular.dart';

const List<GameSpec> allGames = [
  // Jocurile „frate” (generalizare: același obiectiv, alt material)
  CumSeSimteGame(),
  AjutaLicuriciGame(),
  // Fețe desenate din cod, cu metrici standard (pragul emoției, recunoașterea feței)
  CatDeTareGame(),
  CineEPrietenulGame(),
  CateSuntGame(),
  CeAiAuzitGame(),
  // Potrivire și limbaj receptiv
  PotrivesteGame(),
  ArataMiGame(),
  CorpulGame(),
  CeFaceGame(),
  AtributeGame(),
  UndeEUrsulGame(),
  PozitiiGame(),
  FormaAscunsaGame(),
  PrimulSunetGame(),
  IntrusulGame(),
  UmbreGame(),
  // Limba română
  AlfabetulGame(),
  OpuseGame(),
  OrtografieGame(),
  PovestiGame(),
  SilabeGame(),
  CuvinteGame(),
  PluralGame(),
  GramaticaGame(),
  // Matematică
  NumaramGame(),
  ComparamGame(),
  AdunamGame(),
  ScademGame(),
  SemneGame(),
  LipsaGame(),
  ZeciGame(),
  InmultimGame(),
  ImpartimGame(),
  CeasulGame(),
  BaniGame(),
  CalendarGame(),
  TablaGame(),
  ProblemeGame(),
  // Forme & logică
  CuloriGame(),
  FormeGame(),
  SirulGame(),
  PesteInMijlocGame(),
  // Emoții & viață
  EmotiiGame(),
  DaNuGame(),
  AnotimpuriGame(),
  HabitateGame(),
  TrecutGame(),
  SimboluriGame(),
  PersonalitatiGame(),
  CeSeAudeGame(),
  CeImbracGame(),
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
