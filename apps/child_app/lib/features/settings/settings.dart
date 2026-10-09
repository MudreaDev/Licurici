import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

/// Profilul local al copilului (setări senzoriale + clasa). Se păstrează în Drift (ADR-004),
/// prin `main()`; în teste rămâne în memorie.
class AppSettings {
  const AppSettings({
    this.grade = Grade.clasa1,
    this.level = FreePlayLevel.usor,
    this.calm = false,
    this.contrast = false,
    this.voice = true,
    this.stickers = const [],
    this.stickersSeen = 0,
    this.stars = startStars,
    this.hiddenGames = const {},
    this.lanternsSeen = 0,
    this.hiddenGamesAt,
    this.levels = const {},
    this.maxLevels = const {},
    this.rounds = const {},
    this.avoid = const {},
  });

  final Grade grade;
  final FreePlayLevel level;

  /// Modul calm: fără animații ambientale și particule, paletă mai palidă.
  final bool calm;

  /// Contrast mare (vedere slabă): contur închis pe tot ce se apasă și text mai închis.
  /// Pornește și singur când sistemul cere contrast mare (setările de accesibilitate).
  final bool contrast;
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

  /// Jocurile pe care adultul le-a scos din lista copilului („Jocurile copilului”, plan
  /// §5.1). Copilul vede doar restul; un joc nou apare de la sine.
  final Set<String> hiddenGames;

  /// Când s-a schimbat ultima dată lista de jocuri (pe tabletă sau venită de pe server):
  /// la sincronizare câștigă alegerea mai nouă (ADR-011, „ultimul câștigă”).
  final DateTime? hiddenGamesAt;

  /// Nivelul la care a ajuns copilul în fiecare joc (adaptiv): data viitoare pornește de acolo,
  /// nu de la 1. Doar pe tabletă.
  final Map<String, int> levels;

  /// Plafonul de dificultate ales de specialist pe joc (ADR-025): nivelul nu urcă peste el.
  final Map<String, int> maxLevels;

  /// Câte runde are o tură, ales de specialist pe joc (jocurile cu alegere).
  final Map<String, int> rounds;

  /// Categoriile de imagini pe care copilul nu trebuie să le vadă (`avoidItems`): jocurile
  /// sar peste rundele care le-ar arăta.
  final Set<String> avoid;

  /// Nivelul cu care pornește jocul [gameId], ținând cont de plafon. Prima dată: [fallback] sau,
  /// dacă e mai mare, nivelul transferat de la un joc de pe aceeași treaptă (`transferredLevel`).
  int levelOf(String gameId, [int fallback = 1]) {
    final first = transferredLevel(gameId, levels);
    final start = levels[gameId] ?? (first != null && first > fallback ? first : fallback);
    return capLevel(start, maxLevels[gameId]);
  }

  /// Câte felinare aprinse a văzut copilul pe hartă (pentru sărbătoarea unui felinar nou).
  final int lanternsSeen;

  /// Jocurile pe care le vede copilul.
  Set<String> get visibleGames => {for (final e in catalog) if (!hiddenGames.contains(e.id)) e.id};

  Map<String, Object> toJson() => {
    'grade': grade.name,
    'level': level.name,
    'calm': calm,
    if (contrast) 'contrast': true,
    'voice': voice,
    'stickers': stickers,
    'stickersSeen': stickersSeen,
    'stars': stars,
    'hiddenGames': hiddenGames.toList()..sort(),
    'lanternsSeen': lanternsSeen,
    if (hiddenGamesAt != null) 'hiddenGamesAt': hiddenGamesAt!.toIso8601String(),
    if (levels.isNotEmpty) 'levels': levels,
    if (maxLevels.isNotEmpty) 'maxLevels': maxLevels,
    if (rounds.isNotEmpty) 'rounds': rounds,
    if (avoid.isNotEmpty) 'avoid': avoid.toList()..sort(),
  };

  /// Valorile necunoscute (ex. după o actualizare) revin la implicit, fără să blocheze pornirea.
  factory AppSettings.fromJson(Map<String, Object?> j) => AppSettings(
    grade: Grade.values.asNameMap()[j['grade']] ?? Grade.clasa1,
    level: FreePlayLevel.values.asNameMap()[j['level']] ?? FreePlayLevel.usor,
    calm: j['calm'] == true,
    contrast: j['contrast'] == true,
    voice: j['voice'] != false,
    stickers: [
      for (final s in (j['stickers'] as List? ?? const []))
        if (s is String) s,
    ],
    stickersSeen: (j['stickersSeen'] as num?)?.toInt() ?? 0,
    stars: (j['stars'] as num?)?.toInt() ?? startStars,
    hiddenGames: {
      for (final g in (j['hiddenGames'] as List? ?? const []))
        if (g is String) g,
    },
    lanternsSeen: (j['lanternsSeen'] as num?)?.toInt() ?? 0,
    hiddenGamesAt: DateTime.tryParse(j['hiddenGamesAt'] as String? ?? ''),
    levels: {
      for (final MapEntry(:key, :value) in ((j['levels'] as Map?) ?? const {}).entries)
        if (key is String && value is num && value >= 1) key: value.toInt(),
    },
    maxLevels: {
      for (final MapEntry(:key, :value) in ((j['maxLevels'] as Map?) ?? const {}).entries)
        if (key is String && value is num && value >= 1) key: value.toInt(),
    },
    rounds: {
      for (final MapEntry(:key, :value) in ((j['rounds'] as Map?) ?? const {}).entries)
        if (key is String && value is num && value >= 1) key: value.toInt(),
    },
    avoid: {
      for (final a in (j['avoid'] as List? ?? const []))
        if (a is String) a,
    },
  );

  AppSettings copyWith({
    Grade? grade,
    FreePlayLevel? level,
    bool? calm,
    bool? contrast,
    bool? voice,
    List<String>? stickers,
    int? stickersSeen,
    int? stars,
    Set<String>? hiddenGames,
    int? lanternsSeen,
    DateTime? hiddenGamesAt,
    Map<String, int>? levels,
    Map<String, int>? maxLevels,
    Map<String, int>? rounds,
    Set<String>? avoid,
  }) => AppSettings(
    grade: grade ?? this.grade,
    level: level ?? this.level,
    calm: calm ?? this.calm,
    contrast: contrast ?? this.contrast,
    voice: voice ?? this.voice,
    stickers: stickers ?? this.stickers,
    stickersSeen: stickersSeen ?? this.stickersSeen,
    stars: stars ?? this.stars,
    hiddenGames: hiddenGames ?? this.hiddenGames,
    lanternsSeen: lanternsSeen ?? this.lanternsSeen,
    hiddenGamesAt: hiddenGamesAt ?? this.hiddenGamesAt,
    levels: levels ?? this.levels,
    maxLevels: maxLevels ?? this.maxLevels,
    rounds: rounds ?? this.rounds,
    avoid: avoid ?? this.avoid,
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

  /// Clasa și nivelul de pornire schimbate de părinte: jocurile cu alegere pornesc iar de
  /// acolo (treptele lor adaptive salvate se uită).
  Map<String, int> get _withoutChoiceLevels {
    final choice = {for (final g in allGames) g.id};
    return {for (final e in state.levels.entries) if (!choice.contains(e.key)) e.key: e.value};
  }

  void setGrade(Grade grade) => _set(state.copyWith(grade: grade, levels: _withoutChoiceLevels));
  void setLevel(FreePlayLevel level) => _set(state.copyWith(level: level, levels: _withoutChoiceLevels));
  void toggleCalm() => _set(state.copyWith(calm: !state.calm));

  void setContrast(bool on) => _set(state.copyWith(contrast: on));

  /// Adultul alege de pe tabletă ce imagini să nu vadă copilul (contează ca schimbare de plan).
  void setAvoid(String id, bool on) {
    final next = {...state.avoid};
    on ? next.add(id) : next.remove(id);
    _set(state.copyWith(avoid: next, hiddenGamesAt: DateTime.now().toUtc()));
  }
  void toggleVoice() => _set(state.copyWith(voice: !state.voice));

  /// Un joc terminat = un abțibild. Întâi cele lipsă din album, în ordine; după ce albumul e
  /// plin, se adună dubluri (albumul arată câte are din fiecare).
  /// Albumul a fost deschis: toate abțibildurile sunt văzute.
  void markStickersSeen() {
    if (state.hasNewStickers) {
      _set(state.copyWith(stickersSeen: state.stickers.length));
    }
  }

  /// Ștergerea datelor de pe tabletă: setările, abțibildurile și stelele revin la început.
  void reset() => _set(const AppSettings());

  /// Arată sau ascunde jocurile [ids] în lista copilului (cel puțin un joc rămâne vizibil).
  void setGamesVisible(Iterable<String> ids, bool visible) {
    final next = {...state.hiddenGames};
    visible ? next.removeAll(ids) : next.addAll(ids);
    if (next.length >= catalog.length) return;
    _set(state.copyWith(hiddenGames: next, hiddenGamesAt: DateTime.now().toUtc()));
  }

  /// Planul venit de pe server (ales de părinte în panou sau de specialist): jocurile scoase
  /// și, pentru unele jocuri, nivelul de pornire și plafonul alese de specialist. Plafonul
  /// venit de pe server înlocuiește tot; nivelurile de acum se coboară sub el, dacă e nevoie.
  void applyPlan(
    Set<String> hidden,
    Map<String, int> levels,
    DateTime at, [
    Map<String, int>? maxLevels,
    Map<String, int>? rounds,
    Set<String>? avoid,
  ]) {
    final known = {for (final e in catalog) e.id};
    final next = hidden.where(known.contains).toSet();
    if (next.length >= catalog.length) return;
    final caps = maxLevels ?? state.maxLevels;
    final merged = {...state.levels, ...levels};
    _set(
      state.copyWith(
        hiddenGames: next,
        hiddenGamesAt: at,
        maxLevels: caps,
        rounds: rounds ?? state.rounds,
        avoid: avoid ?? state.avoid,
        levels: {for (final MapEntry(:key, :value) in merged.entries) key: capLevel(value, caps[key])},
      ),
    );
  }

  /// Nivelul la care a ajuns copilul în jocul [gameId].
  void setGameLevel(String gameId, int level) {
    final capped = capLevel(level, state.maxLevels[gameId]);
    if (state.levels[gameId] == capped) return;
    _set(state.copyWith(levels: {...state.levels, gameId: capped}));
  }

  void setLanternsSeen(int n) => _set(state.copyWith(lanternsSeen: n));

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

/// Nivelul unui joc, păstrat pe tabletă (pornește de unde a rămas copilul data trecută).
class GameLevel extends Notifier<int> {
  GameLevel(this.gameId);

  final String gameId;

  @override
  int build() => ref.read(settingsProvider).levelOf(gameId);

  void setLevel(int level) {
    state = capLevel(level, ref.read(settingsProvider).maxLevels[gameId]);
    ref.read(settingsProvider.notifier).setGameLevel(gameId, state);
  }

  void advance() => setLevel(state + 1);
}
