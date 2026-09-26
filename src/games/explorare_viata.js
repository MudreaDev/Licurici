// Episod de explorat — EMOȚII & VIAȚĂ: „O zi bună".
// Trei opriri care învață deprinderi importante: recunoașterea emoțiilor (SEL),
// alegeri sănătoase la mâncare și siguranța (ce e sigur / ce cere grija unui adult).
// Reutilizează motorul de episoade (explore.js) + drag-drop (dragdrop.js).
import { runEpisode } from '../explore.js';

const EPISODE = {
  id: 'explorare-viata',
  title: 'O zi bună',
  mapScene: 'oras',
  lead: 'Alege o oprire pe hartă.',
  outro: 'Ai avut o zi bună! 🌟',
  stops: [
    {
      id: 'emotii', name: 'Cum mă simt', emoji: '😊', scene: 'camera',
      x: 17, y: 68,
      intro: 'Toți avem emoții. Hai să potrivim fața cu ce simte.',
      dd: {
        instruction: 'Trage fiecare față la emoția potrivită.',
        zones: [
          { id: 'bucuros',  name: 'Bucuros',  emoji: '😀' },
          { id: 'trist',    name: 'Trist',    emoji: '😢' },
          { id: 'suparat',  name: 'Supărat',  emoji: '😠' },
          { id: 'speriat',  name: 'Speriat',  emoji: '😨' }
        ],
        items: [
          { emoji: '😄', zone: 'bucuros' }, { emoji: '🙂', zone: 'bucuros' },
          { emoji: '😢', zone: 'trist' },   { emoji: '😭', zone: 'trist' },
          { emoji: '😠', zone: 'suparat' }, { emoji: '😡', zone: 'suparat' },
          { emoji: '😨', zone: 'speriat' }, { emoji: '😰', zone: 'speriat' }
        ]
      }
    },
    {
      id: 'mancare', name: 'Mâncare sănătoasă', emoji: '🥗', scene: 'camera',
      x: 50, y: 46,
      intro: 'Ce mâncăm des și ce doar câteodată?',
      dd: {
        instruction: 'Trage mâncarea: sănătoasă sau doar câteodată.',
        zones: [
          { id: 'sanatos', name: 'Sănătos',        emoji: '🥗' },
          { id: 'rar',     name: 'Doar câteodată', emoji: '🍰' }
        ],
        items: [
          { emoji: '🍎', zone: 'sanatos' }, { emoji: '🥕', zone: 'sanatos' }, { emoji: '🍌', zone: 'sanatos' },
          { emoji: '🍭', zone: 'rar' },     { emoji: '🥤', zone: 'rar' },     { emoji: '🍟', zone: 'rar' }
        ]
      }
    },
    {
      id: 'siguranta', name: 'În siguranță', emoji: '✅', scene: 'oras',
      x: 83, y: 58,
      intro: 'Unele lucruri cer grijă. Ce e sigur și ce atingem doar cu un adult?',
      dd: {
        instruction: 'Trage fiecare lucru: sigur sau cu grijă.',
        zones: [
          { id: 'sigur', name: 'Sigur',    emoji: '✅' },
          { id: 'grija', name: 'Cu grijă', emoji: '⚠️' }
        ],
        items: [
          { emoji: '🪥', zone: 'sigur' }, { emoji: '🧼', zone: 'sigur' }, { emoji: '🚦', zone: 'sigur' },
          { emoji: '🔥', zone: 'grija' }, { emoji: '🔪', zone: 'grija' }, { emoji: '🔌', zone: 'grija' }
        ]
      }
    }
  ]
};

export default {
  id: 'explorare-viata',
  name: 'O zi bună',
  emoji: '🌟',
  desc: 'Emoții, alegeri sănătoase și siguranță',
  badge: 'Explorare',
  start(mount, ctx) { runEpisode(mount, ctx, EPISODE); }
};
