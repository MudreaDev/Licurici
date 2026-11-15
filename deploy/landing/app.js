import Splide from './vendor/splide.esm.js';
const screens = {
  home: { number: '01', title: 'Un început prietenos', description: '„Drumul de azi” aduce activitățile la un loc. Copilul descoperă lumea jocurilor, pas cu pas, cu Licurici alături.', alt: 'Ecranul principal cu Drumul de azi' },
  emotions: { number: '02', title: 'Un nume pentru fiecare emoție', description: 'Cum se simte personajul? Copilul privește expresiile și alege un răspuns, exersând recunoașterea emoțiilor într-un context simplu.', alt: 'Jocul Cum se simte, cu fețe pictate și expresii diferite' },
  language: { number: '03', title: 'Cuvintele prind înțeles', description: 'Pe, sub sau lângă? Jocul „Unde e ursulețul?” leagă cuvintele de imagini și îl ajută pe copil să exerseze relațiile spațiale.', alt: 'Jocul Unde e ursulețul, cu obiecte pictate pentru relații spațiale' },
  tower: { number: '04', title: 'Încă un inel. Încă o reușită.', description: 'În „Turnul”, copilul compară mărimi și așază inelele în ordine. O activitate vizuală, cu pași mici și obiecte ușor de recunoscut.', alt: 'Jocul Turnul, cu inele colorate de mărimi diferite' },
  mirror: { number: '05', title: 'Privește. Încearcă. Repetă.', description: 'Licurici arată o atingere pe fața unui prieten. Copilul o repetă în oglindă, exersând imitația, atenția și orientarea pe propriul corp.', alt: 'Jocul Oglinda cu două portrete pictate și mascota Licurici' },
  painting: { number: '06', title: 'Ascultăm și dăm culoare', description: 'O instrucțiune simplă, o culoare și un obiect de pictat. „Colorează ce auzi” aduce împreună înțelegerea limbajului și gesturile precise.', alt: 'Jocul Colorează ce auzi cu paletă și obiecte de colorat' },
};
const keys = Object.keys(screens);
const dialog = document.querySelector('#image-dialog');
const motion = matchMedia('(prefers-reduced-motion: reduce)');
const root = document.querySelector('#app-carousel');
const carousel = new Splide(root, {
  type: 'loop', perPage: 1, perMove: 1, gap: 24, speed: 650,
  autoplay: true, interval: 5000, pauseOnHover: false, pauseOnFocus: true,
  resetProgress: true, arrows: false, pagination: false, keyboard: 'focused',
  drag: true, snap: true, live: true,
  reducedMotion: { speed: 0, rewindSpeed: 0, autoplay: 'pause' },
  i18n: { prev: 'Ecranul anterior', next: 'Ecranul următor', first: 'Primul ecran', last: 'Ultimul ecran', slideX: 'Mergi la ecranul %s', pageX: 'Mergi la pagina %s', play: 'Pornește prezentarea automată', pause: 'Oprește prezentarea automată', carousel: 'carusel', slide: 'ecran', select: 'Alege ecranul', slideLabel: '%s din %s' },
});
let manualPause = motion.matches;
let inView = false;
const status = document.querySelector('#autoplay-status');
function updateSelection() {
  const key = keys[carousel.index];
  for (const button of document.querySelectorAll('[data-screen]')) button.setAttribute('aria-pressed', String(button.dataset.screen === key));
}
carousel.on('mounted moved', updateSelection);
carousel.on('autoplay:play', () => { status.textContent = 'Prezentare automată · 5 secunde / ecran'; });
carousel.on('autoplay:pause', () => { status.textContent = 'Prezentare în pauză · Glisează sau alege un ecran'; });
carousel.mount();
const autoplay = carousel.Components.Autoplay;
function syncVisibility() {
  if (document.hidden || !inView || dialog.open || manualPause) autoplay.pause();
  else if (!root.contains(document.activeElement)) autoplay.play();
}
new IntersectionObserver(([entry]) => { inView = entry.isIntersecting; syncVisibility(); }, {threshold:.15}).observe(root);
document.addEventListener('visibilitychange', syncVisibility);
root.addEventListener('mouseleave', syncVisibility);
root.addEventListener('focusout', () => queueMicrotask(syncVisibility));
document.querySelector('#autoplay').addEventListener('click', () => { manualPause = autoplay.isPaused(); });
motion.addEventListener('change', event => { if (event.matches) { manualPause = true; autoplay.pause(); } });
document.querySelector('#previous-screen').addEventListener('click', () => carousel.go('<'));
document.querySelector('#next-screen').addEventListener('click', () => carousel.go('>'));
for (const button of document.querySelectorAll('[data-screen]')) button.addEventListener('click', () => carousel.go(keys.indexOf(button.dataset.screen)));
for (const link of document.querySelectorAll('[data-preview]')) link.addEventListener('click', () => carousel.go(keys.indexOf(link.dataset.preview)));
root.addEventListener('click', event => {
  const button = event.target.closest('[data-enlarge]');
  if (!button) return;
  const key = button.dataset.enlarge;
  const image = document.querySelector('#dialog-image');
  image.src = 'assets/' + key + '.png'; image.alt = screens[key].alt;
  document.querySelector('#dialog-title').textContent = screens[key].title;
  autoplay.pause(); dialog.showModal();
});
document.querySelector('#close-dialog').addEventListener('click', () => dialog.close());
dialog.addEventListener('close', syncVisibility);
dialog.addEventListener('click', event => {
  if (event.target !== dialog) return;
  const rect = dialog.getBoundingClientRect();
  if (event.clientX < rect.left || event.clientX > rect.right || event.clientY < rect.top || event.clientY > rect.bottom) dialog.close();
});

const ambientToggle = document.querySelector('#ambient-toggle');
let ambientPaused = motion.matches;
function updateAmbient() {
  document.body.classList.toggle('ambient-paused', ambientPaused);
  ambientToggle.setAttribute('aria-pressed', String(ambientPaused));
  ambientToggle.textContent = ambientPaused ? 'Pornește fundalul animat' : 'Oprește fundalul animat';
  ambientToggle.disabled = motion.matches;
  if (motion.matches) ambientToggle.textContent = 'Fundal static · mișcare redusă';
}
ambientToggle.addEventListener('click', () => { ambientPaused = !ambientPaused; updateAmbient(); });
motion.addEventListener('change', event => { ambientPaused = event.matches; updateAmbient(); });
updateAmbient();
