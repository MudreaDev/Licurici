import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

/// Profilul local al copilului (setări senzoriale + clasa).
/// În Sprint 2 se persistă în Drift/SQLite (ADR-04); acum trăiește în memorie.
class AppSettings {
  const AppSettings({
    this.grade = Grade.clasa1,
    this.level = FreePlayLevel.usor,
    this.calm = false,
    this.voice = true,
  });

  final Grade grade;
  final FreePlayLevel level;

  /// Modul calm: fără animații ambientale și particule, paletă mai palidă.
  final bool calm;
  final bool voice;

  AppSettings copyWith({Grade? grade, FreePlayLevel? level, bool? calm, bool? voice}) =>
      AppSettings(
        grade: grade ?? this.grade,
        level: level ?? this.level,
        calm: calm ?? this.calm,
        voice: voice ?? this.voice,
      );
}

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => const AppSettings();

  void setGrade(Grade grade) => state = state.copyWith(grade: grade);
  void setLevel(FreePlayLevel level) => state = state.copyWith(level: level);
  void toggleCalm() => state = state.copyWith(calm: !state.calm);
  void toggleVoice() => state = state.copyWith(voice: !state.voice);
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
