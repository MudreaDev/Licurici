/// Băncile de conținut (port din `legacy/electron/src/data/content.js`).
/// Pasul următor (README §3): mutare în JSON versionat în `packages/game_content`.
library;

const countItems = [
  '🍎', '⭐', '🎈', '🐶', '🌸', '🚗', '🍓', '🐟', '🦋', '🧸', '🌟', '🍒', '🍏', '🐥', '🌷', '🎁',
];

const mathItems = ['🍎', '⭐', '🎈', '🍓', '🐥', '🌸', '🚗', '🍒', '🐟', '🧸'];

class NamedColor {
  const NamedColor(this.name, this.argb);
  final String name;
  final int argb;
}

const colors = [
  NamedColor('roșu', 0xFFE06B6B),
  NamedColor('albastru', 0xFF5B9BB5),
  NamedColor('verde', 0xFF6BBF8A),
  NamedColor('galben', 0xFFF2CF6B),
  NamedColor('portocaliu', 0xFFE6A86A),
  NamedColor('mov', 0xFFA9A3D1),
  NamedColor('roz', 0xFFF0A9C0),
  NamedColor('maro', 0xFFA9805F),
  NamedColor('gri', 0xFF9AA7A7),
  NamedColor('negru', 0xFF3B3B3B),
];

class Emotion {
  const Emotion(this.key, this.emoji, this.label, this.contexts, {this.similar = const []});
  final String key;
  final String emoji;
  final String label;
  final List<String> contexts;

  /// Emoții ușor de confundat cu aceasta (ex. fericit / mândru la „a câștigat un joc”).
  /// Nu apar niciodată ca variantă greșită pentru ea — altfel copilul ar avea două răspunsuri bune.
  final List<String> similar;
}

const emotions = [
  Emotion('fericit', '😊', 'Fericit',
      ['a primit un cadou', 'se joacă cu prietenii', 'mănâncă înghețata preferată', 'a câștigat un joc'],
      similar: ['mandru', 'calm']),
  Emotion('trist', '😢', 'Trist',
      ['i s-a stricat jucăria', 'prietenul a plecat acasă', 'a pierdut balonul', 's-a lovit la genunchi']),
  Emotion('suparat', '😠', 'Supărat',
      ['cineva i-a luat jucăria', 'nu a primit ce voia', 'a fost întrerupt din joc']),
  Emotion('speriat', '😨', 'Speriat',
      ['a auzit un tunet puternic', 'a văzut un câine mare', 'era întuneric în cameră'],
      similar: ['surprins']),
  Emotion('surprins', '😲', 'Surprins',
      ['a primit o surpriză', 'a văzut un balon spărgându-se', 'cineva a strigat „Surpriză!"'],
      similar: ['speriat']),
  Emotion('obosit', '😴', 'Obosit', ['s-a jucat toată ziua', 'este seară târziu', 'a alergat mult'],
      similar: ['calm']),
  Emotion('calm', '😌', 'Calm', ['ascultă muzică liniștită', 'respiră adânc', 'stă lângă mama'],
      similar: ['fericit', 'obosit']),
  Emotion('mandru', '😄', 'Mândru',
      ['a terminat un desen frumos', 'a ajutat un prieten', 'a învățat ceva nou'],
      similar: ['fericit']),
];
