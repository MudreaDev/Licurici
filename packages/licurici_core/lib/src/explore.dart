/// Explorări (port din `legacy/electron/src/games/explorare_*.js`): un episod e o hartă cu
/// 3–4 opriri; la fiecare, Licurici spune o mică poveste, apoi copilul sortează (mecanica
/// `dragDrop` din „Sortăm”). Episodul se termină când toate opririle sunt făcute.
library;

import 'dart:math';

import 'grades.dart';
import 'sorting.dart';

/// O oprire pe hartă: povestea și sortarea ei.
class ExploreStop {
  const ExploreStop({
    required this.id,
    required this.name,
    required this.emoji,
    required this.intro,
    required this.instruction,
    required this.bins,
    required this.items,
    required this.x,
    required this.y,
  });

  final String id;
  final String name;
  final String emoji;

  /// Ce spune Licurici când copilul ajunge la oprire.
  final String intro;
  final String instruction;

  /// Grupele (doar id, nume, iconiță — lucrurile sunt în [items]).
  final List<SortBin> bins;

  /// Lucrurile de sortat: (imagine, id-ul grupei).
  final List<(String, String)> items;

  /// Poziția pe hartă, 0…1 (stânga-sus = 0,0).
  final double x, y;
}

class ExploreEpisode {
  const ExploreEpisode({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.outro,
    required this.stops,
    this.gradeCodes = 'G1234',
  });

  final String id;
  final String name;
  final String emoji;
  final String description;

  /// Ce spune Licurici la final.
  final String outro;
  final List<ExploreStop> stops;
  final String gradeCodes;

  Set<Grade> get grades => Grade.parseCodes(gradeCodes);

  /// Sortarea opririi [stop], cu lucrurile amestecate din [seed].
  SortLevel levelFor(ExploreStop stop, {int? seed}) {
    final s = seed ?? Random().nextInt(1 << 31);
    final items = [...stop.items]..shuffle(Random(s));
    return SortLevel(
      gameId: id,
      level: 1,
      seed: s,
      axes: SortAxes(bins: stop.bins.length, perBin: (items.length / stop.bins.length).ceil()),
      bins: stop.bins,
      items: [for (final (i, (emoji, bin)) in items.indexed) SortItem(i, emoji, bin)],
      instruction: stop.instruction,
    );
  }

  Set<String> get art => {
        emoji,
        for (final s in stops) ...{s.emoji, ...s.bins.map((b) => b.emoji), ...s.items.map((i) => i.$1)},
      };
}

const exploreEpisodes = [
  ExploreEpisode(
    id: 'explorare-stiinte',
    name: 'Autobuzul lui Licurici',
    emoji: '🚌',
    description: 'O călătorie prin natură',
    outro: 'Ai explorat toată natura! Bravo!',
    stops: [
      ExploreStop(
        id: 'habitate',
        name: 'Casele animalelor',
        emoji: '🐾',
        intro: 'Fiecare animal are casa lui. Hai să le ducem acasă!',
        instruction: 'Trage fiecare animal la casa lui.',
        x: 0.16,
        y: 0.72,
        bins: [SortBin('ferma', 'Fermă', '🚜', []), SortBin('padure', 'Pădure', '🌲', []), SortBin('ocean', 'Ocean', '🌊', [])],
        items: [('🐄', 'ferma'), ('🐔', 'ferma'), ('🦊', 'padure'), ('🐻', 'padure'), ('🐠', 'ocean'), ('🐙', 'ocean')],
      ),
      ExploreStop(
        id: 'anotimpuri',
        name: 'Anotimpurile',
        emoji: '🍂',
        intro: 'Fiecare lucru vine cu anotimpul lui. Unde se potrivește?',
        instruction: 'Trage fiecare lucru la anotimpul lui.',
        x: 0.39,
        y: 0.42,
        bins: [
          SortBin('primavara', 'Primăvara', '🌷', []),
          SortBin('vara', 'Vara', '☀️', []),
          SortBin('toamna', 'Toamna', '🍂', []),
          SortBin('iarna', 'Iarna', '❄️', []),
        ],
        items: [
          ('🐣', 'primavara'), ('🌱', 'primavara'), ('🍉', 'vara'), ('🏖️', 'vara'), //
          ('🌰', 'toamna'), ('☔', 'toamna'), ('⛄', 'iarna'), ('🧣', 'iarna'),
        ],
      ),
      ExploreStop(
        id: 'hrana',
        name: 'Ce mănâncă?',
        emoji: '🥕',
        intro: 'Iepurele mănâncă plante, leul mănâncă carne. Dă-le de mâncare!',
        instruction: 'Trage hrana la animalul potrivit.',
        x: 0.62,
        y: 0.66,
        bins: [SortBin('iepure', 'Iepure', '🐰', []), SortBin('leu', 'Leu', '🦁', [])],
        items: [('🥕', 'iepure'), ('🥬', 'iepure'), ('🌿', 'iepure'), ('🍖', 'leu'), ('🍗', 'leu'), ('🐟', 'leu')],
      ),
      ExploreStop(
        id: 'reciclare',
        name: 'Sortăm gunoiul',
        emoji: '♻️',
        intro: 'Hai să păstrăm parcul curat! Fiecare gunoi are coșul lui.',
        instruction: 'Pune fiecare gunoi în coșul potrivit.',
        x: 0.85,
        y: 0.36,
        bins: [SortBin('hartie', 'Hârtie', '📄', []), SortBin('plastic', 'Plastic', '🥤', []), SortBin('resturi', 'Resturi', '🍂', [])],
        items: [('📰', 'hartie'), ('📦', 'hartie'), ('🍾', 'plastic'), ('🧴', 'plastic'), ('🍌', 'resturi'), ('🍎', 'resturi')],
      ),
    ],
  ),
  ExploreEpisode(
    id: 'explorare-istorie',
    name: 'Călătorie în timp',
    emoji: '🏰',
    description: 'Cum se trăia demult',
    outro: 'Ai călătorit prin timp! Bravo!',
    gradeCodes: '1234',
    stops: [
      ExploreStop(
        id: 'acasa',
        name: 'Acasă demult',
        emoji: '🕯️',
        intro: 'Bunicii bunicilor trăiau altfel. Ce e de demult și ce e de acum?',
        instruction: 'Trage fiecare lucru: de demult sau de acum.',
        x: 0.18,
        y: 0.68,
        bins: [SortBin('trecut', 'Demult', '⏳', []), SortBin('prezent', 'Acum', '💡', [])],
        items: [('🕯️', 'trecut'), ('🐎', 'trecut'), ('🪶', 'trecut'), ('🚗', 'prezent'), ('🖊️', 'prezent'), ('📱', 'prezent')],
      ),
      ExploreStop(
        id: 'simboluri',
        name: 'Simbolurile țării',
        emoji: '🏰',
        intro: 'Țara are simbolurile ei. Care e simbol și care e un lucru obișnuit?',
        instruction: 'Trage simbolurile țării separat de lucrurile obișnuite.',
        x: 0.5,
        y: 0.4,
        bins: [SortBin('simbol', 'Simbol al țării', '🏛️', []), SortBin('obiect', 'Lucru obișnuit', '🧸', [])],
        items: [('🇷🇴', 'simbol'), ('👑', 'simbol'), ('🏰', 'simbol'), ('🍎', 'obiect'), ('⚽', 'obiect'), ('🎈', 'obiect')],
      ),
      ExploreStop(
        id: 'vesti',
        name: 'Cum trimiteau vești',
        emoji: '✉️',
        intro: 'Demult, veștile mergeau încet. Ce folosim acum?',
        instruction: 'Trage fiecare lucru: de demult sau de acum.',
        x: 0.82,
        y: 0.6,
        bins: [SortBin('trecut', 'Demult', '⏳', []), SortBin('prezent', 'Acum', '📱', [])],
        items: [('📜', 'trecut'), ('✉️', 'trecut'), ('📻', 'trecut'), ('📧', 'prezent'), ('📱', 'prezent'), ('📺', 'prezent')],
      ),
    ],
  ),
  ExploreEpisode(
    id: 'explorare-viata',
    name: 'O zi bună',
    emoji: '🌟',
    description: 'Emoții, mâncare sănătoasă, siguranță',
    outro: 'Ai avut o zi bună! Bravo!',
    stops: [
      ExploreStop(
        id: 'emotii',
        name: 'Cum mă simt',
        emoji: '😊',
        intro: 'Toți avem emoții. Hai să potrivim fața cu ce simte.',
        instruction: 'Trage fiecare față la emoția potrivită.',
        x: 0.17,
        y: 0.66,
        bins: [
          SortBin('bucuros', 'Bucuros', '😀', []),
          SortBin('trist', 'Trist', '😢', []),
          SortBin('suparat', 'Supărat', '😠', []),
          SortBin('speriat', 'Speriat', '😨', []),
        ],
        items: [
          ('😄', 'bucuros'), ('🙂', 'bucuros'), ('😢', 'trist'), ('😭', 'trist'), //
          ('😠', 'suparat'), ('😡', 'suparat'), ('😨', 'speriat'), ('😰', 'speriat'),
        ],
      ),
      ExploreStop(
        id: 'mancare',
        name: 'Mâncare sănătoasă',
        emoji: '🥗',
        intro: 'Ce mâncăm des și ce doar câteodată?',
        instruction: 'Trage mâncarea: sănătoasă sau doar câteodată.',
        x: 0.5,
        y: 0.4,
        bins: [SortBin('sanatos', 'Sănătos', '🥗', []), SortBin('rar', 'Doar câteodată', '🍰', [])],
        items: [('🍎', 'sanatos'), ('🥕', 'sanatos'), ('🍌', 'sanatos'), ('🍭', 'rar'), ('🥤', 'rar'), ('🍟', 'rar')],
      ),
      ExploreStop(
        id: 'siguranta',
        name: 'În siguranță',
        emoji: '✅',
        intro: 'Unele lucruri cer grijă. Ce e sigur și ce atingem doar cu un adult?',
        instruction: 'Trage fiecare lucru: sigur sau doar cu un adult.',
        x: 0.83,
        y: 0.6,
        bins: [SortBin('sigur', 'Sigur', '✅', []), SortBin('grija', 'Doar cu un adult', '⚠️', [])],
        items: [('🪥', 'sigur'), ('🧼', 'sigur'), ('🚦', 'sigur'), ('🔥', 'grija'), ('🔪', 'grija'), ('🔌', 'grija')],
      ),
    ],
  ),
];

ExploreEpisode? exploreEpisodeById(String id) {
  for (final e in exploreEpisodes) {
    if (e.id == id) return e;
  }
  return null;
}
