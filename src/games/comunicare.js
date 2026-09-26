// Tablă de comunicare (tip PECS/AAC) — cea mai mare valoare în viața reală.
// Atingi simboluri → se adaugă în propoziție și aplicația le rostește. Fără greșeli.
import { AAC } from '../data/content.js';
import { el, clear, speak, speakSeq } from '../ui.js';
import { sfx } from '../audio.js';

export default {
  id: 'comunicare',
  name: 'Vorbește',
  emoji: '💬',
  desc: 'Spune ce vrei cu ajutorul imaginilor',
  badge: 'Comunicare',
  start(mount, ctx) {
    let sentence = []; // [{e,w}]

    const screen = el('div', { class: 'screen' });
    mount.appendChild(screen);
    screen.appendChild(el('h1', { text: '💬 Vorbește' }));
    screen.appendChild(el('p', { class: 'lead', text: 'Atinge imaginile ca să spui ce vrei.' }));

    // Banda propoziției
    const strip = el('div', { class: 'aac-strip' });
    const stripInner = el('div', { class: 'aac-strip-inner' });
    strip.appendChild(stripInner);
    const speakAll = el('button', { class: 'btn', title: 'Citește propoziția' }, '🔊');
    const back = el('button', { class: 'iconbtn', title: 'Șterge ultimul' }, '⌫');
    const clr = el('button', { class: 'iconbtn', title: 'Șterge tot' }, '🗑️');
    strip.appendChild(el('div', { class: 'aac-actions' }, speakAll, back, clr));
    screen.appendChild(strip);

    function renderStrip() {
      clear(stripInner);
      if (sentence.length === 0) {
        stripInner.appendChild(el('span', { class: 'aac-placeholder', text: 'Propoziția ta apare aici…' }));
        return;
      }
      sentence.forEach(item => {
        stripInner.appendChild(el('span', { class: 'aac-chip' },
          el('span', { class: 'e', text: item.e }),
          el('span', { class: 'w', text: item.w })
        ));
      });
    }
    renderStrip();

    speakAll.addEventListener('click', () => {
      if (sentence.length) speakSeq(sentence.map(s => s.w));
    });
    back.addEventListener('click', () => { sentence.pop(); sfx.tap(); renderStrip(); });
    clr.addEventListener('click', () => { sentence = []; sfx.tap(); renderStrip(); });

    // File de categorii
    const tabs = el('div', { class: 'aac-tabs' });
    const cardsWrap = el('div', { class: 'aac-cards' });
    screen.appendChild(tabs);
    screen.appendChild(cardsWrap);

    let activeCat = AAC[0];
    AAC.forEach(cat => {
      const tab = el('button', { class: 'aac-tab' },
        el('span', { class: 'e', text: cat.emoji }), el('span', { text: cat.cat }));
      tab.addEventListener('click', () => { activeCat = cat; renderTabs(); renderCards(); });
      tab._cat = cat;
      tabs.appendChild(tab);
    });

    function renderTabs() {
      [...tabs.children].forEach(t => t.classList.toggle('on', t._cat === activeCat));
    }
    function renderCards() {
      clear(cardsWrap);
      activeCat.words.forEach(word => {
        const card = el('button', { class: 'aac-card' },
          el('div', { class: 'e', text: word.e }),
          el('div', { class: 'w', text: word.w })
        );
        card.addEventListener('click', () => {
          sentence.push(word);
          sfx.tap();
          speak(word.w);       // rostește imediat cuvântul atins
          renderStrip();
        });
        cardsWrap.appendChild(card);
      });
    }
    renderTabs();
    renderCards();
  }
};
