# ✨ Licurici

Aplicație desktop (Windows + macOS) cu jocuri educative pentru **copii** — pregătire de
școală (litere, numere, adunare/scădere/înmulțire/împărțire, ceas, comparații), plus
culori, forme, emoții, comunicare și liniște. Potrivită pentru cei mici și pentru copiii
cu autism.

Jocurile sunt **generate pe loc** (din șabloane + conținut aleator) — nicicând repetitive.
Totul funcționează **offline**. Datele rămân doar pe calculator.

---

## Jocurile (23), grupate pe secțiuni

**Litere & numere (pregătire de școală)**
| Joc | Ce antrenează |
|-----|---------------|
| 🔤 **Alfabetul** | Litere: obiect→literă, literă→obiect, MARE→mică |
| 🔢 **Numărăm** | Numărat, numere |
| 🔢 **În ordine** | Ordonarea numerelor de la mic la mare |
| ➕ **Adunăm** | Adunare cu sprijin vizual + ecuație citită |
| ➖ **Scădem** | Scădere cu obiecte |
| ✖️ **Înmulțim** | Înmulțire ca grupe egale |
| ➗ **Împărțim** | Împărțire în grupe egale |
| ⚖️ **Comparăm** | Mai mult / mai puțin / la fel |
| 🕐 **Ceasul** | Citirea orei pe un ceas analog (SVG) |

**Culori, forme & logică**
| Joc | Ce antrenează |
|-----|---------------|
| 🎨 **Culori** | Recunoașterea culorilor (nume ↔ culoare) |
| 🔷 **Forme** | Recunoașterea formelor |
| 🔁 **Modele** | Gândire logică, continuarea șirului |
| 🧩 **Potrivește** | Atenție vizuală, potrivire |
| 🔎 **Intrusul** | Găsește ce nu se potrivește |
| 🃏 **Perechi** | Memorie — întoarce cărțile și găsește perechile |
| 🧠 **Memorie** | Memorie de lucru (tip „Simon") |

**Lumea din jur**
| Joc | Ce antrenează |
|-----|---------------|
| 😊 **Emoții** | Recunoașterea emoțiilor (față ↔ situație) |
| ↔️ **Opuse** | Cuvinte cu sens opus (mare↔mic, zi↔noapte) |
| 🗂️ **Sortare** | Categorii / formarea conceptelor |
| 📋 **Ce urmează?** | Ordonarea pașilor rutinei (independență) |
| 🤝 **Situații** | Abilități sociale |

**Comunică & liniște**
| Joc | Ce antrenează |
|-----|---------------|
| 💬 **Vorbește** | Tablă de comunicare PECS/AAC — app-ul rostește cuvintele |
| 🫧 **Respiră** | Autoreglare / colț de liniște |

Fiecare joc își **generează conținutul aleator** din băncile din `src/data/content.js` (și
procedural pentru matematică), din mai multe șabloane de întrebări → mereu ceva nou, nicicând
repetitiv. Ca să adaugi variație, extinzi listele (emoții, rutine, categorii, alfabet, culori…).
Potrivit și pentru copii mici, la grădiniță/pregătire de școală — nu doar pentru autism.

---

## Cum rulezi

Ai nevoie de [Node.js](https://nodejs.org) instalat.

```bash
cd Curcubeu
npm install        # descarcă Electron (o singură dată)
npm start          # pornește aplicația
```

## Voce română naturală (offline)

Toate replicile sunt **pre-generate ca fișiere audio** cu vocea **neuronală** Microsoft
**`ro-RO-AlinaNeural`** (feminină, blândă, naturală — „Friendly, Positive") și **incluse în
aplicație** (`src/audio-ro/`, 330 clipuri `.mp3`, ~6 MB; inclusiv numerele 0–100 și
operatorii, ca ecuațiile să fie citite natural). Astfel vocea sună natural
românește **fără internet** și **fără să depindă** de vocile din sistemul utilizatorului
(la fel pe Windows).

Vocile neuronale se obțin **gratuit, fără cheie API**, prin `edge-tts`. Internetul e nevoie
DOAR la generare — aplicația finală e complet offline. Ca să adaugi/regenerezi replici:

```bash
python3 -m pip install --user edge-tts
node tools/gen-voice.mjs
```

Poți schimba vocea (ex. `ro-RO-EmilNeural` — masculină) sau ritmul editând `VOICE`/`RATE`
în `tools/gen-voice.mjs`.

## Cum faci instalerul (build nativ)

```bash
npm run dist:win   # → dist/…Setup.exe   (Windows, x64 + arm64)
npm run dist:mac   # → dist/…universal.dmg (macOS Intel + Apple Silicon)
npm run dist:all   # ambele
```

Rezultatele apar în folderul `dist/`. Iconițele sunt în `assets/`.

> **Instalerele sunt deja construite** în `dist/`:
> - `Curcubeu-1.0.0-universal.dmg` (macOS)
> - `Curcubeu Setup 1.0.0.exe` (Windows)
>
> Nu sunt semnate digital (fără certificat plătit Apple/Microsoft), deci la prima
> deschidere sistemul poate cere confirmare: pe macOS → click-dreapta → *Open*; pe
> Windows → *More info* → *Run anyway*. Pentru distribuție fără avertismente e nevoie de
> semnare cu certificat. Alternativ, `.github/workflows/build.yml` construiește ambele
> instalere automat pe GitHub Actions (runnere native).

---

## Structura

```
Curcubeu/
├─ main.js            proces principal Electron (fereastra)
├─ preload.js         punte sigură main ↔ interfață
├─ package.json       scripturi + config electron-builder
├─ assets/            iconițe (png / ico / icns)
└─ src/
   ├─ index.html
   ├─ styles.css      design calm, ținte mari, „reduce motion"
   ├─ app.js          router, bară de sus constantă, setări
   ├─ store.js        setări + progres (localStorage)
   ├─ audio.js        sunete blânde generate în cod + notă memorie
   ├─ ui.js           helpere DOM, citire cu voce (RO), confetti, final
   ├─ engine.js       motor „alege răspunsul" (învățare fără eroare)
   ├─ data/content.js băncile de conținut
   └─ games/          câte un fișier per joc + registry.js
```

### Cum adaugi un joc nou
1. Creează `src/games/numejoc.js` care exportă `{ id, name, emoji, desc, badge, start(mount, ctx) }`.
   - Pentru jocuri „alege răspunsul", folosește `runLesson(...)` din `engine.js`.
2. Adaugă-l în `src/games/registry.js`.
Gata — apare automat în meniu.

---

## Principii de design (din cele mai bune practici mondiale)

Construit după framework-uri recunoscute: **ABA, TEACCH, PECS, Social Stories, Zones of
Regulation, PRT**. Reguli aplicate în cod:

- **O singură sarcină pe ecran**, 2–3 variante, ținte mari (≥ 60px), spațiere generoasă.
- **Recompensă imediată** (< 1s) la răspuns corect; laudă și pentru efort.
- **Fără pedeapsă la greșeală** — nu blocăm, fără roșu alarmant, fără „Greșit!".
- **Învățare fără eroare**: după greșeli, estompăm distractorii și evidențiem tot mai clar
  răspunsul corect, ca fiecare încercare să se termine cu succes.
- **Culori calme**, saturație redusă; temă „stimulare redusă" opțională.
- **Sunet și mișcare opționale**; respectă `prefers-reduced-motion`.
- **Navigație identică și fixă** pe fiecare ecran (Acasă / Setări mereu în același loc).
- **Text literal**, sans-serif, fără metafore/ironie; **citire cu voce** în română.
- **Profil senzorial** salvat: sunet, animații, stimulare redusă, text mare, dificultate.

Detaliile complete ale cercetării sunt în `DESIGN.md`.
