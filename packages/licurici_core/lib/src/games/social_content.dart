/// Conținutul jocurilor de cogniție socială (EMO3–EMO6). Texte scrise de noi, de validat cu un
/// specialist (plan §10). Fără fotografii, fără persoane reale: personaje inventate.
library;

/// Un personaj. [female] decide acordul („tristă”, „o ajută”).
class Character {
  const Character(this.name, this.emoji, {required this.female});
  final String name;
  final String emoji;
  final bool female;

  /// Pronumele în acuzativ, înaintea verbului: „Ce **o** poate ajuta?”.
  String get acc => female ? 'o' : 'îl';
}

const characters = [
  Character('Ana', '👧', female: true),
  Character('Matei', '👦', female: false),
  Character('Sofia', '👧', female: true),
  Character('Luca', '👦', female: false),
];

/// O emoție cu forma de feminin și situațiile tipice. `{n}` = numele personajului.
class FeltEmotion {
  const FeltEmotion(this.key, this.emoji, this.masc, this.fem, this.situations, {this.minTier = 1});
  final String key;
  final String emoji;
  final String masc;
  final String fem;
  final List<String> situations;

  /// De la ce tier apare (emoțiile de bază întâi).
  final int minTier;

  String label(Character c) => c.female ? fem : masc;
}

const feltEmotions = [
  FeltEmotion('fericit', '😊', 'Fericit', 'Fericită', [
    '{n} a primit un cadou.',
    '{n} se joacă în parc cu prietenii.',
    '{n} mănâncă înghețata preferată.',
    '{n} merge în vizită la bunici.',
  ]),
  FeltEmotion('trist', '😢', 'Trist', 'Tristă', [
    '{n} a pierdut balonul.',
    '{n} vede că jucăria preferată s-a stricat.',
    '{n} nu are cu cine să se joace în pauză.',
    '{n} își ia rămas-bun de la un prieten care pleacă departe.',
  ]),
  FeltEmotion('suparat', '😠', 'Supărat', 'Supărată', [
    '{n} construiește un turn, iar cineva îl dărâmă.',
    '{n} se joacă, iar un copil îi ia jucăria fără să întrebe.',
    '{n} trebuie să se oprească din joc chiar când era mai frumos.',
    '{n} așteaptă la tobogan, iar cineva se bagă în față.',
  ]),
  FeltEmotion('speriat', '😨', 'Speriat', 'Speriată', [
    '{n} aude un tunet foarte puternic.',
    '{n} vede un câine mare care latră.',
    '{n} e în cameră și deodată se stinge lumina.',
    '{n} nu își mai vede mama în magazin.',
  ]),
  FeltEmotion('surprins', '😲', 'Surprins', 'Surprinsă', [
    'Toți strigă „Surpriză!” când {n} intră în cameră.',
    '{n} deschide o cutie, și din ea sare un iepuraș de jucărie.',
    '{n} vede ninsoare afară, deși ieri era cald.',
  ], minTier: 3),
  FeltEmotion('obosit', '😴', 'Obosit', 'Obosită', [
    '{n} a alergat toată ziua.',
    'E seară târziu, iar {n} abia își mai ține ochii deschiși.',
    '{n} s-a întors de la o plimbare foarte lungă.',
  ], minTier: 3),
  FeltEmotion('mandru', '😄', 'Mândru', 'Mândră', [
    '{n} și-a legat șireturile fără ajutor.',
    '{n} a terminat un puzzle greu.',
    '{n} a învățat să meargă pe bicicletă.',
  ], minTier: 5),
  FeltEmotion('calm', '😌', 'Calm', 'Calmă', [
    '{n} ascultă o muzică liniștită.',
    '{n} stă în brațele mamei și respiră încet.',
    '{n} privește peștii din acvariu.',
  ], minTier: 5),
];

/// Emoții care se pot confunda (un singur răspuns bun: nu apar una ca distractor pentru alta).
const similarEmotions = {
  'fericit': {'mandru', 'calm', 'surprins'},
  'mandru': {'fericit'},
  'calm': {'fericit', 'obosit'},
  'obosit': {'calm'},
  'speriat': {'surprins'},
  'surprins': {'speriat', 'fericit'},
  'trist': <String>{},
  'suparat': <String>{},
};

/// Emoțiile grele (pentru alegerea distractorilor la întrebările despre cauze).
const hardEmotions = {'trist', 'suparat', 'speriat'};

bool emotionsClash(String a, String b) =>
    a == b || (similarEmotions[a]?.contains(b) ?? false) || (similarEmotions[b]?.contains(a) ?? false);

// ---------------------------------------------------------------- EMO4: ce mă ajută

class Strategy {
  const Strategy(this.label, this.emoji);
  final String label;
  final String emoji;
}

/// Strategii potrivite pentru fiecare emoție „grea” (reglare emoțională).
const helpfulStrategies = {
  'trist': [
    Strategy('Cere o îmbrățișare.', '🤗'),
    Strategy('Spune cuiva ce simte.', '🗣️'),
    Strategy('Se joacă cu jucăria preferată.', '🧸'),
  ],
  'suparat': [
    Strategy('Respiră adânc de trei ori.', '🌬️'),
    Strategy('Numără încet până la zece.', '🔟'),
    Strategy('Spune ce nu îi place, cu voce calmă.', '🗣️'),
  ],
  'speriat': [
    Strategy('Cere ajutorul unui adult.', '🙋'),
    Strategy('Aprinde lumina.', '💡'),
    Strategy('Ține strâns jucăria preferată.', '🧸'),
  ],
  'obosit': [
    Strategy('Se odihnește puțin.', '🛌'),
    Strategy('Merge la culcare.', '😴'),
  ],
};

/// Comportamente care nu ajută (distractori clari, fără ambiguitate).
const unhelpfulStrategies = [
  Strategy('Lovește masa.', '🔊'),
  Strategy('Țipă la toată lumea.', '😡'),
  Strategy('Aruncă jucăriile.', '🗑️'),
  Strategy('Rupe desenul.', '📄'),
  Strategy('Strică jocul altora.', '🧩'),
  Strategy('Împinge un copil.', '🖐️'),
];

// ---------------------------------------------------------------- EMO5: cine știe

class Thing {
  const Thing(this.def, this.emoji);

  /// Forma articulată: „mingea”.
  final String def;
  final String emoji;
}

class Place {
  const Place(this.inPhrase, this.label, this.emoji);

  /// „în cutie”.
  final String inPhrase;

  /// Eticheta variantei: „În cutie”.
  final String label;
  final String emoji;
}

const hiddenThings = [
  Thing('mingea', '⚽'),
  Thing('ursulețul', '🧸'),
  Thing('mașinuța', '🚗'),
  Thing('cartea', '📖'),
];

const hidingPlaces = [
  Place('în cutie', 'În cutie', '📦'),
  Place('în coș', 'În coș', '🛒'),
  Place('în ghiozdan', 'În ghiozdan', '🎒'),
  Place('sub pat', 'Sub pat', '🛏️'),
];

/// Recipiente cu conținut neașteptat (sarcina „Smarties”).
class TrickBox {
  const TrickBox(this.name, this.expected, this.expectedEmoji, this.actual, this.actualEmoji);

  /// „cutia de creioane”.
  final String name;
  final String expected;
  final String expectedEmoji;
  final String actual;
  final String actualEmoji;
}

const trickBoxes = [
  TrickBox('cutia de creioane', 'Creioane', '✏️', 'Bomboane', '🍭'),
  TrickBox('cutia de jucării', 'Jucării', '🧸', 'Mere', '🍎'),
  TrickBox('cutia de ouă', 'Ouă', '🥚', 'Mingiuțe', '⚽'),
];

// ---------------------------------------------------------------- EMO6: situații sociale

/// O situație cu un singur comportament potrivit și patru nepotrivite (generare generoasă;
/// motorul taie variantele după tier). [level] 1 = viața de zi cu zi, 3 = situații mai fine.
class SocialScenario {
  const SocialScenario(this.question, this.good, this.bad, this.explain, {this.level = 1});
  final String question;
  final String good;
  final List<String> bad;
  final String explain;
  final int level;
}

const socialScenarios = [
  SocialScenario('Un prieten îți spune „Bună!”. Ce faci?', 'Îi spun și eu „Bună!”',
      ['Mă întorc cu spatele', 'Mă prefac că nu aud', 'Fug de lângă el', 'Îi fac o grimasă'],
      'Când cineva ne salută, salutăm și noi.'),
  SocialScenario('Cineva îți dă un cadou. Ce spui?', '„Mulțumesc!”',
      ['„Nu îl vreau!”', 'Nu spun nimic', '„Dă-mi și altul!”', 'Îl arunc'],
      'Când primim ceva, spunem „Mulțumesc”.'),
  SocialScenario('Vrei jucăria pe care o are alt copil. Ce faci?', 'Întreb: „Pot să mă joc și eu?”',
      ['I-o smulg din mână', 'Țip la el', 'Îl împing', 'Plâng până mi-o dă'],
      'Întrebăm frumos și așteptăm răspunsul.'),
  SocialScenario('Ai dărâmat din greșeală turnul cuiva. Ce spui?', '„Îmi pare rău!”',
      ['„Nu am fost eu!”', 'Nu spun nimic', 'Râd', 'Dărâm și restul'],
      'Când greșim, ne cerem scuze. E în regulă să greșim.'),
  SocialScenario('E rândul altui copil la leagăn. Ce faci?', 'Aștept să vină rândul meu',
      ['Mă bag în față', 'Îl dau jos din leagăn', 'Țip că vreau eu', 'Plec supărat acasă'],
      'Așteptăm pe rând. Fiecare are șansa lui.'),
  SocialScenario('Un coleg a căzut pe hol. Ce faci?', 'Îl ajut să se ridice',
      ['Râd de el', 'Trec pe lângă el', 'Îl arăt cu degetul', 'Îl împing'],
      'Când cineva cade, îl ajutăm. Așa arătăm că ne pasă.'),
  SocialScenario('Ai terminat de mâncat. Ce faci cu farfuria?', 'O duc la chiuvetă',
      ['O las pe jos', 'O arunc', 'O ascund sub masă', 'O las pe scaun'],
      'Strângem după noi și ne ajutăm familia.'),
  SocialScenario('Vrei să traversezi strada. Ce faci mai întâi?', 'Mă opresc și mă uit în ambele părți',
      ['Alerg direct', 'Trec cu ochii închiși', 'Mă joc cu mingea pe stradă', 'Trec pe roșu'],
      'Ne uităm stânga-dreapta și trecem cu un adult.'),
  SocialScenario('Un copil nou stă singur în pauză. Ce poți face?', 'Îl invit să se joace cu mine',
      ['Îl las singur', 'Îl arăt cu degetul', 'Râd de el', 'Le spun altora să nu se joace cu el'],
      'Invităm copiii noi la joacă. Așa își fac prieteni.', level: 2),
  SocialScenario('Vorbește doamna educatoare. Ce faci?', 'Ascult în liniște',
      ['Vorbesc peste ea', 'Mă plimb prin clasă', 'Cânt tare', 'Bat cu pumnii în bancă'],
      'Când cineva vorbește, ascultăm. Vorbim când e rândul nostru.', level: 2),
  SocialScenario('Vrei să spui ceva, dar altcineva vorbește. Ce faci?', 'Ridic mâna și aștept',
      ['Strig peste el', 'Vorbesc mai tare', 'Îl împing', 'Îi închid gura cu mâna'],
      'Ridicăm mâna și așteptăm. Așa toată lumea e ascultată.', level: 2),
  SocialScenario('Pierzi la un joc. Ce faci?', 'Spun „Bravo!” și mai încerc',
      ['Mă enervez și plec', 'Stric jocul', 'Spun că a trișat', 'Arunc piesele'],
      'E în regulă să pierdem uneori. Felicităm și încercăm din nou.', level: 2),
  SocialScenario('Un coleg e trist. Ce poți face?', 'Îl întreb dacă e bine',
      ['Îl ignor', 'Râd de el', 'Îi iau jucăria', 'Îi spun să tacă'],
      'Când cineva e trist, îl întrebăm cum se simte.', level: 2),
  SocialScenario('Ești supărat și vrei să te liniștești. Ce faci?', 'Respir adânc de câteva ori',
      ['Lovesc masa', 'Țip tare', 'Arunc jucăriile', 'Împing pe cineva'],
      'Când suntem supărați, respirăm adânc. Ne ajută să ne calmăm.', level: 2),
  SocialScenario('Un copil vrea să te îmbrățișeze, dar tu nu vrei. Ce faci?',
      'Spun calm: „Nu, mulțumesc”',
      ['Îl lovesc', 'Țip la el', 'Fug și mă ascund', 'Plâng fără să spun nimic'],
      'Avem voie să spunem „nu” atunci când nu vrem. O spunem calm.', level: 3),
  SocialScenario('Nu reușești să deschizi o cutie. Ce faci?', 'Cer ajutorul: „Mă ajuți, te rog?”',
      ['Arunc cutia', 'Țip la cutie', 'Plâng și renunț', 'O lovesc de masă'],
      'Când ceva e prea greu, cerem ajutor. E un lucru bun.', level: 3),
  SocialScenario('Prietenul tău vrea să joace alt joc decât tine. Ce faci?',
      'Propun: „Întâi jocul tău, apoi al meu”',
      ['Mă joc doar ce vreau eu', 'Plec supărat', 'Îi stric jocul', 'Îi spun că nu mai suntem prieteni'],
      'Ne înțelegem pe rând: întâi unul, apoi celălalt.', level: 3),
  SocialScenario('Un coleg a desenat ceva frumos. Ce poți spune?', '„Ce desen frumos!”',
      ['„E urât”', 'Nu spun nimic și îl mâzgălesc', 'Râd de el', 'I-l iau'],
      'Când cineva face ceva frumos, îi spunem. Îl face să se simtă bine.', level: 3),
  SocialScenario('Ai luat fără să vrei creionul colegului. Ce faci?', 'I-l dau înapoi',
      ['Îl păstrez', 'Îl ascund', 'Îl rup', 'Spun că e al meu'],
      'Dăm înapoi lucrurile care nu sunt ale noastre.', level: 3),
  SocialScenario('Un adult necunoscut te cheamă să pleci cu el. Ce faci?',
      'Spun „Nu!” și merg la mama sau la educatoare',
      ['Plec cu el', 'Îi dau mâna', 'Îi spun unde locuiesc', 'Urc în mașina lui'],
      'Nu plecăm niciodată cu oameni necunoscuți. Mergem la un adult cunoscut.', level: 3),
];
