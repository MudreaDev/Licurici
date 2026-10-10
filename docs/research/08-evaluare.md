# 08 · Evaluarea: ce am măsurat, cum, și ce rămâne de măsurat

*Capitol de cercetare pentru teză (README §23). Măsurători din sesiunea a unsprezecea (11.10.2026), pe calculatorul de dezvoltare (Windows 11). Cifrele se pot reproduce cu comenzile din fiecare secțiune.*

## 1. Ce înseamnă „bun” pentru Licurici

| Dimensiune | Întrebarea | Metrica | Ținta |
|---|---|---|---|
| Corectitudine | Face codul ce spune? | teste automate, acoperire pe linii | logica clinică (nucleul) ≥ 90% |
| Performanță pe tabletă | Așteaptă copilul vreodată? | timpul calculelor de pe ecranul principal; 60 fps în joc | < 16 ms pe calcul (un cadru); fără sacadări |
| Performanță pe server | Ține la mulți copii? | p95 al sincronizării sub încărcare | p95 < 200 ms la 200 sincronizări/s |
| Accesibilitate | Poate folosi aplicația un copil cu dificultăți motorii sau vizuale? | ținte de atingere, etichete, contrast | ținte ≥ 48 dp, etichete pe tot ce se apasă, contrast WCAG |
| Confidențialitate | Iese ceva ce n-ar trebui? | teste de contract și de acces | niciun câmp necunoscut acceptat; 404 pentru străini |
| Utilitate | Ajută copilul? | studiu cu utilizatori | (semestrul 2, cu acord parental — §13.6) |

## 2. Teste automate

| Componentă | Teste | Fișiere de test | Comandă |
|---|---|---|---|
| `licurici_core` (Dart pur: dificultate, jocuri, sesiune, rapoarte, scanare) | **506** | 53 | `dart test` |
| Aplicația copilului (Flutter) | **308** | 53 | `flutter test` |
| Panoul adulților (Flutter Web) | **21** | 4 | `flutter test` |
| Backend (NestJS) | **86** + testul de fum live | 17 | `npm test`, `npm run test:smoke` |
| **Total** | **921** | | |

Tipuri de teste, cu exemple:
- **unitare pe proprietăți** — rating-ul Elo crește mai mult la o reușită pe un nivel mare (`progress_test.dart`); un generator cu același seed dă același nivel;
- **de paritate** — dificultatea portată din prototipul JavaScript dă exact aceleași valori (`difficulty_test.dart`);
- **de contract** — JSON-ul produs de Dart e acceptat exact de schema TypeScript a serverului (`sync.spec.ts`, fixtura generată cu `tool/sync_fixture.dart`);
- **de acces** — un părinte străin sau un specialist fără partajare primește 404 la fiecare resursă a copilului;
- **de interfață pe mai multe dimensiuni de ecran** — fiecare joc pe telefonul mic și pe tabletă, fără depășiri (`choice_games_test.dart`, `layout_test.dart`);
- **de accesibilitate** — 9 ecrane + 24 de rute de joc (`a11y_test.dart`, `a11y_games_test.dart`);
- **cap-coadă** — copil → joc jucat cu animațiile pornite → SQLite → poarta părintelui → server HTTP local (`flow_test.dart`, `integration_test/flow.dart`);
- **cu fotografii sintetice** — scanarea fișei de colorat în perspectivă, cu lumină inegală, zgomot și rotire (`paper_scan_test.dart`).

### 2.1 Acoperirea pe linii

| Componentă | Acoperire | Comentariu |
|---|---|---|
| `licurici_core` | **94,2%** (5066 / 5380) | Logica clinică și generatoarele. |
| Backend — total | 52,3% (655 / 1253) | Media ascunde două lumi diferite (mai jos). |
| Backend — servicii de domeniu (`auth`, `children`, `consents`, `gdpr/gdpr.ts`, `sync`, `reports`, `stats/skill-stats.ts`) | 80–100% | Tot ce decide acces, consimțământ, idempotență. |
| Backend — cablaj și infrastructură (`api.module.ts`, `controllers.ts`, `repos.ts`, procesoarele BullMQ, `main.ts`) | 0% în Jest | Verificate prin testul de pornire a API-ului și worker-ului și prin testul de fum; cer Postgres/Redis reale pentru teste e2e (Testcontainers — README §21, după instalarea Docker). |
| Aplicația copilului | **91,7%** (12 592 / 13 739) | Ecranele, inclusiv animațiile și fluxul cap-coadă. |
| Panoul adulților | **90,4%** (1 334 / 1 475) | Inclusiv cu backend simulat. |

Comenzi: `dart test --coverage-path=core.lcov` · `npx jest --coverage` · `flutter test --coverage`.

**Interpretare:** separarea domeniu / infrastructură (`04-patternuri.md` §1.3, §4.2) face ca partea care contează clinic și juridic să fie testabilă fără bază de date. Partea netestată automat e „cablajul” — puțină logică, dar exact acolo apar erorile de configurare. De aceea testul de pornire a fost util: a prins o dependență lipsă între module, iar în sesiunea 11 a confirmat că noua rută `/children/:id/skills` și coada `stats` sunt legate corect.

## 3. Performanța pe tabletă

### 3.1 Calculul de pe ecranul principal

La fiecare deschidere a ecranului principal, aplicația calculează progresul pe toate treptele din toate sesiunile salvate și construiește „Drumul de azi”. Măsurat cu `dart run tool/bench_progress.dart` (sesiuni de 40 de încercări, media a 20 de rulări după încălzire, JIT pe desktop):

| Istoric | Încercări | Timp |
|---|---|---|
| 30 de sesiuni (~1 lună) | 1 200 | 6,0 ms |
| 120 de sesiuni (~4 luni) | 4 800 | 5,3 ms |
| 500 de sesiuni (peste 24 de luni — limita retenției) | 20 000 | 12,5 ms |

Chiar presupunând o tabletă de 5–8 ori mai lentă decât calculatorul de dezvoltare, cazul extrem rămâne sub 100 ms, o singură dată la deschiderea ecranului — nu în timpul jocului. Calculul e asincron (după citirea din SQLite), deci nu blochează animațiile. Dacă ar deveni o problemă, pasul următor e un rezumat incremental pe treaptă salvat în Drift (același read model ca pe server).

### 3.2 Cadrele pe secundă

Animațiile sunt procedurale, din cod (ADR-028), fără shadere. Măsurarea relevantă e pe o tabletă reală, în modul *profile* — **încă nefăcută** (README §0.0 A). În panoul de previzualizare al browserului, animațiile sunt încetinite intenționat de browser când fereastra e ascunsă, deci nu e o măsurătoare validă.

### 3.3 Dimensiunea aplicației

| Build | Mărime |
|---|---|
| APK release arm64-v8a | 63,7 MB |
| APK release armeabi-v7a | 62,1 MB |
| APK universal | 65,3 MB |

Cea mai mare parte o formează vocea pre-generată (2 503 clipuri MP3 — ADR-016) și ilustrațiile pictate. Alternativa (sinteză vocală pe dispozitiv) ar fi redus mărimea, dar vocile românești de pe dispozitive sunt inconsistente sau lipsesc — un copil cu TSA are nevoie de aceeași voce, clară, de fiecare dată. Pachetele de conținut descărcabile (S2) ar muta în afara APK-ului ce nu e necesar la prima pornire.

## 4. Performanța serverului

Scriptul k6 (`tools/k6/sync.js`) trimite 200 de sincronizări pe secundă timp de 2 minute, fiecare cu o sesiune nouă, și cere **p95 < 200 ms** și peste 99% de răspunsuri reușite. **Nu a fost rulat încă**: are nevoie de serverul de test cu Postgres și Redis (README §0.0 C).

Ce ne așteptăm să limiteze: scrierea JSON-ului sesiunii în Postgres (o cerere = un `upsert`). Ce *nu* ar trebui să limiteze: statisticile — fiecare sincronizare pune un job în coada `stats`, dar deduplicarea per copil (`keepLastIfActive`) ține cel mult un job activ și unul în așteptare per copil, indiferent de ritmul sincronizărilor.

## 5. Accesibilitate

Testele automate verifică, pe 9 ecrane și 24 de rute de joc: ținte de atingere ≥ 48 × 48 dp, etichete semantice pe tot ce se apasă (pentru TalkBack / VoiceOver) și contrastul textului. Au găsit **11 zone de joc fără etichetă** (sesiunea 9) — reparate. Modul „contrast mare” (sesiunea 9) aduce butoanele text ale adultului la contrast WCAG ≥ 3:1.

Ce nu verifică testele automate: dacă un copil chiar înțelege instrucțiunea, dacă animațiile îl suprasolicită senzorial. Acestea țin de testarea cu utilizatori.

## 6. Ce rămâne de măsurat (și de ce încă nu)

| Măsurătoare | Blocată de | Cine deblochează |
|---|---|---|
| Teste e2e cu Postgres și Redis reale | Docker neinstalat pe calculatorul de dezvoltare | utilizatorul (README §0.0 A) |
| k6 — p95 al sincronizării | server de test | utilizatorul (VPS, §0.0 C) |
| Cadre pe secundă, acvariul, scanarea fișei cu poze reale | tabletă reală | utilizatorul (§0.0 A) |
| Utilitatea clinică (progres pe trepte la copii reali) | acord parental, validarea planului cu specialiști | semestrul 2 (§0.0 D, E) |

Pentru studiul cu utilizatori, metricile sunt deja în aplicație și pe server: independența pe treaptă, numărul de sesiuni până la stăpânire, generalizarea pe seturi de stimuli, menținerea la 7 și 30 de zile, oboseala în sesiune, dispoziția înainte/după (plan §4). Studiul nu cere instrumentare nouă — doar acord, timp și copii.

## 7. Rezumat pentru susținere (60 s)

*Ce am măsurat:* 921 de teste automate; peste 90% acoperire în nucleu (94%), aplicație și panou, 80–100% pe serviciile serverului care decid acces și consimțământ; calculul de pe ecranul principal sub 13 ms și pentru 24 de luni de date; 33 de ecrane verificate automat pentru accesibilitate. *Cum:* teste pe proprietăți, de contract între limbaje, de acces, pe mai multe dimensiuni de ecran și cap-coadă. *Ce lipsește:* încărcarea serverului (k6), fps pe tabletă reală și studiul cu copii — toate pregătite, blocate de infrastructură sau de acorduri, nu de cod.
