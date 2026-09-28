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

class Word {
  const Word(this.word, this.emoji);
  final String word;
  final String emoji;
}

/// Literă + cuvânt-exemplu (unele litere au mai multe cuvinte).
class LetterWord {
  const LetterWord(this.letter, this.word, this.emoji);
  final String letter;
  final String word;
  final String emoji;
}

const alphabet = [
  LetterWord('A', 'albină', '🐝'), LetterWord('B', 'balon', '🎈'),
  LetterWord('C', 'casă', '🏠'), LetterWord('D', 'delfin', '🐬'),
  LetterWord('E', 'elefant', '🐘'), LetterWord('F', 'floare', '🌸'),
  LetterWord('G', 'girafă', '🦒'), LetterWord('I', 'inimă', '❤️'),
  LetterWord('J', 'jucărie', '🧸'), LetterWord('L', 'lună', '🌙'),
  LetterWord('M', 'măr', '🍎'), LetterWord('N', 'nor', '☁️'),
  LetterWord('O', 'ou', '🥚'), LetterWord('P', 'pește', '🐟'),
  LetterWord('R', 'rață', '🦆'), LetterWord('S', 'soare', '☀️'),
  LetterWord('T', 'tobă', '🥁'), LetterWord('U', 'urs', '🐻'),
  LetterWord('V', 'vulpe', '🦊'), LetterWord('Z', 'zebră', '🦓'),
  LetterWord('Ș', 'șarpe', '🐍'), LetterWord('B', 'banană', '🍌'),
  LetterWord('C', 'cireașă', '🍒'), LetterWord('P', 'pisică', '🐱'),
];

const shapes = [
  Word('cerc', '🔵'),
  Word('pătrat', '🟦'),
  Word('triunghi', '🔺'),
  Word('stea', '⭐'),
  Word('inimă', '❤️'),
  Word('romb', '🔷'),
];

class Opposite {
  const Opposite(this.a, this.b);
  final Word a;
  final Word b;
}

const opposites = [
  Opposite(Word('mare', '🐘'), Word('mic', '🐭')),
  Opposite(Word('sus', '⬆️'), Word('jos', '⬇️')),
  Opposite(Word('cald', '☀️'), Word('rece', '❄️')),
  Opposite(Word('zi', '🌞'), Word('noapte', '🌙')),
  Opposite(Word('vesel', '😄'), Word('trist', '😢')),
  Opposite(Word('rapid', '🐇'), Word('încet', '🐢')),
  Opposite(Word('deschis', '🔓'), Word('închis', '🔒')),
  Opposite(Word('curat', '🧼'), Word('murdar', '🧦')),
  Opposite(Word('lung', '🦒'), Word('scurt', '🐛')),
  Opposite(Word('greu', '🪨'), Word('ușor', '🪶')),
  Opposite(Word('uscat', '🏜️'), Word('ud', '💧')),
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

// ---------------------------------------------------------------- ortografie (clasele 2–4)

/// O ortogramă: două forme care se aud la fel, dar se scriu diferit (ex. `sau` / `s-au`).
/// Propozițiile au `___` în locul cuvântului lipsă.
class Ortograma {
  const Ortograma(this.a, this.ruleA, this.sentencesA, this.b, this.ruleB, this.sentencesB);
  final String a;
  final String ruleA;
  final List<String> sentencesA;
  final String b;
  final String ruleB;
  final List<String> sentencesB;
}

const ortograme = [
  Ortograma(
    'sau',
    '„sau” înseamnă „ori”.',
    ['Vrei lapte ___ ceai?', 'Mergem în parc ___ la bunica?'],
    's-au',
    '„s-au” vine de la „se” + „au”.',
    ['Copiii ___ jucat în curte.', 'Florile ___ deschis dimineața.'],
  ),
  Ortograma(
    'la',
    '„la” arată locul sau direcția.',
    ['Mâine merg ___ școală.', 'Pisica doarme ___ soare.'],
    'l-a',
    '„l-a” vine de la „îl” + „a”.',
    ['Mama ___ îmbrățișat pe Andrei.', 'Bunicul ___ ajutat pe vecin.'],
  ),
  Ortograma(
    'sa',
    '„sa” înseamnă „a lui” sau „a ei”.',
    ['Fetița se joacă cu păpușa ___.', 'Ionel o ajută pe sora ___.'],
    's-a',
    '„s-a” vine de la „se” + „a”.',
    ['Ursul ___ trezit primăvara.', 'Bebelușul ___ ridicat singur.'],
  ),
  Ortograma(
    'ia',
    '„ia” înseamnă că cineva ia ceva.',
    ['Maria ___ o carte de pe raft.', 'Tata ___ umbrela, că plouă.'],
    'i-a',
    '„i-a” vine de la „îi” + „a”.',
    ['Bunica ___ dat o prăjitură.', 'Învățătoarea ___ citit o poveste.'],
  ),
  Ortograma(
    'iau',
    '„iau” înseamnă „eu iau”.',
    ['Eu ___ ghiozdanul și plec.', 'Acum îmi ___ haina.'],
    'i-au',
    '„i-au” vine de la „îi” + „au”.',
    ['Colegii ___ făcut o felicitare.', 'Părinții ___ cumpărat o minge.'],
  ),
  Ortograma(
    'va',
    '„va” arată ce se întâmplă mai târziu.',
    ['Mâine ___ ploua.', 'Ana ___ cânta la serbare.'],
    'v-a',
    '„v-a” vine de la „vă” + „a”.',
    ['Doamna învățătoare ___ lăudat pe toți.', 'Cine ___ ajutat, copii?'],
  ),
  Ortograma(
    'mai',
    '„mai” înseamnă „încă”.',
    ['Pot să ___ citesc o poveste?', 'Afară ___ ninge puțin.'],
    'm-ai',
    '„m-ai” vine de la „mă” + „ai”.',
    ['Tu ___ ajutat mult azi.', 'De ce nu ___ strigat?'],
  ),
];

// ---------------------------------------------------------------- povești (domeniu public)

/// O variantă de răspuns dintr-o poveste: text + ilustrație opțională.
class StoryOption {
  const StoryOption(this.label, [this.emoji]);
  final String label;
  final String? emoji;
}

/// Un pas din poveste: ce se povestește, apoi o întrebare de înțelegere.
class StoryStep {
  const StoryStep(this.narration, this.question, this.answer, this.wrong);
  final String narration;
  final String question;
  final StoryOption answer;
  final List<StoryOption> wrong;
}

class Story {
  const Story(this.title, this.author, this.emoji, this.steps);
  final String title;
  final String author;
  final String emoji;
  final List<StoryStep> steps;
}

/// Povești românești din domeniul public, repovestite pe scurt (texte proprii, nu citate).
const stories = [
  Story('Punguța cu doi bani', 'Ion Creangă', '🐓', [
    StoryStep(
      'Un moș avea un cocoș, iar o babă avea o găină. Găina babei făcea ouă.',
      'Ce făcea găina babei?',
      StoryOption('ouă', '🥚'),
      [StoryOption('lapte', '🥛'), StoryOption('pâine', '🍞'), StoryOption('mere', '🍎'), StoryOption('flori', '🌸')],
    ),
    StoryStep(
      'Moșul l-a trimis pe cocoș să aducă și el ceva. Cocoșul a găsit în drum o punguță.',
      'Ce era în punguță?',
      StoryOption('doi bani', '🪙'),
      [
        StoryOption('două mere', '🍎'),
        StoryOption('două ouă', '🥚'),
        StoryOption('două flori', '🌸'),
        StoryOption('două bomboane', '🍭'),
      ],
    ),
    StoryStep(
      'Pe drum a trecut un boier. I-a luat cocoșului punguța și a plecat cu ea.',
      'Cine i-a luat punguța?',
      StoryOption('boierul', '🎩'),
      [
        StoryOption('vulpea', '🦊'),
        StoryOption('baba', '👵'),
        StoryOption('un câine', '🐶'),
        StoryOption('o pisică', '🐱'),
      ],
    ),
    StoryStep(
      'Cocoșul a mers după boier și îi cerea punguța înapoi. Supărat, boierul a poruncit să fie aruncat într-o fântână.',
      'Unde a fost aruncat cocoșul prima dată?',
      StoryOption('în fântână', '💧'),
      [
        StoryOption('în cuptor', '🔥'),
        StoryOption('în pădure', '🌲'),
        StoryOption('pe casă', '🏠'),
        StoryOption('în mare', '🌊'),
      ],
    ),
    StoryStep(
      'Dar cocoșul a înghițit toată apa din fântână și a ieșit afară.',
      'Ce a înghițit cocoșul din fântână?',
      StoryOption('apa', '💧'),
      [
        StoryOption('pietrele', '🪨'),
        StoryOption('peștii', '🐟'),
        StoryOption('frunzele', '🍂'),
        StoryOption('florile', '🌸'),
      ],
    ),
    StoryStep(
      'Atunci boierul l-a aruncat într-un cuptor fierbinte. Cocoșul a dat drumul apei și a stins focul.',
      'Cu ce a stins cocoșul focul?',
      StoryOption('cu apă', '💧'),
      [
        StoryOption('cu zăpadă', '❄️'),
        StoryOption('cu frunze', '🍂'),
        StoryOption('cu lapte', '🥛'),
        StoryOption('cu pietre', '🪨'),
      ],
    ),
    StoryStep(
      'Boierul l-a aruncat apoi printre boi. Cocoșul a înghițit toți boii.',
      'Ce animale a înghițit cocoșul?',
      StoryOption('boii', '🐄'),
      [StoryOption('caii', '🐎'), StoryOption('oile', '🐑'), StoryOption('porcii', '🐖'), StoryOption('iepurii', '🐇')],
    ),
    StoryStep(
      'La urmă, cocoșul a fost aruncat în camera cu bani și a înghițit toți banii. Boierul i-a dat punguța înapoi.',
      'Ce i-a dat boierul la sfârșit?',
      StoryOption('punguța', '🪙'),
      [
        StoryOption('o coroană', '👑'),
        StoryOption('o minge', '⚽'),
        StoryOption('o carte', '📖'),
        StoryOption('un pepene', '🍉'),
      ],
    ),
    StoryStep(
      'Cocoșul s-a întors acasă cu bani și cu boi. Moșul s-a bucurat foarte tare.',
      'Cum s-a simțit moșul?',
      StoryOption('bucuros', '😄'),
      [
        StoryOption('trist', '😢'),
        StoryOption('supărat', '😠'),
        StoryOption('speriat', '😨'),
        StoryOption('obosit', '😴'),
      ],
    ),
  ]),
  Story('Ursul păcălit de vulpe', 'Ion Creangă', '🐻', [
    StoryStep(
      'Era iarnă, iar vulpea era flămândă. Pe drum venea un om cu un car plin cu pește.',
      'Ce ducea omul în car?',
      StoryOption('pește', '🐟'),
      [StoryOption('mere', '🍎'), StoryOption('morcovi', '🥕'), StoryOption('pâine', '🍞'), StoryOption('flori', '🌸')],
    ),
    StoryStep(
      'Vulpea s-a întins în drum și s-a prefăcut că doarme adânc. Omul a luat-o și a pus-o în car.',
      'Ce a făcut vulpea în drum?',
      StoryOption('s-a prefăcut că doarme', '😴'),
      [
        StoryOption('a cântat', '🎵'),
        StoryOption('a dansat'),
        StoryOption('a plâns', '😢'),
        StoryOption('a construit o casă', '🏠'),
      ],
    ),
    StoryStep(
      'Pe drum, vulpea a aruncat peștele din car, apoi a sărit și a fugit.',
      'Ce a aruncat vulpea din car?',
      StoryOption('peștele', '🐟'),
      [
        StoryOption('merele', '🍎'),
        StoryOption('zăpada', '❄️'),
        StoryOption('morcovii', '🥕'),
        StoryOption('pietrele', '🪨'),
      ],
    ),
    StoryStep(
      'A venit ursul și a întrebat-o de unde are atâta pește.',
      'Cine a venit la vulpe?',
      StoryOption('ursul', '🐻'),
      [
        StoryOption('iepurele', '🐇'),
        StoryOption('câinele', '🐶'),
        StoryOption('vaca', '🐄'),
        StoryOption('pisica', '🐱'),
      ],
    ),
    StoryStep(
      'Vulpea l-a păcălit: i-a spus să-și bage coada în apa rece a lacului și să aștepte peștii.',
      'Unde și-a băgat ursul coada?',
      StoryOption('în apa lacului', '💧'),
      [
        StoryOption('în scorbură', '🌳'),
        StoryOption('în foc', '🔥'),
        StoryOption('în nisip'),
        StoryOption('în pământ'),
      ],
    ),
    StoryStep(
      'Ursul a stat acolo toată noaptea, iar apa a înghețat în jurul cozii.',
      'Ce s-a întâmplat cu apa?',
      StoryOption('a înghețat', '❄️'),
      [
        StoryOption('a fiert', '🔥'),
        StoryOption('s-a făcut lapte', '🥛'),
        StoryOption('s-a făcut curcubeu', '🌈'),
        StoryOption('s-a uscat', '☀️'),
      ],
    ),
    StoryStep(
      'Dimineața ursul a tras tare și a rămas fără coadă. De atunci ursul are coada scurtă.',
      'Cum este coada ursului?',
      StoryOption('scurtă'),
      [StoryOption('lungă'), StoryOption('cu dungi'), StoryOption('cu pene'), StoryOption('albastră')],
    ),
    StoryStep(
      'Ursul a înțeles că nu trebuie să crezi pe oricine.',
      'Cine l-a păcălit pe urs?',
      StoryOption('vulpea', '🦊'),
      [
        StoryOption('iepurele', '🐇'),
        StoryOption('omul', '👨'),
        StoryOption('bufnița', '🦉'),
        StoryOption('veverița', '🐿️'),
      ],
    ),
  ]),
];
