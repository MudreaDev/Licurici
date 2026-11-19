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

## 1. Starea de acum (actualizată 25.10.2026)

### Continuare 19.11.2026

- A doua trecere Vorbim: 6 jocuri au trepte noi, detaliate individual în `docs/progres-niveluri-jocuri.md`; AAC rămâne disponibil integral fără dificultate obligatorie. Memoria cu sunete are 9 perechi, cartonașe ≥64 dp și derulare; propozițiile au 5 distractori și tavă derulabilă. Urmează Gândim. Aceste modificări sunt ulterioare versiunii 0.1.3.
- Verificări Vorbim: 670 teste nucleu, 480 aplicație copil (15 capturi opționale sărite), 37 panou, 90 backend, 7 Vercel; analiză Flutter fără probleme, acoperire vocală 2883/2883.

- A doua trecere Ascult și înțeleg: toate cele 11 jocuri au trepte suplimentare, descrise individual în `docs/progres-niveluri-jocuri.md`. Instrucțiuni cu până la 4 obiecte, 4 poziții, 4 colorări sau 5 pași au fost parcurse pe telefon mic simulat; poveștile păstrează integral și în ordine narațiunea. Urmează Vorbim, în ordinea secțiunilor. Aceste modificări sunt ulterioare versiunii 0.1.3.
- Verificări Ascult și înțeleg: 668 teste nucleu, 474 aplicație copil (15 capturi opționale sărite), 37 panou, 90 backend, 7 Vercel; analiza Flutter fără probleme, acoperire vocală 2883/2883.

- A doua trecere Potrivim: toate cele 8 jocuri au trepte noi, detaliate individual în `docs/progres-niveluri-jocuri.md`. Puzzle-ul ajunge la 24 de piese, fără model la 15, cu tavă și ramă derulabile și ținte ≥64 dp pe telefon mic simulat. Urmează Ascult și înțeleg, în ordinea secțiunilor.
- Verificări Potrivim: 666 teste nucleu, 464 aplicație copil (15 capturi opționale sărite), 37 panou, 90 backend, 7 Vercel; analiza Flutter fără probleme. Versiunea de test 0.1.3 este publicată din `89fb73d`: trei APK-uri, panou web și SHA256SUMS, verificate pe GitHub. APK-ul arm64 are aceeași semnătură ca 0.1.2. Verificarea pe tabletă fizică rămâne necesară.

- A doua trecere prin Fac și eu este implementată: Oglinda 7 atingeri, Construiește 4 distractori și paletă derulabilă, Toba 6 runde, Fă ca Licurici 5 acțiuni. Atingerea din Oglinda se normalizează la dimensiunea reală a feței, cercul apare la atingere, iar panoul și rama au fost rearanjate; este necesar testul tactil și vizual pe tabletă fizică. Urmează Potrivim, în ordinea din evidență.
- Verificări Fac și eu: 665 teste nucleu, 454 aplicație copil (15 capturi opționale sărite), 37 panou, 90 backend, 7 Vercel; analiza Flutter fără probleme. Corecția cercului din Oglinda a fost reverificată suplimentar prin cele 8 teste dedicate cu portrete pictate și desenate.

- Verificări pentru a doua trecere Atenție: nucleu 665 teste, aplicația copilului 454 (15 capturi opționale sărite), panou 37, backend 90, Vercel 7; analiza Flutter fără probleme. Țintele noului nivel „Ce s-a schimbat?” au fost măsurate la minimum 64 dp pe telefon mic simulat.

- „Continuă șirul” din Gândim are modele ABAC, ABBC și AABC de la nivelul 8, testate pe telefon și tabletă simulate. Celelalte zece jocuri din secțiune rămân de abordat în ordine; lista exactă este în `docs/progres-niveluri-jocuri.md`.
- Clipurile pentru „Super!” și „Super! Ai terminat!” au fost regenerate cu transcriere silabisită pentru sinteză. Manifestul și textul afișat au rămas aceleași; pronunția trebuie ascultată pe dispozitiv înainte de confirmare.
- Utilizatorul a cerut reluarea în ordine de la **Atenție**: verificați și continuați dezvoltarea tuturor celor șase jocuri din această secțiune înainte de a trece la Fac și eu și celelalte. Extinderea deja realizată la „Continuă șirul” rămâne consemnată, dar restul secțiunii Gândim așteaptă rândul.
- A doua trecere prin Atenție: niveluri suplimentare pentru toate cele șase jocuri, individual în `docs/progres-niveluri-jocuri.md`. Testele de generator și cele de parcurgere pe telefon mic sunt rulate pentru noile trepte. În continuare, a doua trecere prin Fac și eu, apoi Potrivim etc.; nu presupuneți că o primă trecere înseamnă dificultate nelimitată.

### Continuare 18.11.2026

- Validarea secțiunii Ascult și înțeleg: nucleu 659 teste, aplicația copilului 442 (15 capturi opționale sărite), panou 37, backend 90, Vercel 7, analiză Flutter fără probleme. Acoperirea vocală verificată exhaustiv pentru sumele de bani: 2883/2883 fraze, clipuri prezente și nenule.
- Validarea secțiunii Vorbim: nucleu 660 teste, aplicația copilului 452 (15 capturi opționale sărite), panou 37, backend 90, Vercel 7, analiză Flutter fără probleme; acoperire vocală 2883/2883.

- Validarea primelor trei secțiuni: nucleu 658 teste, aplicația copilului 426 (15 capturi opționale sărite), panou 37, backend 90, Vercel 7; analiza Flutter fără probleme. Ecranele de nivel nou au fost verificate pe simulator, nu pe tabletă fizică.

- **Cerința utilizatorului: toate jocurile, secțiune cu secțiune.** Evidența individuală și ordinea sunt în `docs/progres-niveluri-jocuri.md`, verificată automat față de catalog prin `levels_inventory_test.dart`. Prima trecere prin Atenție (6), Fac și eu (4), Potrivim (8), Ascult și înțeleg (11) și Vorbim (6 jocuri extinse și o tablă AAC revizuită) este implementată și testată. Tabla „Vorbește” rămâne integral accesibilă, fără nivel obligatoriu. Memoria cu sunete are 8 perechi și ținte de cel puțin 64 dp la nivelul nou, pe telefonul mic simulat. Urmează Gândim (11 jocuri), apoi secțiunile rămase în ordinea din evidență. Nu marca restul secțiunilor gata pe baza lucrărilor făcute în afara ordinii, fără revizuire și teste. Jocurile păstrează limite reale; verificați pe dispozitiv și cu specialistul.

- **Caută:** nivelul 15 folosește distractori din aceeași grupă cu ținta, cu rezervă la celelalte imagini permise dacă filtrele specialistului golesc grupa. `gameScales` și testele generatorului reflectă noua treaptă.
- După explorări și Caută: 655 teste nucleu, 406 teste aplicație copil, 15 capturi opționale sărite; analiza Flutter și testele panoului/backend/Vercel au trecut. Verificarea pe tabletă rămâne necesară.
- Scările normalizate includ treapta 8 pentru Ceasul și jocurile numerice care folosesc distractori apropiați; scara explorărilor reflectă conținutul disponibil la nivelul 3. Recalcularea rapoartelor vechi folosește aceste scări noi; pentru validarea longitudinală, comparați valorile înainte și după schimbare.

- **Explorări:** toate cele trei episoade folosesc nivelul salvat și au exemple suplimentare pentru fiecare oprire de la nivelul 3. Opririle salvează încercările parțial, iar finalizarea episodului contează o singură dată la repetările stabilite de specialist. În modul adaptiv, nivelul se ajustează după reușitele din întregul episod. Teste pe telefon/tabletă simulate și verificare pentru toate opririle; plafonul conținutului actual este 3, deci extinderea suplimentară rămâne deschisă.

- Validare lot nou de niveluri: 654 teste nucleu, 404 aplicație copil (15 capturi opționale sărite), 37 panou, 90 backend, 7 Vercel; analiza Flutter fără probleme. Verificări pe telefon simulat pentru treptele noi de imitație, secvență, ritm și schimbare de reguli.

- **Următorul lot de niveluri:** `simon` / `licuricii` până la 9 elemente în secvență, `fa-ca-licuriciul` până la 4 acțiuni, `toba-magica` până la 8 bătăi, `regula-se-schimba` până la 8 schimbări în 12 cartonașe, `construieste` cu model vizibil 4 s / 3 s la treptele noi; `ceasul` are variante cu aceeași oră și alte minute de la 8, iar generatorul numeric comun alege vecinii cei mai apropiați. Limitele alese în panou sunt acum 1–40 (acceptate de ambele servere), iar jocurile choice nu se mai opresc artificial la 20. **Extinderea tuturor jocurilor rămâne neîncheiată:** multe mecanici au încă plafon. Nu considera creșterea numărului o nouă dificultate când mecanica nu se schimbă. APK-ul 0.1.2 nu conține aceste modificări.
- **Niveluri suplimentare, parțial:** `turnul` distinge inelele mai apropiate până la nivelul 9; `adu-mi` cere trei obiecte de la 8; `pune-ursul` cere trei așezări de la 7; `oglinda` folosește patru atingeri de la 8 și cinci de la 10. Tăvile au fost adaptate și testate pe telefon mic. Scările reale au fost actualizate în `level_scale.dart`; asta schimbă și normalizarea dificultății pentru aceste jocuri. Clipurile vocale sunt acoperite (2765/2765). **Nu este gata cererea pentru toate jocurile:** celelalte plafonări din `gameScales` și jocurile choice trebuie extinse mecanică cu mecanică, fără a confunda numere mai mari cu dificultate nouă; colorarea, respirația și AAC sunt activități libere, fără niveluri competitive.
- Verificări pentru nivelurile suplimentare: nucleu 652, copil 400 (15 capturi opționale omise), panou 37, backend 90, Vercel 7; analiza Flutter fără probleme. Testele includ noile niveluri pe telefon mic simulat. Verificarea pe dispozitiv rămâne deschisă.
- Inel pictat cu volum și filtru de colorare corectat. Audit: 37 obiecte decupate incorect refăcute, plus blocul din „Rândul meu”; au fost inspectate planșele obiectelor, cardurilor și portretelor, precum și capturile turnului de blocuri. Surse, prompturi și limite: `docs/audit-imagini-2026-11-18.md`.
- Panoul permite limită zilnică și 1–5 jocuri încheiate la același nivel; planul se sincronizează, contoarele rămân în setările locale. Verifică pe tabletă fluxul și reluarea; vezi detaliile în README §0.1, §11 și §13. Ceasul și Zilele și lunile există în „Numere și litere”.
- Salvarea parțială (AAC și atingerea limitei zilnice) nu mai contează ca joc terminat; la atingerea limitei se salvează încercările deja înregistrate.
- Acvariu: cadoul, pușculița și raftul citesc politica de mișcare; toate straturile împart un buget de maximum 40 de particule, oprite în modul calm. Țintele raftului au minimum 64 dp. Jocul cu pești citește politica din `build`, nu din ticker. Teste: `reef_motion_policy_test.dart`, acvariu, cufăr, urmărire și scenă.
- Verificări 18.11: aplicația copilului 396 teste trecute și 15 capturi opționale sărite; analiza Flutter fără probleme. Nucleu 652, panou 37, backend 90 și Vercel 7 teste trecute. Scenele acvariului și ale jocului „Rândul meu” au fost verificate suplimentar cu ilustrațiile încărcate.
- Panourile web: căutare după nume în lista specialistului; selecție etichetată a copilului și indicator DEMO corect în panoul părintelui; spațiere îmbunătățită pe ecrane înguste. APK-urile Android 0.1.2 sunt publicate în `v0.1.2-preview.1`; detalii și verificarea sumelor în `docs/releases.md`.
- Build web JavaScript reușit; verificarea opțională Wasm semnalează incompatibilitatea cunoscută din `socket_io_common`. Build Android arm64, armeabi-v7a și x86_64 reușit. Verificarea pe dispozitiv rămâne de făcut.


### Documentație universitară 12.11.2026

- [x] Laborator 3 PSI adaptat aplicației Licurici: `output/docx/Laborator_3_PSI_Mudrea_Mihail_Licurici.docx`, 25 de pagini, 9 diagrame, 11 tabele. Copertă: Mudrea Mihail, TI-233, coordonator Cojocaru Svetlana, UTM.
- [x] Regulile UTM furnizate ulterior de utilizator au prioritate față de aspectul PDF-ului: Times New Roman, corp 12 pt / 1,5, capitole 13 pt, tabele 11 pt / 1, margini sus/stânga/jos 20 mm și dreapta 10 mm; lista de abrevieri înainte de Introducere și pagini preliminare fără număr vizibil.
- [x] Modelul are 4 funcții și 14 subfuncții; codul real de plan, sesiuni și sincronizare a fost consultat. Sunt separate utilizarea locală, confirmarea transferului și statisticile centrale. Sursele de generare/verificare: `tools/docs/build_lab3.py`, `lab3_diagrams.py`, `render_lab3_word.ps1`, `check_lab3.py`.
- Randarea standard cu LibreOffice nu este disponibilă pe calculator; verificarea s-a făcut cu Microsoft Word în fundal, export PDF și inspectarea paginilor. PDF-ul de verificare și imaginile sunt în `tmp/lab3/`, nu reprezintă livrabile. Bibliografia are referințe numerice în stil IEEE; Zotero nu este instalat.
- Nu s-au modificat jocuri, date despre copil, tehnologii sau reguli ale proiectului. Modificările aplicației existente la începutul sesiunii nu fac parte din acest livrabil. §2–§5 păstrează starea anterioară.

### Continuare 25.10.2026

- [x] **Cufărul în modul calm / reduce motion:** răspuns static imediat de 1,2 s, fără dependență de timpul ambiental oprit și fără bulele deschiderii. Atingerile repetate prelungesc feedbackul; schimbarea modului / ieșirea anulează timerul. Pictorii de recif și noapte ascultă modificările cufărului.
- [x] **Cufăr accesibil pe telefon:** testul a descoperit că bara de jos îi acoperea ținta. Acvariul are acum spațiu rezervat pentru comenzi; ținta cufărului are minimum 64 dp și semantică de buton. Atingerea sa nu mai sperie și peștii simultan. Tranziția zi/noapte respectă dezactivarea animațiilor din sistem.
- **Versiune copil 0.1.2+3:** la această predare verificarea și livrarea erau în curs; pentru publicarea ulterioară vezi continuarea din 18.11 și `docs/releases.md`. Testele noi acoperă timpul ambiental oprit, reatingerea, schimbarea modului, închiderea ecranului, dimensiunea țintei, suprapunerea cu butoanele și preferința sistemului.

- [x] Continuarea graficii: `parts/tower_base.webp` generată și integrată în „Rândul meu”, cu rezerva din cod păstrată; promptul și sursa sunt în `README-parts4.md`. Testul de joc poate încărca ilustrațiile reale la `SHOTS=true`.
- [x] Revizuită lista veche din §3: bărcile din „Paznicul farului” sunt deja pictate prin `StimulusArt` → `objects/sailboat`; nu există un far desenat în ecranul actual. Indiciile geometrice din „Regula se schimbă” rămân din cod, fiind stimuli educativi, nu decorații. Nu relua aceste puncte ca imagini lipsă.
- **Livrare 0.1.1+2:** aplicația copilului și panoul au versiunile incrementate. APK-uri și panou web compilat în GitHub Releases, tag `v0.1.1-preview.1`; procedura și conținutul pachetelor în `docs/releases.md`. **Publicată și verificată:** [v0.1.1-preview.1](https://github.com/MudreaDev/Licurici/releases/tag/v0.1.1-preview.1), sursa `fc8baea`. Toate cele 5 atașamente sunt prezente; digesturile SHA-256 GitHub coincid cu cele locale. Build Android și Web reușite; analiza Flutter curată; cele 2 teste „Rândul meu” cu ilustrațiile încărcate trec, capturi verificate pe telefon/tabletă. Build-ul web JavaScript reușește; verificarea opțională Wasm semnalează incompatibilitatea existentă `socket_io_common` (nu s-a livrat Wasm).

- [x] Lotul principal (§2) era încheiat: verificate 96 de portrete, activarea `faces2/` în pubspec și existența tuturor obiectelor din `mapping.json`.
- [x] Lotul suplimentar `tools/art/batch/jobs_acvariu.json`: cele 6 PNG-uri existau local din 17.10; integrate acum ca `parts/kelp`, `anemone`, `school_fish`, `turtle_side`, `chest_closed`, `chest_open`. Surse și prompturi: `README-aquarium4.md`. Fundalurile `aquarium_back` / `aquarium_front` erau deja integrate; nu se regenerează.
- [x] Acvariu: mânuța de ghidaj nu mai animă în modul calm / reduce motion; particulele de interacțiune sunt oprite în aceste moduri, inclusiv cele deja active. În modul normal, cel mult 5 efecte simultane (maximum 7 particule per efect). Politica de mișcare este citită la construirea ecranului, nu din callback-ul fiecărui cadru.
- [x] Testele existente de acvariu extinse: modul calm activat în timpul indiciului, atingeri repetate, oprirea particulelor. Captură verificată vizual: `apps/child_app/test/shots/acvariu-pictat.png` (locală, ignorată de git).
- **Validare:** nucleu 652, panou 36, backend 90, Vercel 7 și cele 3 teste de scenă cu `SHOTS=true` trec; analiza Flutter fără probleme. Aplicația copilului: **381 teste trecute, 15 capturi opționale sărite** fără `SHOTS`. **APK-urile release construite cu succes** după teste: arm64 84,2 MB (pentru tabletă), armeabi-v7a 82,6 MB, x86_64 85,7 MB, în `apps/child_app/build/app/outputs/flutter-apk/`. Build-ul emite avertismente de mediu (SDK XML / acces nativ Java) și despre fontul CupertinoIcons; nu au blocat construirea. Nu s-au actualizat SDK-uri sau dependențe.
- **Pentru următoarea sesiune:** verifică pe tableta reală cufărul, raftul și modul calm; auditul accesoriilor și particulelor a fost continuat în 18.11. Lista grafică din §3 este revizuită; nu înlocui contururile de colorat sau formele educative cu decorații. §5 rămâne dependent de verificarea pe tabletă, înregistrările vocale și infrastructura utilizatorului.
- **Mediu:** comenzile `py` / Flutter au necesitat acces în afara restricțiilor implicite pentru instalările și cache-urile existente. Nu s-au adăugat dependențe. Folderul neversionat `output/` exista înaintea sesiunii și a fost lăsat intact.

### Istoricul predării (16–17.10)

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
- **17.10, 11:20 (Claude): LOTUL E GATA.** Toate cele **143 de obiecte** sunt pictate și integrate (`painted_extra.dart`,
  `README-objects7.md` / `objects8.md`); la tăierea planșelor, bucățile din celulele vecine se șterg automat
  (`drop_fragments`, cere `scipy`); rechinul a fost refăcut ca imagine unică. Au rămas ca pictograme OpenMoji doar
  simbolurile și formele (săgeți, + − × ÷, cifre, steaguri, cercuri / pătrate colorate) — intenționat, sunt
  stimuli „curați” în jocurile de matematică și forme. **Sarcina principală (§2) e încheiată**; urmează §3–§5.

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

**Audit 25.10:** baza din „Rândul meu” este acum pictată. Barca este deja `objects/sailboat`, afișată prin `StimulusArt`; farul este tema jocului, nu un desen procedural prezent în ecran. Semnul regulii folosește culorile/formele exacte din `cardColors` / `cardShapes` și rămâne din cod conform excepției pentru stimuli curați. Contururile fișelor de colorat sunt necesare umplerii și scanării, iar `drawn_face.dart` este rezerva intenționată. Lista de mai jos este istoric de candidați, nu un lot restant de generat automat.

Caută în cod desenele rămase din cod și înlocuiește-le pe rând cu piese Codex, la fel ca piesele existente
(`apps/child_app/lib/shared/parts.dart`: `hasPart('nume')` + `Part('nume', tint: …)`, imaginea în
`packages/game_content/art/illustrations/parts/nume.webp`, sursa în `README-parts*.md`, decupată la contur de
`convert_codex.py`). Candidați: turnul de cuburi din „Rândul meu" (baza), farul și bărcile din „Paznicul farului",
semnul regulii din „Regula se schimbă", desenul de pe fișa de colorat a acvariului (`coloring_screen.dart`),
fețele desenate rămase ca rezervă (`drawn_face.dart`). Formele geometrice simple (pătrate, cercuri colorate),
cifrele și literele rămân din cod (sunt stimuli „curați", nu ilustrații).

---

## 4. Comenzi de verificare

**Ordine pe Windows:** termină testele Flutter înainte să construiești APK-ul. Testele și build-ul folosesc aceleași fișiere generate Android; în sesiunea 25.10, rularea lor simultană a lăsat o referință la `IntegrationTestPlugin` în compilarea release. Reia comanda standard de build (cu rezolvarea dependențelor, fără `--no-pub`) după teste; nu modifica manual `GeneratedPluginRegistrant.java`.

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
