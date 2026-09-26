// Bănci de conținut. Jocurile aleg aleator din acestea → mereu ceva nou.
// Totul în română, literal și clar (fără metafore/ironie — recomandare autism).

// ---- EMOȚII (recunoaștere emoții — cea mai puternică dovadă) ----
export const EMOTIONS = [
  { key: 'fericit',  emoji: '😊', label: 'Fericit',  contexts: ['a primit un cadou', 'se joacă cu prietenii', 'mănâncă înghețata preferată', 'a câștigat un joc'] },
  { key: 'trist',    emoji: '😢', label: 'Trist',    contexts: ['i s-a stricat jucăria', 'prietenul a plecat acasă', 'a pierdut balonul', 's-a lovit la genunchi'] },
  { key: 'suparat',  emoji: '😠', label: 'Supărat',  contexts: ['cineva i-a luat jucăria', 'nu a primit ce voia', 'a fost întrerupt din joc'] },
  { key: 'speriat',  emoji: '😨', label: 'Speriat',  contexts: ['a auzit un tunet puternic', 'a văzut un câine mare', 'era întuneric în cameră'] },
  { key: 'surprins', emoji: '😲', label: 'Surprins', contexts: ['a primit o surpriză', 'a văzut un balon spărgându-se', 'cineva a strigat „Surpriză!"'] },
  { key: 'obosit',   emoji: '😴', label: 'Obosit',   contexts: ['s-a jucat toată ziua', 'este seară târziu', 'a alergat mult'] },
  { key: 'calm',     emoji: '😌', label: 'Calm',     contexts: ['ascultă muzică liniștită', 'respiră adânc', 'stă lângă mama'] },
  { key: 'mandru',   emoji: '😄', label: 'Mândru',   contexts: ['a terminat un desen frumos', 'a ajutat un prieten', 'a învățat ceva nou'] }
];

// ---- RUTINE ZILNICE (ordonare pași — funcții executive, independență) ----
export const ROUTINES = [
  { name: 'Spălatul pe dinți', steps: [
    { emoji: '🪥', t: 'Iei periuța' },
    { emoji: '🧴', t: 'Pui pasta' },
    { emoji: '😬', t: 'Te speli pe dinți' },
    { emoji: '💧', t: 'Clătești gura' }
  ]},
  { name: 'Spălatul pe mâini', steps: [
    { emoji: '💧', t: 'Deschizi apa' },
    { emoji: '🧼', t: 'Pui săpun' },
    { emoji: '🙌', t: 'Freci mâinile' },
    { emoji: '🧻', t: 'Ștergi mâinile' }
  ]},
  { name: 'Te pregătești de somn', steps: [
    { emoji: '🛁', t: 'Faci baie' },
    { emoji: '👕', t: 'Pui pijamaua' },
    { emoji: '📖', t: 'Citești o poveste' },
    { emoji: '🛏️', t: 'Te culci' }
  ]},
  { name: 'Te pregătești de școală', steps: [
    { emoji: '⏰', t: 'Te trezești' },
    { emoji: '🍽️', t: 'Iei micul dejun' },
    { emoji: '👔', t: 'Te îmbraci' },
    { emoji: '🎒', t: 'Iei ghiozdanul' }
  ]},
  { name: 'Faci un sandviș', steps: [
    { emoji: '🍞', t: 'Iei pâinea' },
    { emoji: '🧈', t: 'Pui unt' },
    { emoji: '🧀', t: 'Pui cașcaval' },
    { emoji: '🥪', t: 'Îl mănânci' }
  ]},
  { name: 'Uzi o floare', steps: [
    { emoji: '🚰', t: 'Umpli stropitoarea' },
    { emoji: '🪴', t: 'Mergi la floare' },
    { emoji: '💧', t: 'Torni apa' },
    { emoji: '🌸', t: 'Floarea crește' }
  ]},
  { name: 'Te speli pe mâini înainte de masă', steps: [
    { emoji: '🖐️', t: 'Mergi la chiuvetă' },
    { emoji: '🧼', t: 'Te speli cu săpun' },
    { emoji: '🍽️', t: 'Te așezi la masă' },
    { emoji: '😋', t: 'Mănânci' }
  ]},
  { name: 'Plantezi o sămânță', steps: [
    { emoji: '🪱', t: 'Faci o groapă' },
    { emoji: '🌰', t: 'Pui sămânța' },
    { emoji: '🌱', t: 'Acoperi cu pământ' },
    { emoji: '💧', t: 'O uzi' }
  ]},
  { name: 'Îți faci patul', steps: [
    { emoji: '🛏️', t: 'Întinzi cearșaful' },
    { emoji: '🛌', t: 'Pui plapuma' },
    { emoji: '🪧', t: 'Așezi perna' },
    { emoji: '✨', t: 'Patul e gata' }
  ]}
];

// ---- CATEGORII (sortare — formarea conceptelor) ----
export const CATEGORIES = [
  { name: 'Animale',  emoji: '🐾', items: ['🐶','🐱','🐰','🐮','🐷','🐸','🦊','🐵','🐴','🐔'] },
  { name: 'Fructe',   emoji: '🍎', items: ['🍎','🍌','🍓','🍇','🍊','🍉','🍒','🥝','🍑','🍐'] },
  { name: 'Vehicule', emoji: '🚗', items: ['🚗','🚌','🚲','✈️','🚂','🚁','🚓','🚜','🛵','⛵'] },
  { name: 'Haine',    emoji: '👕', items: ['👕','👖','🧦','🧤','🧣','👗','👟','🧢','🩳','🥾'] },
  { name: 'Mâncare',  emoji: '🍽️', items: ['🍕','🍔','🍟','🥗','🍜','🥪','🌭','🧀','🥚','🍞'] },
  { name: 'Jucării',  emoji: '🧸', items: ['🧸','🪀','🎈','🎲','🪁','🧩','🚂','⚽','🎨','🪆'] },
  { name: 'Corpul',   emoji: '🖐️', items: ['👁️','👂','👃','👄','🖐️','🦶','🦵','🦷','👅','💪'] },
  { name: 'Natură',   emoji: '🌳', items: ['🌳','🌲','🌵','🌻','🍄','🌊','⛰️','🌈','☀️','🌙'] },
  { name: 'Instrumente', emoji: '🎸', items: ['🎸','🥁','🎹','🎺','🎻','🪕','🎷','🪈','🎤','🪇'] }
];

// ---- SCENARII SOCIALE (perspectivă, ce e potrivit să faci) ----
export const SOCIAL = [
  { q: 'Un coleg a căzut pe hol. Ce faci?',
    options: [ {t:'Îl ajut să se ridice', good:true}, {t:'Râd de el', good:false}, {t:'Plec mai departe', good:false} ],
    explain: 'Când cineva cade, îl ajutăm. Așa arătăm că ne pasă.' },
  { q: 'Vrei să te joci cu o jucărie pe care o are alt copil. Ce faci?',
    options: [ {t:'O întreb: „Pot să mă joc și eu?"', good:true}, {t:'I-o smulg din mână', good:false}, {t:'Țip la el', good:false} ],
    explain: 'Întrebăm frumos și așteptăm răspunsul. Nu luăm cu forța.' },
  { q: 'Un prieten îți spune „Bună!". Ce faci?',
    options: [ {t:'Îi spun și eu „Bună!"', good:true}, {t:'Mă întorc cu spatele', good:false}, {t:'Mă prefac că nu aud', good:false} ],
    explain: 'Când cineva ne salută, salutăm și noi. E politicos.' },
  { q: 'Ai greșit și ai dărâmat turnul cuiva. Ce spui?',
    options: [ {t:'„Îmi pare rău!"', good:true}, {t:'„Nu am fost eu!"', good:false}, {t:'Nu spun nimic', good:false} ],
    explain: 'Când greșim, ne cerem scuze. E în regulă să greșim.' },
  { q: 'Cineva îți dă un cadou. Ce spui?',
    options: [ {t:'„Mulțumesc!"', good:true}, {t:'„Nu îl vreau"', good:false}, {t:'Nu spun nimic', good:false} ],
    explain: 'Când primim ceva, spunem „Mulțumesc".' },
  { q: 'E rândul altui copil la joc. Ce faci?',
    options: [ {t:'Aștept rândul meu', good:true}, {t:'Mă bag în față', good:false}, {t:'Iau jocul oricum', good:false} ],
    explain: 'Așteptăm pe rând. Fiecare are șansa lui.' },
  { q: 'Ești supărat și vrei să te liniștești. Ce faci?',
    options: [ {t:'Respir adânc de câteva ori', good:true}, {t:'Lovesc masa', good:false}, {t:'Țip tare', good:false} ],
    explain: 'Când suntem supărați, respirăm adânc. Ne ajută să ne calmăm.' },
  { q: 'Un coleg e trist. Ce poți face?',
    options: [ {t:'Îl întreb dacă e bine', good:true}, {t:'Îl ignor', good:false}, {t:'Râd de el', good:false} ],
    explain: 'Când cineva e trist, îl întrebăm cum se simte. Arătăm grijă.' },
  { q: 'Vorbește doamna profesoară. Ce faci?',
    options: [ {t:'Ascult în liniște', good:true}, {t:'Vorbesc peste ea', good:false}, {t:'Mă plimb prin clasă', good:false} ],
    explain: 'Când cineva vorbește, ascultăm. Vorbim când e rândul nostru.' },
  { q: 'Vrei să spui ceva, dar altcineva vorbește. Ce faci?',
    options: [ {t:'Ridic mâna și aștept', good:true}, {t:'Strig peste el', good:false}, {t:'Vorbesc mai tare', good:false} ],
    explain: 'Ridicăm mâna și așteptăm rândul. Așa toată lumea e ascultată.' },
  { q: 'Un copil nou stă singur în pauză. Ce poți face?',
    options: [ {t:'Îl invit să se joace cu mine', good:true}, {t:'Îl las singur', good:false}, {t:'Îl arăt cu degetul', good:false} ],
    explain: 'Invităm copiii noi la joacă. Așa își fac prieteni.' },
  { q: 'Ai terminat de mâncat. Ce faci cu farfuria?',
    options: [ {t:'O duc la chiuvetă', good:true}, {t:'O las pe jos', good:false}, {t:'O arunc', good:false} ],
    explain: 'Strângem după noi. Ne ajutăm familia.' },
  { q: 'Pierzi la un joc. Ce faci?',
    options: [ {t:'Spun „Bravo!" și mai încerc', good:true}, {t:'Mă enervez și plec', good:false}, {t:'Stric jocul', good:false} ],
    explain: 'E în regulă să pierdem uneori. Felicităm și încercăm din nou.' },
  { q: 'Vrei să treci strada. Ce faci mai întâi?',
    options: [ {t:'Mă uit stânga-dreapta', good:true}, {t:'Alerg direct', good:false}, {t:'Trec cu ochii închiși', good:false} ],
    explain: 'Ne uităm în ambele părți înainte să traversăm. Așa suntem în siguranță.' }
];

// ---- OBIECTE pentru NUMĂRAT / ADUNARE / SCĂDERE (concret, vizual) ----
export const COUNT_ITEMS = ['🍎','⭐','🎈','🐶','🌸','🚗','🍓','🐟','🦋','🧸','🌟','🍒','🍏','🐥','🌷','🎁'];

// ---- FORME/CULORI pentru MODELE (pattern) ----
export const PATTERN_TOKENS = ['🔴','🔵','🟢','🟡','🟣','🟠','🔺','⬛','⬜','⭐','💛','🟩'];

// ---- PERECHI pentru POTRIVIRE (matching / memorie) ----
export const MATCH_ITEMS = ['🍎','🐶','🚗','⭐','🌸','🎈','🐱','🍓','⚽','🦋','🌈','🍌','🐸','🚂','🧩','🎨','🦁','🐧','🚀','🌵','🍉','🎩','🐢','🦉'];

// ---- VOCABULAR COMUNICARE (tablă tip PECS/AAC) ----
export const AAC = [
  { cat: 'Vreau',    emoji: '🙋', words: [
    {e:'💧', w:'apă'}, {e:'🍎', w:'mâncare'}, {e:'🧸', w:'jucăria'}, {e:'📖', w:'o carte'}, {e:'▶️', w:'să mă joc'}, {e:'🛌', w:'să mă odihnesc'} ] },
  { cat: 'Simt',     emoji: '❤️', words: [
    {e:'😊', w:'bine'}, {e:'😢', w:'trist'}, {e:'😠', w:'supărat'}, {e:'😨', w:'speriat'}, {e:'😴', w:'obosit'}, {e:'🤕', w:'durere'} ] },
  { cat: 'Oameni',   emoji: '👨‍👩‍👧', words: [
    {e:'👩', w:'mama'}, {e:'👨', w:'tata'}, {e:'🧑‍🏫', w:'doamna'}, {e:'🧒', w:'prieten'}, {e:'👵', w:'bunica'}, {e:'👴', w:'bunicul'} ] },
  { cat: 'Acțiuni',  emoji: '🏃', words: [
    {e:'🍽️', w:'mănânc'}, {e:'🥤', w:'beau'}, {e:'🚽', w:'la baie'}, {e:'🎵', w:'muzică'}, {e:'🚶', w:'merg'}, {e:'🤗', w:'îmbrățișare'} ] },
  { cat: 'Politețe', emoji: '🙏', words: [
    {e:'👋', w:'bună'}, {e:'🙏', w:'mulțumesc'}, {e:'✅', w:'da'}, {e:'❌', w:'nu'}, {e:'🆘', w:'ajutor'}, {e:'😔', w:'îmi pare rău'} ] },
  { cat: 'Locuri',   emoji: '🏠', words: [
    {e:'🏠', w:'acasă'}, {e:'🏫', w:'la școală'}, {e:'🏞️', w:'în parc'}, {e:'🛒', w:'la magazin'}, {e:'🚗', w:'în mașină'}, {e:'🏥', w:'la doctor'} ] },
  { cat: 'Timp',     emoji: '⏰', words: [
    {e:'☀️', w:'acum'}, {e:'⏳', w:'mai târziu'}, {e:'✅', w:'gata'}, {e:'🔁', w:'încă o dată'}, {e:'⏸️', w:'pauză'}, {e:'🌙', w:'seara'} ] }
];

// ---- ALFABET (litere + cuvinte-exemplu; pentru jocul „Alfabetul") ----
export const ALPHABET = [
  { l:'A', w:'albină',    e:'🐝' }, { l:'B', w:'balon',   e:'🎈' },
  { l:'C', w:'casă',      e:'🏠' }, { l:'D', w:'delfin',  e:'🐬' },
  { l:'E', w:'elefant',   e:'🐘' }, { l:'F', w:'floare',  e:'🌸' },
  { l:'G', w:'girafă',    e:'🦒' }, { l:'I', w:'inimă',   e:'❤️' },
  { l:'J', w:'jucărie',   e:'🧸' }, { l:'L', w:'lună',    e:'🌙' },
  { l:'M', w:'măr',       e:'🍎' }, { l:'N', w:'nor',     e:'☁️' },
  { l:'O', w:'ou',        e:'🥚' }, { l:'P', w:'pește',   e:'🐟' },
  { l:'R', w:'rață',      e:'🦆' }, { l:'S', w:'soare',   e:'☀️' },
  { l:'T', w:'tobă',      e:'🥁' }, { l:'U', w:'urs',     e:'🐻' },
  { l:'V', w:'vulpe',     e:'🦊' }, { l:'Z', w:'zebră',   e:'🦓' },
  { l:'Ș', w:'șarpe',     e:'🐍' }, { l:'B', w:'banană',  e:'🍌' },
  { l:'C', w:'cireașă',   e:'🍒' }, { l:'P', w:'pisică',  e:'🐱' }
];

// ---- CULORI (nume + cod; pentru jocul „Culori") ----
export const COLORS = [
  { name:'roșu',       hex:'#e06b6b' },
  { name:'albastru',   hex:'#5b9bb5' },
  { name:'verde',      hex:'#6bbf8a' },
  { name:'galben',     hex:'#f2cf6b' },
  { name:'portocaliu', hex:'#e6a86a' },
  { name:'mov',        hex:'#a9a3d1' },
  { name:'roz',        hex:'#f0a9c0' },
  { name:'maro',       hex:'#a9805f' },
  { name:'gri',        hex:'#9aa7a7' },
  { name:'negru',      hex:'#3b3b3b' }
];

// ---- FORME (nume + simbol; pentru jocul „Forme") ----
export const SHAPES = [
  { name:'cerc',       e:'🔵' },
  { name:'pătrat',     e:'🟦' },
  { name:'triunghi',   e:'🔺' },
  { name:'stea',       e:'⭐' },
  { name:'inimă',      e:'❤️' },
  { name:'romb',       e:'🔷' }
];

// ---- OPUSE (pentru jocul „Opuse") ----
export const OPPOSITES = [
  { a:{w:'mare', e:'🐘'},   b:{w:'mic', e:'🐭'} },
  { a:{w:'sus', e:'⬆️'},    b:{w:'jos', e:'⬇️'} },
  { a:{w:'cald', e:'☀️'},   b:{w:'rece', e:'❄️'} },
  { a:{w:'zi', e:'🌞'},     b:{w:'noapte', e:'🌙'} },
  { a:{w:'vesel', e:'😄'},  b:{w:'trist', e:'😢'} },
  { a:{w:'rapid', e:'🐇'},  b:{w:'încet', e:'🐢'} },
  { a:{w:'deschis', e:'🔓'},b:{w:'închis', e:'🔒'} },
  { a:{w:'plin', e:'🥛'},   b:{w:'gol', e:'🥛'} },
  { a:{w:'curat', e:'🧼'},  b:{w:'murdar', e:'🧦'} },
  { a:{w:'lung', e:'🦒'},   b:{w:'scurt', e:'🐛'} },
  { a:{w:'greu', e:'🪨'},   b:{w:'ușor', e:'🪶'} },
  { a:{w:'uscat', e:'🏜️'},  b:{w:'ud', e:'💧'} }
];
