const screens = {
  home: { number: '01', title: 'Un început prietenos', description: '„Drumul de azi” aduce activitățile la un loc. Copilul descoperă lumea jocurilor, pas cu pas, cu Licurici alături.', alt: 'Ecranul principal cu Drumul de azi' },
  emotions: { number: '02', title: 'Un nume pentru fiecare emoție', description: 'Cum se simte personajul? Copilul privește expresiile și alege un răspuns, exersând recunoașterea emoțiilor într-un context simplu.', alt: 'Jocul Cum se simte, cu fețe pictate și expresii diferite' },
  language: { number: '03', title: 'Cuvintele prind înțeles', description: 'Pe, sub sau lângă? Jocul „Unde e ursulețul?” leagă cuvintele de imagini și îl ajută pe copil să exerseze relațiile spațiale.', alt: 'Jocul Unde e ursulețul, cu obiecte pictate pentru relații spațiale' },
  tower: { number: '04', title: 'Încă un inel. Încă o reușită.', description: 'În „Turnul”, copilul compară mărimi și așază inelele în ordine. O activitate vizuală, cu pași mici și obiecte ușor de recunoscut.', alt: 'Jocul Turnul, cu inele colorate de mărimi diferite' },
};
const image = document.querySelector('#screen-image');
const dialog = document.querySelector('#image-dialog');
const dialogImage = document.querySelector('#dialog-image');
for (const button of document.querySelectorAll('[data-screen]')) {
  button.addEventListener('click', () => {
    const key = button.dataset.screen;
    const screen = screens[key];
    if (!screen) return;
    image.src = `assets/${key}.png`;
    image.alt = screen.alt;
    document.querySelector('#screen-number').textContent = `${screen.number} / 04`;
    document.querySelector('#screen-title').textContent = screen.title;
    document.querySelector('#screen-description').textContent = screen.description;
    for (const other of document.querySelectorAll('[data-screen]')) other.setAttribute('aria-pressed', String(other === button));
    document.querySelector('#screen-announcement').textContent = screen.title;
  });
}
document.querySelector('#enlarge').addEventListener('click', () => {
  dialogImage.src = image.src;
  dialogImage.alt = image.alt;
  document.querySelector('#dialog-title').textContent = document.querySelector('#screen-title').textContent;
  dialog.showModal();
});
document.querySelector('#close-dialog').addEventListener('click', () => dialog.close());
dialog.addEventListener('click', (event) => { if (event.target === dialog) {
  const rect = dialog.getBoundingClientRect();
  if (event.clientX < rect.left || event.clientX > rect.right || event.clientY < rect.top || event.clientY > rect.bottom) dialog.close();
}});
