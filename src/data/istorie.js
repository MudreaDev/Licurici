// Conținut de Istorie pentru clasele 1-4 (Moldova + România): simboluri naționale,
// trecut vs prezent, personalități. Literal și simplu, potrivit vârstei.

// Simboluri naționale
export const SYMBOLS = [
  { name: 'drapelul României', e: '🇷🇴' },
  { name: 'drapelul Moldovei', e: '🇲🇩' },
  { name: 'coroana domnitorului', e: '👑' },
  { name: 'stema (scutul)', e: '🛡️' },
  { name: 'imnul (cântecul)', e: '🎵' },
  { name: 'castelul / cetatea', e: '🏰' }
];

// Trecut vs prezent (obiecte vechi ↔ noi)
export const PAST_PRESENT = [
  { old: { e: '🕯️', w: 'lumânarea' }, neu: { e: '💡', w: 'becul' } },
  { old: { e: '🐎', w: 'calul' },      neu: { e: '🚗', w: 'mașina' } },
  { old: { e: '📜', w: 'pergamentul' },neu: { e: '📱', w: 'telefonul' } },
  { old: { e: '✉️', w: 'scrisoarea' }, neu: { e: '📧', w: 'e-mailul' } },
  { old: { e: '📻', w: 'radioul' },    neu: { e: '📺', w: 'televizorul' } },
  { old: { e: '🪶', w: 'pana de scris' }, neu: { e: '🖊️', w: 'pixul' } },
  { old: { e: '🏹', w: 'arcul' },      neu: { e: '🚀', w: 'racheta' } }
];

// Personalități (întrebare → cine a fost)
export const PEOPLE = [
  { q: 'Cine a scris poezia „Luceafărul"?',            a: 'Mihai Eminescu' },
  { q: 'Cine a fost mare domnitor și a apărat Moldova?', a: 'Ștefan cel Mare' },
  { q: 'Cine a scris „Amintiri din copilărie"?',        a: 'Ion Creangă' },
  { q: 'Cine a unit prima dată Țările Române?',          a: 'Mihai Viteazul' },
  { q: 'Cine a fost domnitor și mare cărturar?',         a: 'Dimitrie Cantemir' }
];
export const PEOPLE_NAMES = PEOPLE.map(p => p.a);
