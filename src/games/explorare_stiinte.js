// Episod de explorat — ȘTIINȚE: „Autobuzul lui Licurici · Călătorie în natură".
// O hartă ilustrată cu 4 opriri; la fiecare, o provocare trage-și-plasează dintr-o poveste.
// Conținut aliniat curriculumului primar (mediu, ființe, anotimpuri, hrană, ecologie).
import { runEpisode } from '../explore.js';

const EPISODE = {
  id: 'explorare-stiinte',
  title: 'Călătorie în natură',
  lead: 'Alege o oprire pe hartă.',
  outro: 'Ai explorat toată natura! 🌿',
  stops: [
    {
      id: 'habitate', name: 'Casele animalelor', emoji: '🐾', scene: 'ferma',
      x: 16, y: 72,
      intro: 'Bună! Fiecare animal are casa lui. Hai să le ducem acasă!',
      dd: {
        instruction: 'Trage fiecare animal la casa lui.',
        zones: [
          { id: 'ferma',  name: 'Fermă',  emoji: '🚜' },
          { id: 'padure', name: 'Pădure', emoji: '🌲' },
          { id: 'ocean',  name: 'Ocean',  emoji: '🌊' }
        ],
        items: [
          { emoji: '🐄', zone: 'ferma' },  { emoji: '🐔', zone: 'ferma' },
          { emoji: '🦊', zone: 'padure' }, { emoji: '🐻', zone: 'padure' },
          { emoji: '🐠', zone: 'ocean' },  { emoji: '🐙', zone: 'ocean' }
        ]
      }
    },
    {
      id: 'anotimpuri', name: 'Anotimpurile', emoji: '🍂', scene: 'anotimpuri',
      x: 39, y: 50,
      intro: 'Fiecare lucru vine cu anotimpul lui. Unde se potrivește?',
      dd: {
        instruction: 'Trage fiecare lucru la anotimpul lui.',
        zones: [
          { id: 'primavara', name: 'Primăvara', emoji: '🌷' },
          { id: 'vara',      name: 'Vara',      emoji: '☀️' },
          { id: 'toamna',    name: 'Toamna',    emoji: '🍂' },
          { id: 'iarna',     name: 'Iarna',     emoji: '❄️' }
        ],
        items: [
          { emoji: '🐣', zone: 'primavara' }, { emoji: '🌱', zone: 'primavara' },
          { emoji: '🍉', zone: 'vara' },      { emoji: '🏖️', zone: 'vara' },
          { emoji: '🌰', zone: 'toamna' },    { emoji: '☔', zone: 'toamna' },
          { emoji: '⛄', zone: 'iarna' },     { emoji: '🧣', zone: 'iarna' }
        ]
      }
    },
    {
      id: 'hrana', name: 'Ce mănâncă?', emoji: '🥕', scene: 'hrana',
      x: 62, y: 61,
      intro: 'Iepurele mănâncă plante, leul mănâncă carne. Dă-le de mâncare!',
      dd: {
        instruction: 'Trage hrana la animalul potrivit.',
        zones: [
          { id: 'iepure', name: 'Iepure', emoji: '🐰' },
          { id: 'leu',    name: 'Leu',    emoji: '🦁' }
        ],
        items: [
          { emoji: '🥕', zone: 'iepure' }, { emoji: '🥬', zone: 'iepure' }, { emoji: '🌿', zone: 'iepure' },
          { emoji: '🍖', zone: 'leu' },    { emoji: '🍗', zone: 'leu' },    { emoji: '🐟', zone: 'leu' }
        ]
      }
    },
    {
      id: 'reciclare', name: 'Sortăm gunoiul', emoji: '♻️', scene: 'reciclare',
      x: 85, y: 40,
      intro: 'Hai să păstrăm parcul curat! Fiecare gunoi are coșul lui.',
      dd: {
        instruction: 'Pune fiecare gunoi în coșul potrivit.',
        zones: [
          { id: 'hartie',  name: 'Hârtie',  emoji: '📄' },
          { id: 'plastic', name: 'Plastic', emoji: '🥤' },
          { id: 'resturi', name: 'Resturi', emoji: '🍎' }
        ],
        items: [
          { emoji: '📰', zone: 'hartie' },  { emoji: '📦', zone: 'hartie' },
          { emoji: '🍾', zone: 'plastic' }, { emoji: '🧴', zone: 'plastic' },
          { emoji: '🍌', zone: 'resturi' }, { emoji: '🍂', zone: 'resturi' }
        ]
      }
    }
  ]
};

export default {
  id: 'explorare-stiinte',
  name: 'Autobuzul lui Licurici',
  emoji: '🚌',
  desc: 'Explorează natura: hartă cu opriri și provocări',
  badge: 'Explorare',
  start(mount, ctx) { runEpisode(mount, ctx, EPISODE); }
};
