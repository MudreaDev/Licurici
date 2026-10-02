/// Respiră (FEX6, catalog #43): respirație ghidată, joc liber — fără scor, fără greșeli.
/// Se înregistrează doar folosirea (`SessionEventKind.breathing`): KPI-ul e folosirea spontană.
library;

import 'grades.dart';

/// Un ciclu de respirație: inspir → ține → expir (secunde).
class BreathPattern {
  const BreathPattern({this.inhale = 4, this.hold = 2, this.exhale = 4, this.cycles = 3});

  final int inhale;
  final int hold;
  final int exhale;
  final int cycles;

  int get cycleSeconds => inhale + hold + exhale;
}

class BreathingGame {
  const BreathingGame();

  String get id => 'respira';
  String get name => 'Respiră';
  String get emoji => '🌸';
  String get description => 'Un moment de liniște';
  Set<Grade> get grades => Grade.parseCodes('G1234');
  List<String> get steps => const ['FEX6'];

  /// Ritmul implicit (4-2-4, ca în prototip); mai târziu, din planul specialistului.
  BreathPattern get pattern => const BreathPattern();
}
