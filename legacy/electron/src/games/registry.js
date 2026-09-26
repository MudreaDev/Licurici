// Registrul jocurilor — fiecare joc are: materie (subject) + clasele potrivite (grades).
// Meniul se grupează pe materii și se filtrează după clasa aleasă.
import potriveste from './potriveste.js';
import emotii from './emotii.js';
import sortare from './sortare.js';
import secventa from './secventa.js';
import numaram from './numaram.js';
import modele from './modele.js';
import memorie from './memorie.js';
import social from './social.js';
import comunicare from './comunicare.js';
import respira from './respira.js';
import alfabetul from './alfabetul.js';
import adunam from './adunam.js';
import scadem from './scadem.js';
import inmultim from './inmultim.js';
import impartim from './impartim.js';
import culori from './culori.js';
import forme from './forme.js';
import ceasul from './ceasul.js';
import comparam from './comparam.js';
import ordonam from './ordonam.js';
import intrusul from './intrusul.js';
import perechi from './perechi.js';
import opuse from './opuse.js';
import silabe from './silabe.js';
import cuvinte from './cuvinte.js';
import zeci from './zeci.js';
import semne from './semne.js';
import lipsa from './lipsa.js';
import tabla from './tabla.js';
import bani from './bani.js';
import habitate from './habitate.js';
import anotimpuri from './anotimpuri.js';
import corpul from './corpul.js';
import engleza from './engleza.js';
import simboluri from './simboluri.js';
import trecut from './trecut.js';
import personalitati from './personalitati.js';
import explorareStiinte from './explorare_stiinte.js';
import explorareIstorie from './explorare_istorie.js';
import explorareViata from './explorare_viata.js';
import probleme from './probleme.js';
import grupam from './grupam.js';
import gramatica from './gramatica.js';
import plural from './plural.js';
import { SUBJECTS, subjectInfo } from '../grades.js';

const ALL = [
  potriveste, emotii, sortare, secventa, numaram, modele, memorie, social, comunicare,
  respira, alfabetul, adunam, scadem, inmultim, impartim, culori, forme, ceasul, comparam,
  ordonam, intrusul, perechi, opuse, silabe, cuvinte, zeci, semne, lipsa, tabla, bani,
  habitate, anotimpuri, corpul, engleza, simboluri, trecut, personalitati,
  explorareStiinte, explorareIstorie, explorareViata, probleme, grupam, gramatica, plural
];

// materie + clase (G=grădiniță, 1..4). Compact.
const GC = { G: 'gradinita', 1: 'clasa1', 2: 'clasa2', 3: 'clasa3', 4: 'clasa4' };
const expand = (s) => s.split('').map(c => GC[c]);
const META = {
  alfabetul: ['romana', 'G12'], silabe: ['romana', '123'], cuvinte: ['romana', '1234'], opuse: ['romana', 'G1234'],
  gramatica: ['romana', '34'], plural: ['romana', '234'],
  numaram: ['matematica', 'G1'], ordonam: ['matematica', 'G1'], adunam: ['matematica', '123'],
  scadem: ['matematica', '123'], zeci: ['matematica', '12'], semne: ['matematica', '123'],
  lipsa: ['matematica', '123'], comparam: ['matematica', 'G1'], inmultim: ['matematica', '234'],
  tabla: ['matematica', '234'], impartim: ['matematica', '34'],
  probleme: ['matematica', '234'],
  ceasul: ['timp-bani', '1234'], bani: ['timp-bani', '1234'],
  culori: ['forme', 'G1'], forme: ['forme', 'G12'], modele: ['forme', 'G12'], potriveste: ['forme', 'G1'],
  intrusul: ['forme', 'G1234'], perechi: ['forme', 'G1234'], memorie: ['forme', 'G1234'], grupam: ['forme', 'G1234'],
  habitate: ['stiinte', 'G1234'], anotimpuri: ['stiinte', 'G1234'], corpul: ['stiinte', 'G1234'], sortare: ['stiinte', 'G1234'],
  'explorare-stiinte': ['stiinte', 'G1234'],
  emotii: ['emotii', 'G1234'], social: ['emotii', 'G1234'], secventa: ['emotii', 'G12'],
  'explorare-viata': ['emotii', 'G1234'],
  comunicare: ['emotii', 'G1'], respira: ['emotii', 'G1234'],
  engleza: ['engleza', '1234'],
  simboluri: ['istorie', 'G1234'], trecut: ['istorie', 'G1234'], personalitati: ['istorie', '34'],
  'explorare-istorie': ['istorie', 'G1234']
};

export const GAMES = ALL.map(g => {
  const [subject, gc] = META[g.id] || ['forme', 'G1234'];
  const color = (subjectInfo(subject) || {}).color || '#5b9bb5';
  return { ...g, subject, grades: expand(gc), color };
});
export const GAME_MAP = Object.fromEntries(GAMES.map(g => [g.id, g]));

// Jocurile pentru o clasă, grupate pe materii (în ordinea SUBJECTS).
export function gamesForGrade(gradeId) {
  const out = [];
  for (const sub of SUBJECTS) {
    const games = GAMES.filter(g => g.subject === sub.id && g.grades.includes(gradeId));
    if (games.length) out.push({ subject: sub, games });
  }
  return out;
}
