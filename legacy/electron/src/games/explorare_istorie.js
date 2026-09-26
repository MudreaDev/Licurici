// Episod de explorat — ISTORIE: „Călătorie în timp".
// Hartă (cetate) cu 3 opriri; la fiecare, o provocare trage-și-plasează dintr-o poveste:
// trecut vs prezent (obiecte de acasă și de comunicare) + recunoașterea simbolurilor țării.
// Reutilizează motorul de episoade (explore.js) și mecanica drag-drop (dragdrop.js).
import { runEpisode } from '../explore.js';

const EPISODE = {
  id: 'explorare-istorie',
  title: 'Călătorie în timp',
  mapScene: 'cetate',
  lead: 'Alege o oprire pe hartă.',
  outro: 'Ai călătorit prin timp! ⏳',
  stops: [
    {
      id: 'acasa', name: 'Acasă demult', emoji: '🕯️', scene: 'muzeu',
      x: 18, y: 70,
      intro: 'Bunicii trăiau altfel. Ce e din trecut și ce e de acum?',
      dd: {
        instruction: 'Trage fiecare lucru: din trecut sau de acum.',
        zones: [
          { id: 'trecut',  name: 'Trecut',  emoji: '⏳' },
          { id: 'prezent', name: 'Acum',    emoji: '💡' }
        ],
        items: [
          { emoji: '🕯️', zone: 'trecut' },  { emoji: '🐎', zone: 'trecut' }, { emoji: '🪶', zone: 'trecut' },
          { emoji: '🚗', zone: 'prezent' }, { emoji: '🖊️', zone: 'prezent' }, { emoji: '📱', zone: 'prezent' }
        ]
      }
    },
    {
      id: 'simboluri', name: 'Simbolurile țării', emoji: '🏰', scene: 'cetate',
      x: 50, y: 47,
      intro: 'Țara are simbolurile ei. Care e simbol și care e un obiect obișnuit?',
      dd: {
        instruction: 'Trage simbolurile țării separat de obiectele obișnuite.',
        zones: [
          { id: 'simbol', name: 'Simbol al țării', emoji: '🏛️' },
          { id: 'obiect', name: 'Obiect obișnuit', emoji: '🧸' }
        ],
        items: [
          { emoji: '🇷🇴', zone: 'simbol' }, { emoji: '👑', zone: 'simbol' }, { emoji: '🏰', zone: 'simbol' },
          { emoji: '🍎', zone: 'obiect' },  { emoji: '⚽', zone: 'obiect' }, { emoji: '🎈', zone: 'obiect' }
        ]
      }
    },
    {
      id: 'vesti', name: 'Cum trimiteau vești', emoji: '✉️', scene: 'muzeu',
      x: 82, y: 58,
      intro: 'Demult, veștile mergeau încet. Ce e din trecut și ce folosim acum?',
      dd: {
        instruction: 'Trage fiecare lucru: din trecut sau de acum.',
        zones: [
          { id: 'trecut',  name: 'Trecut',  emoji: '⏳' },
          { id: 'prezent', name: 'Acum',    emoji: '📺' }
        ],
        items: [
          { emoji: '📜', zone: 'trecut' },  { emoji: '✉️', zone: 'trecut' }, { emoji: '📻', zone: 'trecut' },
          { emoji: '📧', zone: 'prezent' }, { emoji: '📱', zone: 'prezent' }, { emoji: '💡', zone: 'prezent' }
        ]
      }
    }
  ]
};

export default {
  id: 'explorare-istorie',
  name: 'Călătorie în timp',
  emoji: '🏰',
  desc: 'Explorează trecutul: hartă cu opriri și provocări',
  badge: 'Explorare',
  start(mount, ctx) { runEpisode(mount, ctx, EPISODE); }
};
