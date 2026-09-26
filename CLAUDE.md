# Licurici — context pentru Claude (citește întâi)

Aplicație desktop educativă (Electron, Windows + macOS) pentru **grădiniță + clasele 1-4**
(curriculum Moldova/România), 100% **offline**. Fost „Curcubeu". Limba: română (+ engleză ca materie).

## Rulare & build
```bash
npm install
npm start                # rulează aplicația
npm run dist:mac         # → dist/Licurici-1.0.0-universal.dmg
npm run dist:win         # → dist/Licurici Setup 1.0.0.exe  (electron-builder descarcă singur wine)
```
După build, în `dist/` păstrează doar `.dmg` și `.exe` (restul sunt intermediare).

## Arhitectură (src/)
- `index.html` → `app.js` (router: home, aventura, progres, setari, despre, joc). Bară de sus fixă.
- `games/registry.js` — TOATE jocurile + `META` (materie + clase, string compact `G1234`). `gamesForGrade(grade)` grupează pe materii.
- `grades.js` — GRADES (grădiniță, clasa1-4) + SUBJECTS (8 materii) + `gradeTier()`.
- `engine.js` — motorul „alege răspunsul" (învățare fără eroare, recompensă, `speakSeq`, final nivel-aware). `ui.js` `showFinish` pt jocurile custom.
- **`difficulty.js` — MOTOR CENTRAL de dificultate.** Un `tier()` numeric (Aventură: NEMĂRGINIT, crește la fiecare 4 niveluri; joc liber: din clasă + ușor/mediu) conduce toată scalarea. Derivă: `optionCount()` (2→5 variante de răspuns), `distractors()`, `roundCount()` (5→8 runde), `numMax()` (plafoane numerice). `engine.js` aplică AUTOMAT optionCount (taie variantele afișate, păstrând corectul) + roundCount (taie rundele) la TOATE jocurile „alege răspunsul" → fiecare nivel e o variantă tot mai grea. Opt-out: `spec.fixedChoices`/`r.fixedChoices` (ex. comparam — opțiunile sunt grupele; intrusul — format fix) și `spec.fixedRounds`. Jocurile generează GENEROS variante (numChoices default 5; distractori sample 4); motorul taie după tier. Matematica: numere mai mari cu tier-ul + sprijin vizual (obiecte) doar la numere mici (concret→abstract). `store.js` — setări + progres + stats + Aventură (localStorage).
- `levels.js` + Aventura (app.js) — niveluri NESFÂRȘITE generate procedural, hartă cu lumi, stele.
- **`gfx.js`** — înlocuiește AUTOMAT orice emoji din DOM cu ilustrația **OpenMoji** din `art/openmoji/` (SVG cartoon). NU pune imagini manual; scrie emoji în cod și parserul le transformă. Emoji nou → rulează `scratchpad/get-openmoji.mjs` (sau echivalent) ca să descarce SVG-ul.
- `music.js` — muzică ambient generată în cod. `audio.js` — sunete. Volume: `store` musicVol/sfxVol/voiceVol (0..1, mediu=0.5).
- **Voce**: clipuri neuronale în `audio-ro/*.mp3` + `manifest.js`. Generator: `tools/gen-voice.mjs` (edge-tts; RO `ro-RO-AlinaNeural` rate +0%, EN `en-US-JennyNeural`). `ui.js speak(text)` redă clipul din manifest. Adaugi text nou de rostit → adaugă-l în generator și rulează `node tools/gen-voice.mjs` (incremental).
- `mascot.js` — licuriciul SVG. `styles.css` — design (tokens, Fredoka, cartoon).
- **Explorare** (episoade stil „Autobuzul magic"): `explore.js` (motor: hartă cu opriri + scene + poveste),
  `dragdrop.js` (mecanica trage-și-plasează reutilizabilă, pointer events, fără pedeapsă),
  `scenes.js` (fundaluri ILUSTRATE în cod — SVG cartoon per scenă: ferma/anotimpuri/hrana/reciclare/harta).
  Episoade: `games/explorare_stiinte.js` (Științe, 4 opriri) și `games/explorare_istorie.js` (Istorie, 3 opriri:
  trecut/prezent, simboluri, comunicare). `ep.mapScene` alege fundalul hărții. `dragdrop.js` exportă și
  `runDragGame(mount, ctx, spec)` — joc drag-drop de sine stătător cu final+stele (ex. `games/grupam.js`).

## Ce e gata
Sistem de clase + filtrare pe materii · Aventură (niveluri infinite, dificultate procedurală) · statistici · 44 jocuri
pe 8 materii (Română, Matematică, Timp&bani, Științe, Istorie, Forme&logică, Emoții, Engleză) ·
**3 episoade de explorat (Științe, Istorie, Emoții&viață) în secțiune „Explorare" pe home, trage-și-plasează, fundaluri ilustrate, probleme cu text, joc de grupat, gramatică+plural (cls 3-4), nume copil în Setări** ·
grafică OpenMoji peste tot (fără emoji de sistem) · 3 cursoare volum · voce naturală RO+EN ·
muzică ambient · design cartoon.

## Următorii pași (cerute de utilizator)
1. ✅ **Episoade de explorat** stil *Autobuzul magic* — LIVRAT pentru Științe („Autobuzul lui Licurici · Călătorie în natură", hartă cu 4 opriri).
2. ✅ **Mecanici trage-și-plasează** — LIVRAT (`dragdrop.js`, folosit în episoade; extensibil la jocuri de sortare).
3. ✅ **Fundaluri ilustrate per scenă** — LIVRAT (`scenes.js`, SVG cartoon).
   → LIVRAT și episod Istorie („Călătorie în timp") + joc drag-drop de sine stătător (`grupam`).
4. ✅ **Probleme cu text** la matematică — LIVRAT (`games/probleme.js`, cls 2-4).
   ✅ **Română avansată cls 3-4** — LIVRAT: `games/gramatica.js` (substantiv/verb/adjectiv) + `games/plural.js` (singular/plural), date în `data/romana.js`.
   → De extins (idei): episod Română de explorat; sinonime; texte cu întrebări de înțelegere.
5. ✅ **Build .dmg + .exe FĂCUT** (o singură dată, la final): `dist/Licurici-1.0.0-universal.dmg` (176M) + `dist/Licurici Setup 1.0.0.exe` (169M). Nesemnate.
6. Semnarea instalerelor (certificate Apple/Microsoft) pentru distribuție fără avertismente.

## Convenții
- Prietenos cu autismul: o sarcină/ecran, ținte mari, fără pedeapsă la greșeală, culori calme, „modul calm".
- Tot procedural/offline (spirit .kkrieger): fără fișiere noi unde se poate.
- Comunicare cu utilizatorul: română, concisă.
