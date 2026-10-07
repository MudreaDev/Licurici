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
    this.stickers = const [],
    this.stickersSeen = 0,
    this.stars = startStars,
  });

  final Grade grade;
  final FreePlayLevel level;

  /// Modul calm: fără animații ambientale și particule, paletă mai palidă.
  final bool calm;
  final bool voice;

  /// Abțibildurile câștigate, în ordine (id-urile din `stickerIds`). Rămân doar pe
  /// dispozitiv: sunt recompensa copilului, nu o măsurătoare (README §11).
  final List<String> stickers;

  /// Câte abțibilduri a văzut deja în album (restul sunt „noi” — semn pe butonul albumului).
  final int stickersSeen;

  bool get hasNewStickers => stickers.length > stickersSeen;

  /// Stelele din „pușculiță”: se adună la finalul jocurilor (exact cele arătate copilului)
  /// și se dau pe mâncare în acvariu. Ca abțibildurile, rămân doar pe dispozitiv.
  final int stars;

  /// Cu câte stele pornește copilul, ca să poată hrăni peștii de la prima vizită.
  static const startStars = 3;

  Map<String, Object> toJson() => {
    'grade': grade.name,
    'level': level.name,
    'calm': calm,
    'voice': voice,
    'stickers': stickers,
    'stickersSeen': stickersSeen,
    'stars': stars,
  };

  /// Valorile necunoscute (ex. după o actualizare) revin la implicit, fără să blocheze pornirea.
  factory AppSettings.fromJson(Map<String, Object?> j) => AppSettings(
    grade: Grade.values.asNameMap()[j['grade']] ?? Grade.clasa1,
    level: FreePlayLevel.values.asNameMap()[j['level']] ?? FreePlayLevel.usor,
    calm: j['calm'] == true,
    voice: j['voice'] != false,
    stickers: [
      for (final s in (j['stickers'] as List? ?? const []))
        if (s is String) s,
    ],
    stickersSeen: (j['stickersSeen'] as num?)?.toInt() ?? 0,
    stars: (j['stars'] as num?)?.toInt() ?? startStars,
  );

  AppSettings copyWith({
    Grade? grade,
    FreePlayLevel? level,
    bool? calm,
    bool? voice,
    List<String>? stickers,
    int? stickersSeen,
    int? stars,
  }) => AppSettings(
    grade: grade ?? this.grade,
    level: level ?? this.level,
    calm: calm ?? this.calm,
    voice: voice ?? this.voice,
    stickers: stickers ?? this.stickers,
    stickersSeen: stickersSeen ?? this.stickersSeen,
    stars: stars ?? this.stars,
  );
}

/// Abțibildurile din album (ilustrațiile `rewards/sticker_<id>`).
const stickerIds = [
  'bunny',
  'turtle',
  'owl',
  'fox',
  'bear',
  'elephant',
  'hedgehog',
  'duck',
  'cat',
  'frog',
  'snail',
  'whale',
];

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

  /// Un joc terminat = un abțibild. Întâi cele lipsă din album, în ordine; după ce albumul e
  /// plin, se adună dubluri (albumul arată câte are din fiecare).
  /// Albumul a fost deschis: toate abțibildurile sunt văzute.
  void markStickersSeen() {
    if (state.hasNewStickers) {
      _set(state.copyWith(stickersSeen: state.stickers.length));
    }
  }

  void addStars(int n) => _set(state.copyWith(stars: state.stars + n));

  /// Plătește [n] stele, dacă are destule.
  bool spendStars(int n) {
    if (state.stars < n) return false;
    _set(state.copyWith(stars: state.stars - n));
    return true;
  }

  String awardSticker() {
    final id = stickerIds[state.stickers.length % stickerIds.length];
    _set(state.copyWith(stickers: [...state.stickers, id]));
    return id;
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
