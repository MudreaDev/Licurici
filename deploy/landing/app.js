import { createCarousel } from './carousel.mjs';
const screens = {
  home: { number: '01', title: 'Un început prietenos', description: '„Drumul de azi” aduce activitățile la un loc. Copilul descoperă lumea jocurilor, pas cu pas, cu Licurici alături.', alt: 'Ecranul principal cu Drumul de azi' },
  emotions: { number: '02', title: 'Un nume pentru fiecare emoție', description: 'Cum se simte personajul? Copilul privește expresiile și alege un răspuns, exersând recunoașterea emoțiilor într-un context simplu.', alt: 'Jocul Cum se simte, cu fețe pictate și expresii diferite' },
  language: { number: '03', title: 'Cuvintele prind înțeles', description: 'Pe, sub sau lângă? Jocul „Unde e ursulețul?” leagă cuvintele de imagini și îl ajută pe copil să exerseze relațiile spațiale.', alt: 'Jocul Unde e ursulețul, cu obiecte pictate pentru relații spațiale' },
  tower: { number: '04', title: 'Încă un inel. Încă o reușită.', description: 'În „Turnul”, copilul compară mărimi și așază inelele în ordine. O activitate vizuală, cu pași mici și obiecte ușor de recunoscut.', alt: 'Jocul Turnul, cu inele colorate de mărimi diferite' },
  mirror: { number: '05', title: 'Privește. Încearcă. Repetă.', description: 'Licurici arată o atingere pe fața unui prieten. Copilul o repetă în oglindă, exersând imitația, atenția și orientarea pe propriul corp.', alt: 'Jocul Oglinda cu două portrete pictate și mascota Licurici' },
  painting: { number: '06', title: 'Ascultăm și dăm culoare', description: 'O instrucțiune simplă, o culoare și un obiect de pictat. „Colorează ce auzi” aduce împreună înțelegerea limbajului și gesturile precise.', alt: 'Jocul Colorează ce auzi cu paletă și obiecte de colorat' },
};
const image = document.querySelector('#screen-image');
const dialog = document.querySelector('#image-dialog');
const dialogImage = document.querySelector('#dialog-image');
const keys = Object.keys(screens);
const slider = document.querySelector('#descopera');
const toggle = document.querySelector('#autoplay');
const motion = matchMedia('(prefers-reduced-motion: reduce)');
let userPaused = motion.matches;
const carousel = createCarousel({ count: keys.length, onChange(index, announce) {
    const key = keys[index];
    const screen = screens[key];
    image.src = `assets/${key}.png`;
    image.alt = screen.alt;
    if (!motion.matches) image.animate([{opacity:.35,transform:'translateX(8px)'},{opacity:1,transform:'translateX(0)'}], {duration:350,easing:'ease-out'});
    document.querySelector('#screen-number').textContent = `${screen.number} / 06`;
    document.querySelector('#screen-title').textContent = screen.title;
    document.querySelector('#screen-description').textContent = screen.description;
    for (const other of document.querySelectorAll('[data-screen]')) other.setAttribute('aria-pressed', String(other.dataset.screen === key));
    if (announce) document.querySelector('#screen-announcement').textContent = screen.title;
  }, onState({running, paused}) {
    userPaused = paused;
    toggle.textContent = paused ? 'Pornește prezentarea' : 'Pauză';
    toggle.setAttribute('aria-label', paused ? 'Pornește prezentarea automată' : 'Oprește prezentarea automată');
    document.querySelector('#autoplay-status').textContent = running ? 'Prezentare automată · 7 secunde / ecran' : paused ? 'Prezentare oprită · Explorează în ritmul tău' : 'Pauză cât explorezi';
  },
});
carousel.block('outside', true);
carousel.pause(motion.matches);
new IntersectionObserver(([entry]) => carousel.block('outside', !entry.isIntersecting), {threshold:.2}).observe(document.querySelector('.showcase-stage'));
document.addEventListener('visibilitychange', () => carousel.block('hidden', document.hidden));
carousel.block('hidden', document.hidden);
const preview = document.querySelector('#enlarge');
preview.addEventListener('pointerenter', event => { if (event.pointerType === 'mouse') carousel.block('hover', true); });
preview.addEventListener('pointerleave', () => carousel.block('hover', false));
slider.addEventListener('focusin', event => { if (event.target !== toggle) carousel.block('focus', true); });
slider.addEventListener('focusout', event => { if (!slider.contains(event.relatedTarget)) carousel.block('focus', false); });
toggle.addEventListener('click', () => { carousel.block('focus', false); carousel.pause(!userPaused); });
motion.addEventListener('change', event => { if (event.matches) carousel.pause(true); });
for (const button of document.querySelectorAll('[data-screen]')) {
  button.addEventListener('click', () => carousel.select(keys.indexOf(button.dataset.screen)));
}
document.querySelector('#previous-screen').addEventListener('click', () => carousel.step(-1));
document.querySelector('#next-screen').addEventListener('click', () => carousel.step(1));
for (const link of document.querySelectorAll('[data-preview]')) {
  link.addEventListener('click', () => carousel.select(keys.indexOf(link.dataset.preview)));
}
// Preload only the next gallery assets; no third-party requests.
for (const key of keys.slice(1)) { const preload = new Image(); preload.src = `assets/${key}.png`; }
document.querySelector('#enlarge').addEventListener('click', () => {
  carousel.block('dialog', true);
  dialogImage.src = image.src;
  dialogImage.alt = image.alt;
  document.querySelector('#dialog-title').textContent = document.querySelector('#screen-title').textContent;
  dialog.showModal();
});
document.querySelector('#close-dialog').addEventListener('click', () => dialog.close());
dialog.addEventListener('close', () => carousel.block('dialog', false));
dialog.addEventListener('click', (event) => { if (event.target === dialog) {
  const rect = dialog.getBoundingClientRect();
  if (event.clientX < rect.left || event.clientX > rect.right || event.clientY < rect.top || event.clientY > rect.bottom) dialog.close();
}});
