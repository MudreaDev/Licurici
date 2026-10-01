import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

/// Profilul local al copilului (setări senzoriale + clasa). Se păstrează în Drift (ADR-004),
/// prin `main()`; în teste rămâne în memorie.
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

  Map<String, Object> toJson() => {
    'grade': grade.name,
    'level': level.name,
    'calm': calm,
    'voice': voice,
  };

  /// Valorile necunoscute (ex. după o actualizare) revin la implicit, fără să blocheze pornirea.
  factory AppSettings.fromJson(Map<String, Object?> j) => AppSettings(
    grade: Grade.values.asNameMap()[j['grade']] ?? Grade.clasa1,
    level: FreePlayLevel.values.asNameMap()[j['level']] ?? FreePlayLevel.usor,
    calm: j['calm'] == true,
    voice: j['voice'] != false,
  );

  AppSettings copyWith({
    Grade? grade,
    FreePlayLevel? level,
    bool? calm,
    bool? voice,
  }) => AppSettings(
    grade: grade ?? this.grade,
    level: level ?? this.level,
    calm: calm ?? this.calm,
    voice: voice ?? this.voice,
  );
}

class SettingsNotifier extends Notifier<AppSettings> {
  SettingsNotifier([this._initial = const AppSettings(), this._persist]);

  final AppSettings _initial;
  final void Function(AppSettings)? _persist;

  @override
  AppSettings build() => _initial;

  void _set(AppSettings s) {
    state = s;
    _persist?.call(s);
  }

  void setGrade(Grade grade) => _set(state.copyWith(grade: grade));
  void setLevel(FreePlayLevel level) => _set(state.copyWith(level: level));
  void toggleCalm() => _set(state.copyWith(calm: !state.calm));
  void toggleVoice() => _set(state.copyWith(voice: !state.voice));
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
