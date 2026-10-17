# Licurici — instrucțiuni pentru Codex (continuarea lucrului)

Scris pe 16.10.2026, la predarea proiectului de la Claude către Codex. **Fișier comun:** îl citesc și Claude
(prin `CLAUDE.md`) și Codex (prin `AGENTS.md`); cine lucrează îi actualizează secțiunea „1. Starea de acum” la final. Fișierul spune **ce e făcut, ce rămâne și
exact cum se continuă** — în primul rând generarea imaginilor, apoi restul. Citește-l întreg o dată, apoi lucrează
pe pași, în ordine.

---

## 0. Reguli (obligatorii)

1. **Sursa unică de adevăr este [README.md](README.md).** Citește întâi **§0.1** (unde am rămas), **§0.0** (ce are de făcut
   utilizatorul) și §22 (ghid de lucru). La finalul fiecărei sesiuni actualizează §0.1, §0.0 (bifează ce s-a făcut,
   adaugă ce îi revine utilizatorului, linia de progres din §21) și, dacă e cazul, §16 / §21.
2. **Comunicarea cu utilizatorul: în română, concis.**
3. **Commit-uri:** mesaje simple, convenționale, în română fără diacritice (ex. `feat(art): ...`, `fix(games): ...`),
   **fără nicio atribuire sau mențiune despre unelte de AI** (fără `Co-Authored-By`, fără „generated with…").
4. **Ramuri:** se lucrează pe `feat/fundatia-terapeutica`; după fiecare commit se urcă **pe ambele**:
   ```bash
   git push origin feat/fundatia-terapeutica
   git push origin feat/fundatia-terapeutica:main
   ```
   (`main` e ramura de producție a proiectului Vercel; utilizatorul a cerut ca `main` să fie la zi.)
5. **Proiectul țintă:** aplicație **Flutter** pentru copii (doar landscape) + panou Flutter Web + backend NestJS /
   PostgreSQL / Redis / BullMQ în Docker. Codul din `legacy/electron/` e doar prototip de referință — nu se mai
   lucrează acolo. Orice tehnologie nouă → ADR în `docs/adr/`; orice dată nouă despre copil → README §11 + §13.
6. **Grafică (ADR-028 + cererea utilizatorului din 16.10):** toate imaginile din jocuri se fac cu **Codex**
   (ilustrații pictate, stil de carte pentru copii, paleta pastel). Desenele „din cod” făcute de Claude rămân doar
   **rezervă** până există imaginea pictată. Fără Rive, fără Unity.
7. **Nu crea conturi și nu introduce parole pe site-uri publice** (ex. panoul de pe Vercel); testele cap-coadă online
   le face utilizatorul.
8. Înainte de commit: testele trebuie să treacă (vezi §4). Python pe acest calculator se rulează cu **`py`**, nu `python`.
   În Git Bash, pentru argumente care încep cu `/` (ex. `--dart-define=API_URL=/api/v1`), pune `MSYS_NO_PATHCONV=1`.

---

## 1. Starea de acum (16.10.2026, seara)

- **109 jocuri** în aplicație; toate cele 12 jocuri „frate” gata (Turnul, Adu-mi, Pune ursulețul, Colorează ce auzi,
  Memorie cu sunete, Oglinda și cele 6 din sesiunea 11). Vocea: 2763/2763 fraze cu clip (`edge-tts`, vezi §6).
- **Teste:** nucleu (`packages/licurici_core`) 652, aplicația copilului 377 (+14 capturi „pictat” sărite fără `SHOTS`),
  panou 36, versiunea Vercel 7 — toate trec.
- **Vercel (versiunea de test):** proiectul `licurici-panou` e online la **https://licurici-panou.vercel.app**,
  ramura `main`, Blob legat (`/api/v1/health` → `{"ok":true,"storage":"blob"}`). Cod: `deploy/vercel/`, ghid:
  `docs/deploy-vercel.md`. Fiecare push pe `main` face deploy automat.
- **APK:** `apps/child_app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (tabletele de azi).
- **Imagini Codex făcute în sesiunea asta:** 8 carduri de jocuri, 9 obiecte, 15 piese (masa, cutia, inelul, țărușul,
  ghiveciul, tulpina, mugurul, floarea, rama și globul felinarului, bula, cubul, paharul, oglinda, borcanul de vopsea)
  și **8 portrete de bază** ale copiilor pictați (`a0`…`b3`, expresia „neutru”).
- **Rămase (231 de imagini la predare):** 88 de portrete cu expresii + 143 de obiecte care încă apar ca pictograme OpenMoji.
- **17.10, noaptea (Claude):** lotul pe planșe merge (`codex_batch.py … --loop`): 9 obiecte integrate (cada,
  lumânarea, haina, coroana, puiul din ou, nota muzicală, telefonul, piesa de puzzle, tricoul); portretele au ajuns
  la 46 / 96 în `tools/art/batch/out/faces2/` (încă neintegrate — se activează la 96 / 96). Codex dă ~9 planșe pe
  fereastră de utilizare; lotul așteaptă singur deblocarea.
- **17.10, dimineața (Claude):** **toate cele 96 de portrete sunt integrate și active** (`faces2/` în pubspec);
  `convert_codex.py` acceptă acum cifre în nume (`faces2`, `a0_…_100`). „Oglinda” are geometrie pe copil
  (`_geometry` în `mirror_screen.dart`, test `test/mirror_painted_test.dart`). Rămân doar **obiectele** (lotul
  `jobs_planse.json` continuă); după fiecare fereastră: pașii din §2.4 (fără partea de fețe).
- **De refăcut ca imagine unică** (din `jobs_unice.json`, după ce se termină planșele): `objects/shark` (tăiat în
  dreapta de marginea celulei). Șterge `tools/art/batch/out/objects/shark.png`, generează lucrarea unică, apoi §2.4.

---

## 2. SARCINA PRINCIPALĂ: generarea imaginilor rămase

Tot ce trebuie e în **`tools/art/batch/`**:

| Fișier | Ce e |
|---|---|
| `jobs_planse.json` | **43 de planșe** (recomandat): 26 de planșe de fețe (2×2 sau 1×2, același copil, expresii diferite) + 17 planșe de obiecte (3×3). Fiecare are `name`, `grid`, `cells` (numele imaginilor rezultate, rând cu rând), `refs` (imaginile de stil de atașat) și `prompt` (exact ce se cere). |
| `jobs_unice.json` | Aceleași 231 de imagini, **câte una pe lucrare** (alternativa, dacă planșele nu ies bine). |
| `refs/` | Referințele de stil (PNG). `refs/faces2/<id>_neutru_100.png` = portretul de bază al fiecărui copil — **trebuie atașat** la toate expresiile copilului respectiv, ca să rămână același copil. |
| `face_ids.json` | Descrierea celor 8 copii (`a0`…`b3`). |
| `mapping.json` | Emoji → numele obiectului (pentru legarea în aplicație). |
| `out/` | Rezultatele brute (ignorat de git). Conține deja cele 8 portrete de bază. |

### 2.1 Varianta A — scriptul automat (Codex CLI)

Din rădăcina proiectului:
```bash
PYTHONIOENCODING=utf-8 py tools/art/codex_batch.py tools/art/batch/jobs_planse.json tools/art/batch/out --workers 3 --loop
```
Scriptul rulează `codex exec` pentru fiecare planșă (promptul pe stdin, referințele atașate cu `-i`), găsește PNG-ul
în `~/.codex/generated_images/<sesiune>/`, îl copiază în `out/sheets/` și **îl taie automat în celule**
(`out/faces2/…png`, `out/objects/…png`, fiecare decupată la contur). Se poate relua oricând: ce există se sare.
La limita de utilizare, cu `--loop` așteaptă singur ora spusă de Codex și continuă (fără `--loop` se oprește și scrie ora).

### 2.2 Varianta B — Codex generează direct (în sesiunea interactivă)

Pentru fiecare lucrare din `jobs_planse.json`, în ordine:
1. Generează imaginea cu unealta de imagini, cu **promptul exact** din `prompt` și imaginile din `refs` ca referințe
   (căile din `refs` sunt relative la `tools/art/batch/`).
2. Salvează PNG-ul (RGBA, fundal transparent) ca `tools/art/batch/out/<name>.png`
   (ex. `tools/art/batch/out/sheets/a0_bucuros100_trist100_suparat100_speriat100.png`).
3. După câteva planșe, taie-le în celule:
   ```bash
   PYTHONIOENCODING=utf-8 py tools/art/codex_batch.py tools/art/batch/jobs_planse.json tools/art/batch/out --split-only
   ```
Pentru o lucrare din `jobs_unice.json`, salvează direct `tools/art/batch/out/<name>.png` (ex. `out/objects/tiger.png`).

### 2.3 Verifică ce a ieșit (înainte de integrare)

Fă o planșă de previzualizare și uită-te la ea:
```bash
py -c "from PIL import Image; import glob; fs=sorted(glob.glob('tools/art/batch/out/faces2/*.png'))+sorted(glob.glob('tools/art/batch/out/objects/*.png')); W=200; s=Image.new('RGBA',(W*8,W*((len(fs)+7)//8)),(220,220,220,255)); [s.alpha_composite(Image.open(f).convert('RGBA').resize((W,W)),((i%8)*W,(i//8)*W)) for i,f in enumerate(fs)]; s.save('tools/art/batch/out/preview.png')"
```
Refă (șterge fișierul și rulează din nou lucrarea) ce nu e bun:
- **fețe:** același copil ca în `refs/faces2/<id>_neutru_100.png` (păr, ten, ochelari, bentiță, pistrui, tricou
  mentă), aceeași încadrare (cap și umeri, din față), expresia cerută; la treptele 20/40/60/80% expresia trebuie să
  crească vizibil de la o treaptă la alta; fără lacrimi decât la „trist” 100%; **fără fețe înfricoșătoare**;
- **obiecte:** un singur obiect, întreg, centrat, fundal transparent, fără text, fără umbră pe podea; stilul
  obiectelor existente (`packages/game_content/art/illustrations/objects/apple.webp`, `teddy.webp`, `house.webp`);
- celulele tăiate greșit (două obiecte într-o celulă, obiect tăiat) → refă lucrarea ca imagine unică din
  `jobs_unice.json`.

### 2.4 Integrarea în aplicație

Din rădăcina proiectului, în ordine:
```bash
export PYTHONIOENCODING=utf-8
# 1) lista „Sursă PNG + prompt" (o cere convert_codex.py) — câte un fișier README nou pe lot
py tools/art/codex_readme.py tools/art/batch/jobs_planse.json tools/art/batch/out faces2 faces2/
py tools/art/codex_readme.py tools/art/batch/jobs_planse.json tools/art/batch/out objects7 objects/
# 2) conversia în webp (mărimi și decupare după folder; doar ce s-a schimbat)
py tools/art/convert_codex.py
# 3) emoji → ilustrația pictată pentru obiectele noi (regenerează apps/child_app/lib/shared/painted_extra.dart)
py tools/art/painted_map.py tools/art/batch/mapping.json
# 4) fețele: câte portrete sunt gata
py tools/art/check_faces.py
```
- **Obiectele** apar imediat în jocuri (prin `painted_extra.dart`), fiecare pe măsură ce există.
- **Fețele** se activează **doar când `check_faces.py` arată 96 / 96**: atunci adaugă în
  `packages/game_content/pubspec.yaml`, la `assets`, linia `    - art/illustrations/faces2/` (lângă `parts/`).
  Până atunci folderul nu e în aplicație, ca să nu apară amestecate fețe pictate cu fețe desenate din cod.
  Codul e deja gata: `paintedFace()` în `apps/child_app/lib/shared/stimulus_art.dart` alege copilul pictat și treapta
  de intensitate cea mai apropiată; copiii sunt definiți în `packages/licurici_core/lib/src/face.dart`
  (`paintedLooks`, `paintedIds`, `ladderLooks`).
- **Oglinda** folosește portretele „neutru” și pozițiile măsurate pe ele (`partCenter` în
  `apps/child_app/lib/features/games/mirror/mirror_screen.dart`). După activarea fețelor verifică în captură că
  cercul de lumină cade pe nas / gură / ochi / urechi; dacă nu, ajustează valorile din ramura „portretele pictate".

### 2.5 Verificarea vizuală cu ilustrațiile reale

```bash
cd apps/child_app
MSYS_NO_PATHCONV=1 flutter test --dart-define=SHOTS=true --update-goldens test/art_shots_test.dart
```
Capturile apar în `apps/child_app/test/shots/pictat-*.png` (Cât de tare?, Cine e prietenul?, Cum se simte?, Oglinda,
Pune ursulețul, Unde e ursulețul?, Turnul, Floarea crește, Stop!, Atinge rapid, Rândul meu, Cucu-bau, Colorează ce
auzi, Memorie cu sunete). Uită-te la fiecare: nimic tăiat, nimic suprapus greșit, fețele de aceeași mărime.

### 2.6 Final de lot

Rulează testele (§4), apoi commit + push pe ambele ramuri (§0.4), de ex.
`feat(art): fete pictate cu expresii (96), obiecte pictate in locul pictogramelor`.
Actualizează README §0.1 și §0.0 („Imaginile Codex" — ce a rămas de verificat de utilizator pe tabletă).

---

## 3. Alte imagini care încă nu sunt pictate (după lotul de mai sus)

Caută în cod desenele rămase din cod și înlocuiește-le pe rând cu piese Codex, la fel ca piesele existente
(`apps/child_app/lib/shared/parts.dart`: `hasPart('nume')` + `Part('nume', tint: …)`, imaginea în
`packages/game_content/art/illustrations/parts/nume.webp`, sursa în `README-parts*.md`, decupată la contur de
`convert_codex.py`). Candidați: turnul de cuburi din „Rândul meu" (baza), farul și bărcile din „Paznicul farului",
semnul regulii din „Regula se schimbă", desenul de pe fișa de colorat a acvariului (`coloring_screen.dart`),
fețele desenate rămase ca rezervă (`drawn_face.dart`). Formele geometrice simple (pătrate, cercuri colorate),
cifrele și literele rămân din cod (sunt stimuli „curați", nu ilustrații).

---

## 4. Comenzi de verificare

```bash
# nucleul (Dart pur)
cd packages/licurici_core && dart test
# aplicația copilului
cd apps/child_app && flutter analyze lib test && MSYS_NO_PATHCONV=1 flutter test
# panoul
cd apps/dashboard && flutter test
# versiunea Vercel
cd deploy/vercel && npm test
# backend (NestJS)
cd backend && npm test
# vocea: ce fraze nu au clip, apoi generarea lor (edge-tts, ro-RO-AlinaNeural)
cd packages/licurici_core && dart run tool/voice_coverage.dart --write
cd ../.. && PYTHONIOENCODING=utf-8 PYTHON=py node tools/gen-voice/gen-voice.mjs
# APK-urile (tabletele de azi: arm64)
cd apps/child_app && flutter build apk --release --split-per-abi
```
Orice frază nouă rostită într-un joc se adaugă în `packages/licurici_core/tool/voice_coverage.dart` și se generează
vocea; aplicația nu are voci în engleză.

---

## 5. Ce urmează după imagini (în ordinea priorității)

1. **Răspunsurile utilizatorului din README §0.0**: tableta reală (fluiditate, sunet, jocurile noi, imaginile noi),
   testul cap-coadă online (terapeut → copil → cod → tabletă → sesiune în panou). Repară ce raportează.
2. **„Cum spune?"** (emoția din voce, singurul joc cu metrici standard rămas) — așteaptă înregistrările de la
   utilizator (§0.0 D).
3. **Stiva completă în Docker** (când utilizatorul are Docker Desktop): `docker compose -f infra/docker-compose.yml up -d --build`,
   apoi `node tools/e2e/stack.mjs`; testele e2e cu Testcontainers (README §21).
4. **Producția** (după ce utilizatorul are VPS UE + domeniu + Brevo): `docs/operare.md`, `infra/docker-compose.prod.yml`,
   testul k6; migrarea datelor din versiunea Vercel (`deploy/vercel`, documentele JSON din Blob) în PostgreSQL
   — rutele sunt aceleași (`docs/deploy-vercel.md`, ultima secțiune).
5. **Magazinele**: Google Play (Families) — formularele sunt în `docs/gdpr/declaratii-magazine.md`; iOS cere Mac/Xcode
   sau build în cloud + cont Apple Developer.
6. **(S2, opțional)** conținut pentru clasele 5–12 și tema „matură"; Sentry; Azure Speech.

---

## 6. Hartă rapidă a proiectului

| Unde | Ce |
|---|---|
| `packages/licurici_core/` | logica (Dart pur): jocurile, nivelurile (`level_scale.dart`), catalogul (`catalog.dart`), treptele terapeutice (`development.dart`), înregistrarea încercărilor (`recorder.dart`), metricile standard, fețele (`face.dart`) |
| `apps/child_app/` | aplicația copilului (Flutter, landscape): `lib/main.dart` (rutele), `lib/features/games/<joc>/` (ecranele), `lib/shared/` (voce, sunete, ilustrații, piese pictate) |
| `apps/dashboard/` | panoul terapeutului / părintelui (Flutter Web) |
| `backend/` | API-ul NestJS + Prisma (stiva completă) |
| `deploy/vercel/` | versiunea de test: API mic pe Vercel + Blob, panoul construit la deploy |
| `packages/game_content/` | ilustrații (`art/illustrations/<folder>/`, cu sursele în `README-*.md`), OpenMoji, voce (`audio/ro/`, `voice.json`), fonturi |
| `tools/art/` | uneltele pentru imagini: `codex_batch.py`, `codex_readme.py`, `convert_codex.py`, `painted_map.py`, `check_faces.py`, `batch/` |
| `docs/` | ADR-uri, cercetare (§23), GDPR, ghiduri (operare, deploy Vercel, brief-uri de ilustrații) |

Un joc nou = logica în `licurici_core/lib/src/<joc>.dart` (+ export în `licurici_core.dart`, intrare în `catalog.dart`,
`GameKind` + rută, `LevelScale` în `level_scale.dart` + `test/level_scale_test.dart`, treapta în `development.dart`,
metoda de înregistrare în `recorder.dart`) + ecranul în `apps/child_app/lib/features/games/<joc>/` + ruta în
`main.dart` + calea în `test/a11y_games_test.dart` + test de widget + vocea + cardul Codex
(`art/illustrations/games/<id>.webp`) + README §16 / §0.1.
