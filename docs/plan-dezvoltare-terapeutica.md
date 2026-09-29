# Planul de reorientare: de la „jocuri educative” la platformă de dezvoltare gamificată pentru copii cu TSA

Status: **Propus** (de validat cu utilizatorul și, ideal, cu 1–2 specialiști) · Data: 2026-09-29 · Decizii: [ADR-026](adr/ADR-026-trasee-de-dezvoltare-nu-clase.md), [ADR-027](adr/ADR-027-niveluri-generate-procedural.md)

> **Pe scurt.** Până acum am construit o colecție de jocuri organizată ca la școală (materii + clase).
> Pentru copiii cu TSA asta e greșit: un copil de 7 ani poate fi la nivelul de 2 ani la comunicare și la
> nivelul de 6 ani la potrivire vizuală. De aceea înlocuim **clasele și materiile** cu **arii de dezvoltare**,
> fiecare cu un **traseu de trepte** (de la mic la mare). Jocul rămâne atractiv, dar fiecare atingere a copilului
> devine o **încercare măsurată** (corect, cu ce ajutor, în cât timp). Specialistul vede **progresul pe trepte**,
> grafice ca în terapia ABA și **KPI-uri clare**, și trage el concluziile. Aplicația **nu pune diagnostice**.

---

## 1. Ce e greșit acum și ce schimbăm

| Acum (game dev) | Ținta (terapie gamificată) |
|-----------------|----------------------------|
| Jocuri grupate pe **materii** (română, matematică…) | Jocuri grupate pe **arii de dezvoltare** (atenție, potrivire, limbaj receptiv, emoții…) |
| Nivelul copilului = **clasa** (G, 1–4) | Nivelul copilului = **treapta** pe fiecare traseu, independent pe fiecare arie |
| Jocul se termină cu **stele** | Fiecare rundă e o **încercare** înregistrată: rezultat, nivel de ajutor, latență, stimul |
| Dificultate = `tier` (mai multe variante, numere mai mari) | Dificultate = **treaptă** (obiectiv concret) + **nivel de ajutor** (prompt) care scade treptat |
| Statistici „acuratețe pe abilitate” | **KPI-uri terapeutice**: independență, stăpânire, generalizare, menținere, latență, semne de oboseală |
| Specialistul „fixează jocuri” | Specialistul face o **evaluare inițială**, un **plan individual cu obiective**, urmărește graficele, decide |
| Catalog pe materii și clase, toate jocurile vizibile copilului | **Paleta de jocuri** (fără clase, fără materii) din care **specialistul alege** pentru fiecare copil doar ce îi trebuie (§5.1) |
| Ecranul copilului: listă de jocuri pe materii | Ecranul copilului: **doar jocurile alocate lui**, ca „Drumul de azi” (orar vizual cu 3–5 activități) + acvariul |

**Ce NU se pierde:** motorul (`ChoiceMechanic`, `Difficulty`, `AdaptiveRule`), vocea, animațiile, cele 12 jocuri,
backend-ul, sincronizarea, panoul cu două roluri, planurile (ADR-025), acvariul. Toate se refolosesc; se schimbă
**modelul de date din jurul jocurilor** și **ce măsurăm**.

---

## 2. Principii (se adaugă la cele din README §2)

1. **Copilul nu vede note, clase, eșec sau comparații.** Vede doar lumina care crește (licurici, felinare, acvariu).
2. **Fiecare interacțiune e o dată utilă**, dar colectăm **minimul necesar** (GDPR, §13): fără audio, video, cameră, text liber de la copil.
3. **Aplicația observă, specialistul concluzionează.** Sistemul poate *semnala* („stagnare de 5 sesiuni”), nu *diagnostica*.
4. **Practici bazate pe dovezi.** Fiecare funcție terapeutică se leagă de o practică recunoscută (§9): prompting, time delay,
   întărire, suporturi vizuale, instruire asistată de tehnologie, analiza sarcinii, modelare.
5. **Generalizare, nu memorare.** O treaptă e stăpânită doar dacă reușește pe **stimuli diferiți** (alt câine, alt desen, alt joc).
6. **Motivația copilului e o variabilă terapeutică**: interesul special (trenuri, dinozauri…) ca temă a stimulilor, alegerea între 2 activități, „întâi–apoi”.

---

## 3. Modelul de dezvoltare: arii → trepte → obiective → încercări

```
Arie de dezvoltare (ex. Potrivire vizuală)
 └─ Treaptă (ex. P3: potrivește imagine cu imagine, obiecte NEidentice, 3 variante)
     ├─ Criteriu de stăpânire (implicit: ≥ 80% independent, 2 sesiuni la rând, ≥ 2 seturi de stimuli)
     ├─ Exerciții = joc + parametri (ex. „Potrivește” {variante: 3, set: animale}, „Umbre” {…})
     └─ Încercări (fiecare rundă jucată): corect? cu ce ajutor? în cât timp? ce stimul?
Obiectiv (în planul copilului) = o treaptă aleasă de specialist + termen + criteriu (opțional modificat)
```

### 3.1 Ariile de dezvoltare (prima versiune)

Structura e **inspirată** de instrumentele folosite în terapie (VB-MAPP, ABLLS-R, Portage, PEP-3: arii, niveluri, repere),
**fără a le copia conținutul** (sunt protejate de drepturi de autor). Treptele de mai jos sunt ale noastre și trebuie
validate cu un specialist (§10).

| Cod | Arie | Ce dezvoltă | Mecanici |
|-----|------|-------------|----------|
| ATN | **Atenție și atenție comună** | orientare la stimul, urmărire, atenție susținută, direcția privirii | tap-țintă, urmărire, `choice` |
| IMI | **Imitație** | repetă o acțiune/secvență văzută | `sequence` (Simon), imitație de gesturi pe ecran |
| POT | **Potrivire și percepție vizuală** | identic → neidentic → categorie → asociere, figură–fond, puzzle | `choice`, `dragDrop`, `puzzle` |
| LRC | **Limbaj receptiv** | „Arată-mi…” obiecte, acțiuni, atribute, 2 elemente, prepoziții | `choice` cu instrucțiune vocală |
| COM | **Comunicare și limbaj expresiv (AAC)** | cerere (mand), denumire (tact), da/nu, propoziții cu pictograme | `freePlay` AAC, `choice` |
| COG | **Cogniție** | cauză–efect, permanența obiectului, categorii, secvențe, cantitate, mărime | `dragDrop`, `sequence`, `choice` |
| EMO | **Emoții și cogniție socială** | recunoaștere emoții → cauze → perspectivă (cine știe ce?) → situații sociale | `choice`, `explore` |
| FEX | **Funcții executive și autoreglare** | așteptare, inhibiție (go/no-go), flexibilitate (schimbă regula), memorie de lucru, respirație | joc go/no-go, sortare cu regulă schimbată, `sequence`, `respira` |
| AUT | **Autonomie și rutine** | secvențe de activități zilnice (spălat pe mâini, îmbrăcat), orar vizual | `sequence`, `dragDrop` |
| MOT | **Motricitate fină pe ecran** | tap precis, tragere, trasare | `trace`, `dragDrop` |
| PAC | **Pre-academic → academic** | pre-numerație → numere → operații; sunete → litere → citire | jocurile existente (numărăm, adunăm, alfabetul, povești…) |

**Catalogul complet (52 de jocuri pe arii, cu axe de dificultate, KPI specifici și paradigma din cercetare):** [catalog-jocuri-pe-arii.md](catalog-jocuri-pe-arii.md).

`PAC` înlocuiește materiile: jocurile de matematică și română **rămân**, dar ca trepte superioare, nu ca „clasa 2”.

### 3.2 Exemple de trasee (de la mic la mare)

**POT — Potrivire vizuală**
| Treaptă | Obiectiv | Exerciții |
|---------|----------|-----------|
| POT1 | Potrivește obiect identic, 2 variante | Potrivește {variante:2, identic} |
| POT2 | Obiect identic, 3–5 variante | Potrivește {variante:3→5} |
| POT3 | Obiect cu siluetă (umbră) | Umbre |
| POT4 | Obiecte **ne**identice (alt câine) | Potrivește {neidentic} |
| POT5 | Culori și forme pe obiecte diferite | Culori, Forme |
| POT6 | După categorie (animale / mâncare) | Grupăm, Sortare, Intrusul |
| POT7 | După asociere (periuță–pastă) | Perechi {asociere} |
| POT8 | Șiruri și modele (AB, ABC) | Modele |

**LRC — Limbaj receptiv**
| Treaptă | Obiectiv |
|---------|----------|
| LRC1 | Arată obiectul numit, 2 variante, obiecte foarte cunoscute |
| LRC2 | 3–5 variante, 20+ obiecte |
| LRC3 | Părțile corpului, acțiuni („cine doarme?”) |
| LRC4 | Atribute (mare/mic, culoare + obiect: „mingea roșie”) |
| LRC5 | Două elemente („arată câinele și mingea”) |
| LRC6 | Prepoziții și poziții (sus, jos, în, lângă) |
| LRC7 | Întrebări despre o scenă (cine? ce? unde?) → Povești |

**EMO — Emoții**
| Treaptă | Obiectiv |
|---------|----------|
| EMO1 | Bucuros vs trist, 2 variante, același personaj |
| EMO2 | 4 emoții de bază, personaje diferite (generalizare) |
| EMO3 | Emoția din situație („i s-a spart balonul”) |
| EMO4 | Ce poate face ca să se simtă mai bine (strategii) |
| EMO5 | Perspectivă: „ce crede Ana că e în cutie?” |
| EMO6 | Situații sociale (a cere, a aștepta rândul, a spune nu) |

**FEX — Funcții executive**
| Treaptă | Obiectiv |
|---------|----------|
| FEX1 | Așteaptă semnalul (felinarul se aprinde) înainte de a atinge |
| FEX2 | Go/no-go: atinge peștii, nu și meduzele |
| FEX3 | Sortare după o regulă (culoare) |
| FEX4 | Regula se schimbă (acum după formă) — flexibilitate |
| FEX5 | Memorie de lucru: secvență 2 → 5 elemente (Simon) |
| FEX6 | Autoreglare: exercițiul de respirație, cerut singur la nevoie |

**PAC — Numerație (fost „Matematică”)**
PAC-N1 potrivire cantități mici (1–3) → N2 numără până la 5 → N3 cifra ↔ cantitatea → N4 compară (mai mult/mai puțin) →
N5 numără până la 10/20 → N6 adunare cu obiecte → N7 scădere cu obiecte → N8 adunare fără obiecte → …
(jocurile existente: Numărăm, Comparăm, Adunăm, Scădem).

Traseele sunt **date** (JSON), nu cod: `packages/game_content/trasee/<arie>.json`. Un joc nou se leagă de una sau mai multe trepte.

### 3.3 Ierarhia de ajutor (prompting) în aplicație

Aceasta e piesa care transformă un „joc” într-o **sesiune de terapie** măsurabilă.

| Nivel | Ce face aplicația | În ABA |
|-------|-------------------|--------|
| **P4 – model complet** | mâna animată atinge răspunsul, copilul repetă | prompt fizic/model |
| **P3 – indicare** | răspunsul corect pulsează / e luminat | prompt gestual |
| **P2 – reducere variante** | distractorii se estompează (deja există: învățare fără eroare) | prompt de poziție/stimul |
| **P1 – indiciu** | indiciul vocal neutru („Uită-te la urechi”) | prompt verbal |
| **P0 – independent** | fără ajutor | răspuns independent |

- **Treaptă nouă:** de la mult la puțin (P4 → P0), cu **întârziere progresivă** (0 s, apoi 2 s, 4 s înainte de ajutor) — *time delay*.
- **Treaptă cunoscută:** de la puțin la mult (ajutorul vine doar după greșeală sau pauză lungă).
- Fiecare încercare salvează **nivelul maxim de ajutor primit**. KPI-ul principal devine **independența**, nu doar acuratețea.
- Specialistul poate fixa strategia pe obiectiv (ex. „fără P4, copilul se enervează la mâna animată”).

### 3.4 Structura unei sesiuni (nu „un joc”)

Motorul de sesiune construiește din plan o secvență scurtă (5–15 min, configurabilă):

1. **Orarul vizual** apare la început: 3–5 imagini („întâi potrivim, apoi emoții, apoi acvariu”). *Întâi–apoi.*
2. **Încălzire:** 2–3 încercări dintr-o treaptă deja stăpânită (succes sigur = impuls comportamental).
3. **Blocuri țintă:** încercări din obiectivele active, **amestecate** cu itemi stăpâniți (~70% cunoscut / 30% nou), ca să nu apară frustrarea.
4. **Verificări de menținere:** din când în când, o treaptă stăpânită acum 7/30 de zile.
5. **Pauze:** butonul „pauză” (mereu vizibil) → exercițiul de respirație / ecran calm. Folosirea lui e o dată (autoreglare), nu un eșec.
6. **Final pe succes** + recompensa (stele → acvariu).

Copilul poate **alege** între 2 activități acolo unde specialistul permite (alegerea e și ea un obiectiv de comunicare).

### 3.5 Niveluri generate algoritmic, infinite și fără repetări

Un joc **nu** are 5–10 niveluri scrise de mână. Are un **generator** care produce la cerere un nivel nou, exact pe măsura
copilului, de fiecare dată altul. Aplicația nu e o carte citită din nou: e un antrenor care propune mereu pasul următor.

#### a) Dificultatea e un vector de axe, nu un singur număr

Acum `Difficulty(tier)` e un singur număr care crește variantele (2→5) și plafonul numeric. E prea sărac. Fiecare joc își
declară **axele de dificultate**, iar un nivel = un punct în spațiul acestor axe.

| Joc / tip | Axe de dificultate (exemple) |
|-----------|------------------------------|
| Potrivire | nr. variante · **asemănarea distractorilor** (altă categorie → aceeași categorie → aceeași formă și culoare) · identic / neidentic · rotire, oglindire · fundal aglomerat · mărimea țintelor |
| Limbaj receptiv | nr. variante · familiaritatea cuvântului · lungimea instrucțiunii (1 → 2 → 3 elemente: „mingea **roșie** **sub** masă”) · asemănarea distractorilor |
| Emoții | nr. emoții · intensitate (evidentă → subtilă) · personaje diferite · indicii (față → față + context → doar context) |
| Go / no-go | viteză · proporția no-go (10% → 40%) · asemănarea „nu atinge” cu „atinge” · schimbarea regulii |
| Memorie (Simon) | lungimea secvenței · viteza · nr. poziții · sunete + culori sau doar culori · ordine inversă |
| Labirint | dimensiune · ramificații · fundături · capcane vizuale · drumul nemarcat |
| Puzzle | nr. piese · forma pieselor · rotire · model vizibil sau nu |
| Numerație | interval · cu obiecte / fără · trecere peste ordin · operații compuse · distractori apropiați (7 vs 8) |

**Treapta** (§3.2) fixează axele **calitative** (ex. POT4 = neidentic). În interiorul treptei, generatorul mișcă **continuu** axele
**cantitative** (variante, asemănare, viteză). Așa, între două trepte există zeci de micro-niveluri, iar trecerea e lină.

#### b) Nivelul copilului e un rating care se ajustează după fiecare încercare

- Fiecare copil are un **rating pe fiecare treaptă** (număr real). Fiecare nivel generat are o **dificultate estimată** din axe.
- După fiecare încercare, rating-ul se ajustează ca la șah (**Elo**): reușește un nivel greu → crește mult; greșește unul ușor → scade.
  Același principiu funcționează la scară mare în Math Garden (Klinkenberg et al., 2011), o platformă adaptivă pentru copii.
- Generatorul caută nivelul la care copilul are **~80% șanse de reușită**: destul de greu ca să învețe, destul de ușor ca să nu
  se frustreze (important la TSA; specialistul poate cere 90% pentru un copil sensibil la eșec).
- Nivelul de ajutor (P0–P4) intră în calcul: o reușită cu ajutor contează puțin.
- `AdaptiveRule` (fereastra de 20 de încercări) rămâne ca plasă de siguranță, iar trecerea la treapta următoare rămâne decizia
  criteriului de stăpânire + a specialistului.
- În semestrul 2, dificultatea reală a nivelurilor se **calibrează din date** (IRT sau Elo pe itemi, din agregate pseudonimizate) —
  subiect bun de cercetare pentru teză (`07-dificultate-adaptiva.md`).

#### c) Conținut combinatoriu: stimuli cu atribute + reguli

Conținutul nu mai e o listă de întrebări, ci o **bază de stimuli cu atribute**, din care generatorul compune întrebări după reguli:

```json
{ "id": "minge_rosie", "art": "minge", "categorie": "jucarii", "culoare": "rosu", "forma": "cerc",
  "marime": "mica", "gen": "f", "forme": { "art": "mingea", "adj_rosu": "roșie" }, "familiar": 1 }
```

- **Distractorii** se aleg după atribute: pentru un nivel ușor, din altă categorie; pentru unul greu, aceeași categorie și culoare.
- **Instrucțiunile** se compun dintr-o gramatică mică („Arată” + articol + substantiv + adjectiv acordat + prepoziție…); vocea se
  compune din fragmente pre-generate (sistemul `speak: [...]` există deja).
- **Ilustrațiile** devin combinabile: personaj × emoție × accesoriu × fundal (straturi PNG/SVG compuse și animate din cod — ADR-028).
  Exemplu: 3 personaje × 6 emoții × 4 intensități × 10 contexte = **720 de imagini diferite** din ~30 de piese desenate.
- Exemplu de volum: 200 de stimuli × 5 niveluri de asemănare × 4 poziții × teme → **zeci de mii** de runde distincte pentru o
  singură treaptă de potrivire.

#### d) Fără repetări (dar cu repetarea bună)

- **Istoric per copil:** ce combinații a văzut (hash de stimul + distractori + așezare). Generatorul le evită până la epuizarea
  spațiului (practic niciodată).
- **Repetarea bună = repetarea spațiată.** Itemii greșiți revin după intervale crescătoare (1 zi, 3, 7, 30 — sistem Leitner),
  **dar în altă formă** (alt desen, alte variante, altă poziție). Copilul exersează ce trebuie, fără să memoreze poziția răspunsului.
- **Anti-tipare:** răspunsul corect nu stă de 3 ori la rând pe aceeași poziție; niciun distractor nu apare suspect de des.
- **Variabilitatea e un parametru al specialistului:** unii copii cu TSA au nevoie de previzibilitate. Structura sesiunii rămâne
  mereu aceeași; cât variază conținutul se reglează (puțin → mult). Creșterea treptată a variabilității e ea însăși un obiectiv
  (flexibilitate).

#### e) Determinism: orice nivel poate fi reprodus

- Un nivel = `(generatorId, versiune, treaptă, parametri, seed)`. Același seed → exact același nivel (`GameContext.random` e
  deja injectat).
- Încercarea (`trial`) salvează seed-ul → specialistul poate **revedea exact ce a văzut copilul** când a greșit.
- Teste: pentru fiecare generator, **10 000 de seed-uri** pe tot spațiul de axe → un singur răspuns corect, fără ambiguități, fără
  distractori identici, voce și ilustrații existente pentru tot ce se afișează, dificultatea crește monoton pe axe.

#### f) Ce vede copilul

Copilul **nu vede numere de nivel**. Vede o cărare care nu se termină: fiecare sesiune adaugă bucăți noi pe hartă, felinare
noi, pești noi. Progresul real (treapta, rating-ul) îl vede doar adultul.

#### g) AI: doar la crearea materialului, nu la rulare (decizia din README §2.1 rămâne)

AI-ul poate genera **atribute, liste de cuvinte, scene, povești sociale**, pe care un om le verifică și le adaugă în baza de
stimuli. Generatorul care rulează pe tabletă e **algoritmic**: gratuit, offline, previzibil, testat.

---

## 4. Ce măsurăm: evenimente și KPI-uri

### 4.1 Evenimentul de încercare (`trial`)

Singurul eveniment de bază; totul se calculează din el (event sourcing, ADR-011).

| Câmp | Exemplu | De ce |
|------|---------|-------|
| `sessionId`, `childId` (UUID) | — | pseudonimizare |
| `stepId`, `gameId`, `config` | `POT4`, `potriveste`, `{variante:3}` | legătura cu traseul |
| `seed`, `axes`, `rating` | `83412`, `{asemanare:0.7}`, `1340` | nivelul exact, reproductibil (§3.5) |
| `stimulusId`, `stimulusSet` | `caine_2`, `animale_b` | generalizare |
| `correct` | `true` | acuratețe |
| `promptLevel` | `P0`…`P4` | independență |
| `attempts` | `1` | corect din prima |
| `latencyMs` | `2400` (de la finalul instrucțiunii) | viteză de procesare, ezitare |
| `selfCorrected` | `false` | autocorectare |
| `offTargetTaps` | `3` | impulsivitate / motricitate |
| `idleMs` | `0` | atenție, abandon |
| `mode` | `plan` / `liber` / `evaluare` / `live` | contextul |
| `at` | timestamp | tendințe, ora din zi |

Evenimente de sesiune: `session_start` / `session_end` (durată, câte blocuri terminate), `pause_requested`, `session_abandoned`,
`choice_made` (ce a ales copilul când a avut de ales), `reward_spent`. **Fără text liber, audio sau imagini ale copilului.**

### 4.2 KPI-uri (calculate de worker în `child_skill_stats` / read model, §10)

| KPI | Formula | Ce îi spune specialistului |
|-----|---------|----------------------------|
| **Acuratețe** | corecte / încercări, pe treaptă, pe sesiune | nivelul de reușită |
| **Independență** | încercări corecte cu P0 / încercări | cât depinde de ajutor (cel mai important) |
| **Nivel mediu de ajutor** | media `promptLevel` pe sesiune | estomparea ajutorului în timp |
| **Latență** | mediana `latencyMs` (nu media, e robustă) | ezitare, automatizare |
| **Stăpânire** | criteriul atins (ex. ≥ 80% P0, 2 sesiuni, 2 seturi de stimuli) | treaptă gata |
| **Timp până la stăpânire** | sesiuni / încercări de la start până la criteriu | ritmul de învățare, pe arii |
| **Generalizare** | nr. seturi de stimuli / jocuri distincte cu ≥ 80% | învățare reală vs memorare |
| **Menținere** | acuratețe la verificările de la 7/30 zile | ce se uită |
| **Stabilitate** | abaterea acurateței între sesiuni | zile bune/rele, factori externi |
| **Oboseală în sesiune** | panta acurateței/latenței în interiorul sesiunii | durata optimă a sesiunii |
| **Implicare** | sesiuni terminate / începute, pauze cerute, abandonuri, rejucări voluntare | motivație, toleranță |
| **Impulsivitate** | `offTargetTaps`, răspunsuri < 500 ms greșite | atenție, inhibiție |
| **Profilul de dezvoltare** | treapta curentă pe fiecare arie (grafic radar/bare) | imaginea de ansamblu, inegalitățile |
| **Atingerea obiectivelor (GAS)** | scor −2…+2 pe obiectiv, la revizuire | evaluare standard a planurilor individuale |

**Reguli de semnalare** (sistem de reguli în `licurici_core`, testat; niciun AI):
- **Stagnare:** 5 sesiuni pe aceeași treaptă fără creștere a independenței → „ia în calcul alt exercițiu sau alt tip de ajutor”.
- **Dependență de ajutor:** acuratețe > 80% dar independență < 40% → „estompează ajutorul mai repede / time delay”.
- **Regres la menținere:** o treaptă stăpânită scade sub 60% → „reintrodu în plan”.
- **Oboseală:** acuratețea scade constant după minutul X → „sesiuni mai scurte”.
- **Gata de urcat:** criteriu atins → „propune treapta următoare” (specialistul confirmă; sau automat, dacă a permis).

---

## 5. Fluxul specialistului (panoul web, rolul `THERAPIST`)

```
Evaluare inițială → Plan individual → Sesiuni (acasă / la cabinet / live) → Monitorizare → Revizuire → Raport
        ↑_____________________________________________________________________________|
```

1. **Evaluarea inițială (plasarea pe trasee).** Un mod `evaluare`: sondaje scurte pe fiecare arie (3–5 încercări pe treaptă,
   fără ajutor, fără recompensă condiționată), care urcă până la primul eșec. Rezultat: **profilul de dezvoltare** (treapta pe fiecare arie).
   Nu e un test standardizat și nu se prezintă ca atare — e un punct de plecare, pe care specialistul îl corectează.
2. **Planul individual** (extinde ADR-025): 3–6 **obiective** = trepte + criteriu + termen + strategia de ajutor + exercițiile
   (jocuri + parametri generate din `GameConfig`) + temele de interes ale copilului.
3. **Sesiunile:** copilul joacă planul offline, acasă. La cabinet: **sesiune live** (WebSocket) — specialistul vede încercările în
   timp real și poate nota manual un ajutor fizic dat sau un comportament (listă închisă: „a cerut pauză”, „agitat”, „a vocalizat”).
4. **Monitorizarea:**
   - **Graficul ABA pe obiectiv:** % pe sesiune, linia criteriului, **linii de schimbare de fază** (când s-a schimbat exercițiul/ajutorul).
   - Profilul de dezvoltare (evoluție lunară), KPI-urile din §4.2, semnalările.
   - Detaliu pe încercări (ce stimul a greșit de mai multe ori → erori sistematice, ex. confundă „trist” cu „supărat”).
5. **Revizuirea:** la termen, scor **GAS** pe fiecare obiectiv, obiective noi.
6. **Rapoarte:** PDF pentru specialist (cu grafice, pentru dosar / comisie) și **versiunea pentru părinte** (limbaj simplu, fără jargon,
   „ce a reușit luna asta”, ce se poate exersa acasă). Generate de worker (BullMQ).
7. **Asistentul AI** (semestrul 2, deja decis): răspunde pe **statisticile agregate și pseudonimizate**, ajută la redactarea raportului.
   Nu decide nimic.

**Părintele** vede: drumul copilului (versiunea simplă a profilului), timpul de joc, raportul, recomandările specialistului pentru acasă.

---

### 5.1 Paleta de jocuri și alocarea pe copil

**Nu există clase, materii sau „toate jocurile pentru toți”.** Există o **paletă** (toate jocurile platformei) pe care o vede
doar adultul. Specialistul alege din ea, pentru fiecare copil, **doar jocurile de care are nevoie**. Copilul vede numai ce i s-a alocat.

**Pagina „Jocuri” din panoul specialistului:**
- **Paleta:** carduri cu fiecare joc (imagine, descriere scurtă, ce dezvoltă). Filtre după **arie**, **treaptă**, mecanică
  (atingere, tragere, secvență…), cerințe (fără citire, fără sunet, motricitate fină). Căutare după nume sau abilitate.
- **Previzualizare:** specialistul joacă 1–2 runde demonstrative direct în panou, la treapta aleasă, înainte să aloce jocul.
- **Recomandări:** după profilul copilului (§5, pasul 1), paleta evidențiază jocurile potrivite treptelor lui actuale.
  Doar sugestii, alegerea rămâne a specialistului.
- **Alocarea pe copil** (drag & drop sau „Adaugă la copil”):
  - treapta / obiectivul pe care îl servește;
  - parametrii din `GameConfig` (formular generat automat, ADR-025): treapta de pornire, limite ale axelor de dificultate (§3.5),
    variabilitatea, strategia de ajutor, tema de interes, durata sau nr. de runde;
  - frecvența (zilnic / de 3 ori pe săptămână) și ordinea în sesiune;
  - dacă jocul e **obligatoriu în Drumul de azi** sau **la alegerea copilului** (copilul alege între 2–3 jocuri alocate).
- **Lista copilului:** jocurile alocate, cu starea fiecăruia (activ, pus pe pauză, stăpânit → mutat la menținere, scos).
  Specialistul poate pune pe pauză un joc care îl agită pe copil, fără să piardă datele.
- **Șabloane:** specialistul își salvează seturi („început potrivire + receptiv”) și le aplică la alți copii, apoi le ajustează.
- **Istoric de modificări:** fiecare adăugare/scoatere/schimbare de parametri apare ca **linie de schimbare de fază** în graficele
  copilului (§5, pasul 4), ca să se vadă efectul deciziei.

**Fără specialist** (părinte fără cont de specialist sau aplicația fără cont): părintele are aceeași paletă, simplificată,
cu un **set de pornire** propus după evaluarea inițială. Când părintele invită un specialist, acesta preia alocarea
(părintele vede ce s-a ales, nu poate modifica planul fără acord, dacă specialistul a blocat planul).

**În aplicația copilului:** niciun catalog, nicio listă de categorii. Doar jocurile alocate lui (Drumul de azi + cele „la alegere”)
și acvariul. Un joc nou alocat apare la următoarea sincronizare, cu o mică animație de „cadou” de la Licurici.

## 6. Atractivitatea pentru copil (fără să strice terapia)

- **Metafora Licurici:** fiecare arie e o **cărare** pe hartă; fiecare treaptă stăpânită **aprinde un felinar**. Copilul vede cum
  se luminează lumea, nu vede „nivelul 4”. Nimic nu se stinge la greșeală.
- **Acvariul** rămâne economia de jetoane (stele → pești/hrană), predictibilă, cu „întâi–apoi”.
- **Interese speciale:** temă de stimuli pe copil (vehicule, animale, dinozauri, spațiu). Pentru stimulii tematici folosim seturi
  suplimentare de ilustrații (ADR-024). Acesta e unul dintre cei mai puternici factori de motivație la copiii cu TSA.
- **„Suc” (juice) dar controlat:** reacții la atingere, mascota care se bucură, micro-animații < 1 s (§15.1); totul redus în modul calm.
- **Varietate de stimuli** = mai atractiv **și** generalizare. Lucrul de game dev (ilustrații, variante) servește direct terapia.
- **Predictibilitate:** aceeași structură în fiecare sesiune, orar vizual, avertizare înainte de final („încă 2”).

---

## 7. Schimbări tehnice

### 7.1 `licurici_core`
- `Domain` (ariile), `Step` (treaptă: id, arie, ordine, descriere, criteriu implicit), `Ladder` (traseu încărcat din JSON).
- `GameSpec`: scoatem `subject` și `grades`; adăugăm `steps` (treptele pe care le servește) și `GameConfig` (ADR-025).
  `Grade` și `Subject` dispar din UI-ul copilului. `Difficulty.tier` rămâne parametru intern al jocului, fixat de treaptă.
- `PromptLevel` (P0–P4) + `PromptStrategy` (mult→puțin, puțin→mult, time delay).
- `Trial` (evenimentul din §4.1) + `MasteryCriterion` + `MasteryEvaluator` (Dart pur, testat).
- `SessionPlanner`: construiește sesiunea (încălzire, țintă, amestec 70/30, menținere, final pe succes).
- `SignalRules`: regulile din §4.2 (Dart pur, partajate logic cu worker-ul; sursa adevărului pe server e worker-ul).
- `AdaptiveRule` existent rămâne plasă de siguranță; ajustarea fină o face rating-ul (§3.5).
- **Generarea procedurală (§3.5, ADR-027):** `DifficultyAxes` (axele declarate de fiecare joc, înlocuiesc `tier` în jocurile noi;
  `Difficulty` rămâne pentru compatibilitate), `SkillRating` (Elo pe copil × treaptă), `LevelGenerator` (axe + seed → nivel),
  `StimulusBank` (stimuli cu atribute, din JSON), `ExposureHistory` + `SpacedReview` (Leitner), teste pe 10 000 de seed-uri.

### 7.2 Aplicația copilului
- Ecran principal: **Drumul de azi** + jocurile „la alegere” — **numai jocurile alocate copilului** (§5.1) — + **Harta cu felinare** + **Acvariu**.
  Dispar complet alegerea clasei, materiile și catalogul din zona copilului. Paleta e doar în zona adultului (poartă parentală).
- Ierarhia de ajutor în `ChoiceMechanic` (mâna animată, pulsare, estompare, indiciu, întârziere).
- Butonul permanent de **pauză**, orarul vizual, avertizarea de final.
- Drift: `trials`, `sessions`, `plan_objectives`, `ladder_progress`, outbox.

### 7.3 Backend
- Tabele: `domains`, `steps` (din JSON, versionate), `objectives` (planul), `trials` (partiționat lunar), `mastery_records`,
  `observations` (listă închisă de comportamente, de la specialist), `gas_scores`.
- Worker: calculul KPI-urilor la ingestia evenimentelor (coada `stats`), semnalările, rapoartele PDF.
- API: `/children/:id/profile`, `/children/:id/objectives`, `/objectives/:id/chart`, `/children/:id/signals`, `/reports`.

### 7.4 Modelul de date (actualizare README §11) — schiță
```
CHILD ||--o{ ASSIGNMENT       (gameId, objectiveId?, config, frecvență, obligatoriu/la alegere, status, assignedBy)
CHILD ||--o{ OBJECTIVE        (stepId, criteriu, termen, strategie ajutor, status, gas)
CHILD ||--o{ LADDER_PROGRESS  (domain, currentStep, masteredAt[])
GAME_SESSION ||--o{ TRIAL     (stepId, gameId, stimulusId, correct, promptLevel, attempts, latencyMs, …)
OBJECTIVE ||--o{ PHASE_CHANGE (at, ce s-a schimbat)  — pentru liniile din graficul ABA
CHILD ||--o{ OBSERVATION      (de la specialist: cod din listă închisă, at)
```

---

## 8. Date, lege, etică (atenție, se schimbă încadrarea)

1. **Date privind sănătatea.** În clipa în care un specialist folosește platforma într-un **context terapeutic**, datele de progres și
   observațiile pot deveni **date privind sănătatea** (categorie specială, art. 9 GDPR / Legea 195/2024). Consecințe:
   consimțământ **explicit** separat pentru partajarea cu specialistul, DPIA obligatorie, criptarea observațiilor, audit pe fiecare
   acces, păstrăm regula „fără diagnostic în baza de date”. De actualizat §13.3 și `docs/gdpr/dpia.md`.
2. **Dispozitiv medical?** Un software destinat **diagnosticului sau tratamentului** poate intra sub **Regulamentul (UE) 2017/745 (MDR)**
   (regula 11). Ca să rămânem în afara lui (fezabil pentru o licență), platforma se prezintă ca **instrument educațional și de
   suport pentru specialist**: colectează observații, **nu pune diagnostic, nu recomandă tratament automat**, deciziile sunt ale
   specialistului. Formulările din aplicație, magazin și teză trebuie să respecte asta („exersează”, „urmărește progresul”,
   nu „tratează autismul”). De scris un ADR/secțiune separată; de verificat cu coordonatorul.
3. **Etica testării** (§13.6): pilotul cu copii doar cu acord scris, prin specialist, anonimizat.

---

## 9. Legătura cu practicile bazate pe dovezi (argument pentru teză)

Raportul NCAEP (Steinbrenner et al., 2020) listează 28 de practici bazate pe dovezi pentru TSA. Funcțiile platformei se leagă direct:

| Practică (NCAEP 2020) | Unde apare în Licurici |
|------------------------|------------------------|
| Prompting (PP) | ierarhia P4–P0 (§3.3) |
| Time Delay (TD) | întârzierea progresivă a ajutorului |
| Reinforcement (R) | recompensa < 1 s, stele, acvariu, „întâi–apoi” |
| Discrete Trial Training (DTT) | încercările structurate, datele pe încercare |
| Visual Supports (VS) | orarul vizual, pictogramele AAC, instrucțiuni vizuale |
| Technology-Aided Instruction (TAII) | toată platforma |
| Task Analysis (TA) | traseele AUT (rutine pe pași) |
| Modeling / Video Modeling (MD/VM) | mâna animată, secvențele animate de imitație |
| Antecedent-Based Intervention (ABI) | amestecul 70/30, interese speciale, alegerea activității, modul calm |
| Augmentative & Alternative Communication (AAC) | aria COM |
| Social Narratives (SN) | Povești sociale în aria EMO |

Pentru teză: documentul `docs/research/06-ux-autism.md` se extinde cu acest tabel și cu referințele exacte (de verificat pe sursa originală).

---

## 10. Validarea cu specialiști (obligatoriu, altfel rămâne „game dev”)

- Găsim **1–2 specialiști** (psihopedagog / logoped / terapeut ABA; ex. centre din Chișinău sau prin coordonator) pentru:
  1. revizuirea ariilor și treptelor (2 întâlniri de 1 h, pe documentele JSON transformate în tabel);
  2. revizuirea KPI-urilor și a graficelor din panou (machetă);
  3. un pilot scurt în semestrul 2 (cu acord parental).
- Măsurăm: **SUS** (utilizabilitatea panoului pentru specialiști), timpul de configurare a unui plan, dacă graficele îi ajută să ia
  decizii (interviu scurt). Rezultatele intră în `docs/research/08-evaluare.md`.

---

## 11. Roadmap revizuit (înlocuiește prioritățile din README §21, termenul de 70% rămâne decembrie)

### Sprint 2 · până la 25 oct — Modelul de dezvoltare
- [ ] ADR-026 acceptat; README §2, §11, §15, §16 actualizate (arii în loc de materii/clase)
- [x] `Domain`, `Step` (`LadderStep`), `Ladder` + JSON pentru 4 trasee: **POT, LRC, EMO, PAC-numerație** (validate ulterior)
- [ ] Cele 12 jocuri re-etichetate pe trepte; câte un folder per joc + `GameConfig`
- [x] `Trial` + `PromptLevel` + ierarhia de ajutor în `ChoiceMechanic`; `MasteryEvaluator` cu teste
- [ ] Generarea procedurală: `DifficultyAxes`, `SkillRating` (Elo), `StimulusBank` cu atribute, istoric anti-repetare; aplicate pe Potrivire, Emoții, Numerație — 🟨 piesele + Potrivire gata; Emoții, Numerație urmează
- [ ] Drift: sesiuni, încercări, progres pe trasee, outbox

### Sprint 3 · 26 oct – 8 nov — Sesiunea terapeutică + conturi
- [ ] `SessionPlanner` (încălzire, 70/30, menținere, final pe succes), orar vizual, pauză, „întâi–apoi”
- [ ] Modul `evaluare` (plasarea pe trasee)
- [ ] Ecranul „Drumul de azi” cu **doar jocurile alocate** (tabela locală `assignments`) + harta cu felinare (variantă simplă); alocarea locală de către părinte (paleta simplificată)
- [ ] Auth părinte, consimțăminte (inclusiv cel explicit pentru specialist), sincronizare `/sync/events`

### Sprint 4 · 9 – 22 nov — Mecanici pentru trasee noi
- [ ] `DragDropMechanic`, `SequenceMechanic`, `MemoryCardsMechanic`, mecanica **go/no-go**
- [ ] Trasee FEX, COG, ATN + jocurile lor (Potrivește, Umbre, Grupăm, Sortare, Memorie/Simon, Ce urmează?, Go/no-go)
- [ ] Worker: KPI-urile din §4.2 + semnalările

### Sprint 5 · 23 nov – 6 dec — Panoul specialistului
- [ ] Rolurile părinte/specialist, invitare, `CARE_LINK` + audit
- [ ] **Pagina „Jocuri”**: paleta cu filtre pe arii/trepte, previzualizare, alocare pe copil cu parametri, șabloane, istoric (§5.1)
- [ ] Profilul de dezvoltare, planul cu obiective (formular din `GameConfig`), **graficul ABA** cu linii de fază, semnalările
- [ ] Sesiunea live (WebSocket) + observații din listă închisă

### Sprint 6 · 7 – 20 dec — Rapoarte, GDPR, demo = **70%**
- [ ] Raport PDF (specialist + părinte), scor GAS la revizuire
- [ ] GDPR actualizat pentru date de sănătate (DPIA, consimțământ explicit), export/ștergere
- [ ] Producție (Docker, Traefik), demo cu un scenariu complet: evaluare → plan → 2 săptămâni de date simulate → grafice → raport

### Semestrul 2
- [ ] Trasee COM (AAC), IMI, AUT, MOT; restul jocurilor ca exerciții pe trepte
- [ ] Validare cu specialiști + pilot; iterații pe trepte și KPI
- [ ] Interese speciale (seturi tematice de ilustrații), acvariul complet, asistentul AI pentru adulți
- [ ] Teza: capitolele despre modelul de dezvoltare, KPI, practici bazate pe dovezi, evaluare

**Ce scoatem sau amânăm:** alegerea clasei și catalogul pe materii (înlocuite de paleta + alocarea de către specialist, §5.1), **clasele 5–12** (decizia din §2.1 se retrage:
contrazice focusul pe dezvoltare), „Aventura” cu niveluri infinite (înlocuită de harta cu felinare).

---

## 12. Riscuri

| Risc | Ce facem |
|------|----------|
| Treptele inventate de noi nu sunt corecte clinic | validare cu specialiști (§10); traseele sunt date JSON, ușor de corectat |
| Prea mult de făcut până în decembrie | 4 trasee complete în S1, restul în S2; demo cu date simulate |
| Aplicația e percepută ca dispozitiv medical | formulări de „suport”, fără diagnostic/tratament automat (§8.2) |
| Datele devin date de sănătate | consimțământ explicit, DPIA, criptare, audit (§8.1) |
| Copilul se plictisește de exerciții repetitive | varietate de stimuli, interese speciale, sesiuni scurte, alegere, acvariu |
| Generatorul produce niveluri ambigue sau greșite | validatori + teste pe 10 000 de seed-uri; seed-ul salvat pentru reproducere |
| Prea multă variație deranjează copilul | variabilitatea e parametru al specialistului; structura sesiunii rămâne fixă |
| KPI-uri greșite din date puține | criterii cu număr minim de încercări; afișăm „date insuficiente” în loc de procente false |
