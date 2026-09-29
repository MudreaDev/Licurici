# Catalogul de jocuri pe arii de dezvoltare (52)

Status: **Propus** · Data: 2026-09-29 · Legat de: [plan-dezvoltare-terapeutica.md](plan-dezvoltare-terapeutica.md) (§3, §3.5, §4, §5.1), ADR-026, ADR-027.

Acesta e **paleta** din care specialistul alege jocurile fiecărui copil (plan §5.1). Nu are clase sau materii: fiecare joc
aparține unei **arii de dezvoltare**, acoperă un interval de **trepte**, își generează nivelurile **algoritmic** pe **axe de
dificultate** (plan §3.5) și trimite **încercări** din care se calculează KPI-urile (plan §4).

Jocurile se bazează pe **paradigme din cercetare** (sarcini validate în psihologia dezvoltării și în studiile pe TSA), îmbrăcate
într-un joc atractiv. Asta e diferența față de „game dev”: fiecare joc măsoară ceva cunoscut, iar rezultatele pot fi
interpretate de specialist.

> ⚠️ Jocurile **nu sunt teste standardizate** și nu se folosesc pentru diagnostic. Paradigmele sunt folosite pentru exersare și
> pentru observarea progresului în timp; interpretarea aparține specialistului (plan §8).

---

## 1. Ce are fiecare joc (contractul comun)

| Element | Conținut |
|---------|----------|
| **Arie + trepte** | ex. `FEX2–FEX4`; specialistul alege treapta de pornire |
| **Axe de dificultate** | 3–6 axe, fiecare cu interval și direcție („mai greu = …”); treapta fixează axele calitative |
| **Generator** | combinatoriu (bază de stimuli cu atribute), procedural (labirint, puzzle) sau parametric (timp, viteză) — determinist cu seed |
| **Încercare** | câmpurile comune din plan §4.1 + câmpuri specifice jocului (mai jos) |
| **KPI comuni** | acuratețe · **independență** (P0) · nivel mediu de ajutor · latență mediană · stăpânire · generalizare · menținere · oboseală · implicare |
| **KPI specifici** | ce măsoară paradigma (ex. erori de comisie, span, costul schimbării) |
| **Parametri pentru specialist** (`GameConfig`) | treapta, limite pe axe, variabilitate, strategia de ajutor, tema de interes, durata |

**Legenda generatorului:** 🧩 combinatoriu (stimuli × atribute × reguli) · 🌀 procedural (structură generată: grilă, drum, piese) · ⏱ parametric (timp, viteză, proporții).

---

## 2. Catalogul

### ATN — Atenție și atenție comună (5)

| # | id | Joc (ce face copilul) | Trepte | Axe de dificultate | KPI specifici | Bază |
|---|----|------------------------|--------|--------------------|---------------|------|
| 1 | `prinde-licuriciul` | Licuriciul apare pe ecran; copilul îl atinge | ATN1–2 | poziție (centru → margini) · mărime · timp de afișare · distractori în fundal | timp de reacție, **variabilitatea** timpului de reacție, omisiuni | orientare la stimul, timp de reacție simplu ⏱ |
| 2 | `urmareste-pestele` | Un pește înoată; copilul îl atinge când se oprește | ATN2–3 | viteză · traiectorie (dreaptă → curbă → cu ocoliri) · pești asemănători | precizie la oprire, pierderi de urmărire | urmărire vizuală ⏱🌀 |
| 3 | `cauta-in-camera` | Găsește obiectul cerut într-o scenă | ATN2–4 | nr. distractori (3 → 30) · asemănarea distractorilor (culoare/formă) · aglomerare · obiect parțial ascuns | timp de căutare vs nr. distractori (panta), atingeri greșite | căutare vizuală (unde copiii cu TSA sunt adesea buni — punct forte de valorificat) 🧩🌀 |
| 4 | `unde-se-uita` | Personajul privește spre un obiect; copilul atinge obiectul | ATN3–5 | indiciu (arată cu mâna + privire → doar ochi → doar cap) · nr. obiecte · distanța între obiecte | acuratețe pe tip de indiciu, latență | atenție comună, urmărirea privirii (serious games cu avatar, RCT pe adolescenți TSA) 🧩 |
| 5 | `ce-s-a-schimbat` | Scena dispare scurt și revine cu o schimbare; copilul o găsește | ATN4–6 | nr. obiecte · tipul schimbării (apare/dispare → culoare → poziție) · durata pauzei | acuratețe pe tip de schimbare | detectarea schimbării, atenție susținută 🧩 |

### IMI — Imitație (3)

| # | id | Joc | Trepte | Axe | KPI specifici | Bază |
|---|----|-----|--------|-----|---------------|------|
| 6 | `fa-ca-licuriciul` | Licuriciul atinge/trage ceva pe ecran; copilul repetă | IMI1–3 | nr. acțiuni (1 → 3) · tip (atingere → tragere → cerc) · model vizibil / ascuns | acțiuni corecte în ordine, latență de pornire | imitație motorie cu model video/animat (modelare — EBP) ⏱ |
| 7 | `toba-magica` | Licuriciul bate un ritm la tobe; copilul îl repetă | IMI2–4 | lungime ritm · tempo · nr. tobe · pauze în ritm | abatere de timp (ms) față de ritm, lungimea maximă reprodusă | imitație ritmică, sincronizare ⏱ |
| 8 | `construieste-la-fel` | Copiază un model din cuburi/forme | IMI3–6 | nr. piese · culori similare · rotire · model dispare după X s | piese corecte, nr. mutări vs optim | copiere vizuo-constructivă (tip „block design”) 🌀 |

### POT — Potrivire și percepție vizuală (5)

| # | id | Joc | Trepte | Axe | KPI specifici | Bază |
|---|----|-----|--------|-----|---------------|------|
| 9 | `potriveste` | Pune obiectul lângă perechea lui (identic → neidentic → culoare → formă → categorie) | POT1–6 | nr. variante · **asemănarea distractorilor** · identic/neidentic · rotire · dimensiunea criteriului (obiect, culoare, formă, categorie) | confuzii frecvente (matrice stimul × ales) | potrivire după model (match-to-sample, DTT) 🧩 — include actualele `culori`, `forme` |
| 10 | `umbre` | Găsește umbra obiectului | POT3–5 | siluete asemănătoare · detaliu intern (plin → contur) · rotire | acuratețe pe tip de siluetă | figură–fond 🧩 |
| 11 | `puzzle` | Puzzle din orice imagine a bazei | POT4–8 | nr. piese (2 → 24) · forma pieselor (benzi → pătrate → jigsaw) · rotire · model vizibil | mutări / piesă, timp / piesă | percepție spațială 🌀 |
| 12 | `gaseste-diferenta` | Două scene, găsește diferențele | POT5–8 | nr. diferențe · mărimea diferenței · aglomerarea scenei | diferențe găsite / timp, atingeri greșite | discriminare vizuală 🧩🌀 |
| 13 | `forma-ascunsa` | Găsește o formă ascunsă într-un desen complex | POT6–8 | complexitatea desenului · nr. linii care trec prin formă · rotire | timp de găsire | figuri încastrate (embedded figures — tot un punct forte frecvent la TSA) 🌀 |

### LRC — Limbaj receptiv (5)

| # | id | Joc | Trepte | Axe | KPI specifici | Bază |
|---|----|-----|--------|-----|---------------|------|
| 14 | `arata-mi` | „Arată mingea” | LRC1–2 | nr. variante · familiaritatea cuvântului · asemănare semantică a distractorilor | vocabular receptiv stăpânit (nr. cuvinte), confuzii semantice | etichete receptive (DTT) 🧩 |
| 15 | `ce-face` | „Cine doarme?” — acțiuni | LRC3 | nr. variante · acțiuni asemănătoare (aleargă/merge) · personaje diferite | nr. verbe stăpânite | acțiuni receptive 🧩 |
| 16 | `mingea-rosie` | Instrucțiuni cu atribute și 2–3 elemente | LRC4–5 | nr. elemente (1 → 3) · atribute (culoare, mărime) · distractori care au doar un atribut corect | acuratețe pe lungimea instrucțiunii | înțelegerea instrucțiunilor compuse 🧩 (gramatică + voce pe fragmente) |
| 17 | `unde-e-ursul` | Pune / găsește obiectul „sub”, „pe”, „lângă”, „în” | LRC6 | nr. prepoziții · obiecte · perspectivă | confuzii între prepoziții | relații spațiale 🧩 |
| 18 | `asculta-povestea` | Poveste scurtă ilustrată + întrebări (cine? ce? unde? de ce?) | LRC7 | lungimea poveștii · tip întrebare (literal → inferență) · suport vizual | acuratețe pe tip de întrebare | înțelegere (include actualul `povesti`) 🧩 |

### COM — Comunicare și limbaj expresiv (5)

| # | id | Joc | Trepte | Axe | KPI specifici | Bază |
|---|----|-----|--------|-----|---------------|------|
| 19 | `vreau` | Tablou AAC: copilul cere cu pictograme ce vrea (hrană pentru pește, jucărie în joc) | COM1–3 | nr. pictograme (2 → 20) · pagini · „vreau” + obiect → + atribut | **cereri spontane** / sesiune, varietatea cererilor | AAC, PECS (EBP) — freePlay |
| 20 | `da-nu` | Răspunde da/nu la întrebări simple | COM2–3 | tip întrebare (preferință → fapt) · ilustrație/fără | acuratețe da vs nu (bias spre „da”) | conceptul da/nu 🧩 (actualul `da-nu`) |
| 21 | `spune-propozitia` | Construiește o propoziție din pictograme care descrie imaginea | COM3–5 | lungime (2 → 4 elemente) · ordine · distractori | lungimea medie a propoziției (MLU pe pictograme) | AAC, structurarea limbajului 🧩 |
| 22 | `ce-se-aude` | Ascultă un sunet, alege sursa | COM1–3 | categorii (animale → vehicule → casă) · sunete asemănătoare · zgomot de fond | confuzii auditive | discriminare auditivă 🧩 |
| 23 | `primul-sunet` | Cu ce sunet începe cuvântul? | COM4–6 | sunete apropiate (m/n, b/p) · poziția sunetului (început → sfârșit) · nr. variante | confuzii fonologice | conștiință fonologică (pregătirea citirii) 🧩 |

### COG — Cogniție (6)

| # | id | Joc | Trepte | Axe | KPI specifici | Bază |
|---|----|-----|--------|-----|---------------|------|
| 24 | `atinge-si-vezi` | Orice atingere produce o reacție (floarea înflorește, peștele sare) | COG1 | întârzierea reacției · o singură țintă activă → mai multe | atingeri intenționate vs aleatorii, durata implicării | cauză–efect (cel mai mic nivel) ⏱ |
| 25 | `cucu-bau` | Obiectul se ascunde sub un pahar; paharele se mută; unde e? | COG2–3 | nr. pahare · nr. mutări · viteză | acuratețe vs nr. mutări | permanența obiectului, urmărire ⏱🌀 |
| 26 | `sortam` | Pune obiectele în cutii după categorie (include „intrusul”) | COG3–6 | nr. categorii · categorii apropiate (fructe/legume) · criteriu (perceptiv → funcțional) | erori pe categorie | clasificare 🧩 (actualele `grupam`, `sortare`, `intrusul`) |
| 27 | `mare-mijlociu-mic` | Ordonează după mărime / cantitate / lungime | COG4–5 | nr. obiecte · diferența între ele · dimensiunea (mărime → înălțime → cantitate) | inversiuni | seriere 🧩 |
| 28 | `continua-sirul` | Continuă modelul (AB, AAB, ABC…) | COG5–7 | tip model · nr. atribute care variază (culoare → culoare + formă) · lungime | acuratețe pe tip de model | raționament, modele 🧩 (actualul `modele`) |
| 29 | `ce-urmeaza` | Ordonează imaginile unei întâmplări | COG5–7 | nr. pași (2 → 6) · pași asemănători · cauzalitate explicită/implicită | erori de ordine (distanța față de ordinea corectă) | secvențiere 🧩 |

### EMO — Emoții și cogniție socială (5)

| # | id | Joc | Trepte | Axe | KPI specifici | Bază |
|---|----|-----|--------|-----|---------------|------|
| 30 | `emotii` | Recunoaște emoția personajului | EMO1–2 | nr. emoții (2 → 6) · **intensitate** (evidentă → subtilă) · personaje diferite · față/corp/voce | **matricea de confuzii** între emoții (ex. trist ↔ supărat) | recunoașterea emoțiilor (Emotiplay, Zirkus Empathico) 🧩 (actualul `emotii`) |
| 31 | `ce-simte` | Situație → ce simte personajul? | EMO3 | situații comune → mai puțin comune · emoții mixte | acuratețe pe tip de situație | emoții din context 🧩 |
| 32 | `ce-ma-ajuta` | Personajul e supărat; ce poate face? | EMO4 | nr. strategii · strategii plauzibile ca distractori | strategii alese (preferințe) | strategii de reglare emoțională 🧩 |
| 33 | `cine-stie` | Povestioare cu perspectivă: „unde va căuta Ana mingea?” | EMO5 | tip (ce vede celălalt → ce știe → ce crede greșit) · nr. personaje | acuratețe pe nivel de perspectivă | teoria minții (sarcini de tip „credință falsă”) 🧩 |
| 34 | `situatii` | Povești sociale ilustrate cu alegeri (a cere, a aștepta rândul, a spune nu) | EMO6 | complexitatea situației · nr. alegeri · consecințe arătate/nu | alegeri adecvate pe tip de situație | povești sociale (EBP) 🧩 (actualul `social`) |

### FEX — Funcții executive și autoreglare (8)

| # | id | Joc | Trepte | Axe | KPI specifici | Bază |
|---|----|-----|--------|-----|---------------|------|
| 35 | `semaforul` | Atinge doar când felinarul devine verde | FEX1 | timp de așteptare (1 → 6 s) · imprevizibilitate · „tentații” (licăriri) | **atingeri anticipate**, timp de așteptare tolerat | amânare / așteptare ⏱ |
| 36 | `pescarul` | Prinde peștii, nu meduzele | FEX2 | viteză (intervalul între stimuli) · **proporția no-go** (10% → 40%) · asemănarea no-go cu go · stimuli dubli | **erori de comisie** (a atins meduza), **omisiuni**, timp de reacție și variabilitatea lui | Go/No-Go (dificultate manipulabilă prin interval și prepotență) ⏱ |
| 37 | `peste-in-mijloc` | Spune încotro înoată peștele din mijloc, ignorând vecinii | FEX2–3 | nr. vecini · vecini congruenți/incongruenți · mărimea țintei | **efectul de interferență** (TR incongruent − congruent) | Flanker (nr. distractori și mărimea țintei ca axe) ⏱ |
| 38 | `regula-se-schimba` | Sortează cărți după culoare, apoi după formă, apoi alternat | FEX3–4 | nr. schimbări · schimbare anunțată/neanunțată · 2 → 3 dimensiuni | **erori perseverative** după schimbare, **costul schimbării** (TR) | Dimensional Change Card Sort (flexibilitate) 🧩⏱ |
| 39 | `simon` | Repetă secvența de lumini și sunete | FEX5 | lungimea secvenței · viteză · nr. poziții · doar lumini (fără sunet) · ordine inversă | **span** (lungimea maximă) | memorie de lucru 🌀⏱ (actualul `memorie`) |
| 40 | `felinarele` | Felinarele de pe o hartă se aprind pe rând; copilul le atinge în aceeași ordine | FEX5 | span · poziții aleatoare / grilă · ordine inversă | **span vizuo-spațial** | Corsi pe tabletă (eCorsi) 🌀 |
| 41 | `perechi` | Cărți întoarse, găsește perechile | FEX5 | nr. perechi (2 → 12) · asemănare · perechi după asociere | **întoarceri repetate inutile** (memorie), eficiența (mutări / perechi) | memorie vizuală 🌀🧩 |
| 42 | `labirint` | Du peștele la acvariu prin labirint | FEX6 (și MOT) | dimensiune · ramificații · fundături · drum vizibil / nu · obstacole mobile | **eficiența drumului** (lungime / optim), reveniri, timp de planificare înainte de prima mișcare | planificare 🌀 |
| 43 | `respira` | Respirație ghidată (balonul crește și scade) | FEX6 | durata ciclului · nr. cicluri · cu/fără ghidaj vizual | **folosire spontană** (cerută din butonul de pauză), cicluri terminate | autoreglare — freePlay (actualul `respira`) |

### AUT — Autonomie și rutine (4)

| # | id | Joc | Trepte | Axe | KPI specifici | Bază |
|---|----|-----|--------|-----|---------------|------|
| 44 | `pasii-rutinei` | Pune în ordine pașii unei rutine (spălatul pe mâini, pe dinți, masa) | AUT1–3 | nr. pași · pași asemănători · pași lipsă de găsit | rutine stăpânite, erori de ordine | analiza sarcinii (EBP) 🧩 |
| 45 | `ne-imbracam` | Îmbracă personajul după vreme și ordinea corectă | AUT2–4 | vreme (evidentă → mixtă) · nr. haine · ordinea contează / nu | erori de ordine, alegeri nepotrivite vremii | autonomie 🧩 |
| 46 | `orarul-meu` | Construiește orarul zilei din pictograme | AUT3–5 | nr. activități · momente ale zilei · schimbare neprevăzută inserată | acceptarea schimbării (timp de răspuns la schimbare) | suporturi vizuale, orar vizual (EBP) 🧩 |
| 47 | `la-magazin` | Lista de cumpărături: găsește produsele și plătește | AUT4–6 | lungimea listei · raioane · buget · distractori | produse corecte, pași în plus, planificare | planificare în viața zilnică (ShopAutiPlan) 🧩🌀 (include `bani`) |

### MOT — Motricitate fină pe ecran (2)

| # | id | Joc | Trepte | Axe | KPI specifici | Bază |
|---|----|-----|--------|-----|---------------|------|
| 48 | `traseaza` | Urmărește cu degetul drumuri, forme, cifre, litere | MOT1–4 | lățimea traseului · curbură · ghidaj (puncte → săgeți → nimic) · lungime | **abaterea medie** de la traseu, ieșiri, viteză | grafomotricitate 🌀 (include `trasare-litere`, `trasare-cifre`) |
| 49 | `hraneste-pestii` | Trage hrana la pești care se mișcă | MOT1–3 | mărimea țintei · viteza peștilor · distanță | precizia plasării, trageri ratate | control motor fin, tragere precisă ⏱ |

### PAC — Pre-academic → academic (3)

| # | id | Joc | Trepte | Axe | KPI specifici | Bază |
|---|----|-----|--------|-----|---------------|------|
| 50 | `numaram` | Numără, potrivește cifra cu cantitatea, compară | PAC-N1–N5 | interval · obiecte aranjate / împrăștiate · cifră ↔ cantitate · mai mult / mai puțin | **subitizare** (TR pentru 1–4), erori de ±1 | numerație 🧩 (actualele `numaram`, `comparam`) |
| 51 | `calculam` | Adunare, scădere, apoi înmulțire, cu și fără obiecte | PAC-N6+ | operația · interval · trecere peste ordin · suport vizual · distractori apropiați | erori tipice (ex. ±1, operația greșită), TR pe tip de problemă | aritmetică adaptivă (Math Garden: Elo, țintă ~75%) 🧩 (actualele `adunam`, `scadem`) |
| 52 | `citim` | Litere → silabe → cuvinte → propoziții → ortograme | PAC-L1+ | unitatea (literă → propoziție) · litere asemănătoare (b/d) · lungime · familiaritate | confuzii de litere, cuvinte stăpânite | pre-citire / citire 🧩 (actualele `alfabetul`, `opuse`, `ortografie`) |

---

## 3. Acoperirea pe arii

| Arie | Jocuri | Primele de făcut (S1) |
|------|--------|------------------------|
| ATN | 5 | `cauta-in-camera`, `unde-se-uita` |
| IMI | 3 | `fa-ca-licuriciul` |
| POT | 5 | **`potriveste`** (primul joc refăcut pe ADR-027), `umbre` |
| LRC | 5 | `arata-mi`, `mingea-rosie` |
| COM | 5 | `da-nu` (există), `ce-se-aude` |
| COG | 6 | `sortam`, `ce-urmeaza` |
| EMO | 5 | **`emotii`** (există), `ce-simte` |
| FEX | 8 | **`pescarul`** (go/no-go), `simon`, `regula-se-schimba` |
| AUT | 4 | `pasii-rutinei` |
| MOT | 2 | `traseaza` |
| PAC | 3 | **`numaram`**, `calculam` (există parțial) |

**Pentru decembrie (70%)** propun ~16–18 jocuri complet pe noul model: cele 12 existente, refăcute și comasate în 8 jocuri
(`potriveste`, `emotii`, `da-nu`, `numaram`, `calculam`, `citim`, `asculta-povestea`, plus `culori`/`forme` în `potriveste`),
și ~9 jocuri noi, cu prioritate pe arii fără jocuri: `pescarul`, `simon`, `regula-se-schimba`, `cauta-in-camera`,
`unde-se-uita`, `arata-mi`, `sortam`, `ce-urmeaza`, `pasii-rutinei`. Restul în semestrul 2.

---

## 4. Mecanici necesare (câte jocuri acoperă fiecare)

| Mecanică | Jocuri | Există? |
|----------|--------|---------|
| `choice` (alege răspunsul) | ~24 | ✅ |
| `dragDrop` (trage, sortează, potrivește) | ~9 | ⬜ Sprint 4 |
| `sequence` (ordonează / repetă) | ~7 | ⬜ Sprint 4 |
| `reaction` (**nouă**: stimuli în timp — go/no-go, flanker, semafor, reacție) | 5 | ⬜ Sprint 4 |
| `scene` (**nouă**: căutare / diferențe / atingere în scenă) | 3 | ⬜ S2 |
| `trace` | 1 | ⬜ |
| `puzzle`, `maze` (🌀) | 2 | ⬜ S2 |
| `memoryCards` | 1 | ⬜ |
| `freePlay` (AAC, respirație, cauză–efect) | 3 | parțial |

Mecanica `reaction` e cea care aduce jocurile „de funcții executive”, cu KPI-uri de timp de reacție la nivel de milisecunde:
evenimentele trebuie să folosească un ceas monoton (`Stopwatch`) și să înregistreze momentul afișării cadrului, nu doar al atingerii.

---

## 5. KPI specifici — definiții

| KPI | Definiție | Jocuri |
|-----|-----------|--------|
| Timp de reacție (TR) | de la apariția stimulului (cadrul afișat) până la atingere, ms, mediană | 1, 35–38, 50 |
| Variabilitatea TR | abaterea standard / coeficient de variație al TR | 1, 36, 37 |
| Erori de comisie | răspuns la un stimul „no-go” | 35, 36 |
| Omisiuni | fără răspuns la un stimul „go” în fereastra de timp | 1, 36 |
| Efectul de interferență | TR mediu incongruent − TR mediu congruent | 37 |
| Costul schimbării | TR/acuratețe în primele încercări după schimbarea regulii − în rest | 38 |
| Erori perseverative | răspunsuri după regula veche după schimbare | 38 |
| Span | cea mai lungă secvență reprodusă corect de 2 ori din 3 | 39, 40, 7 |
| Eficiența drumului | lungimea drumului copilului / drumul optim | 42 |
| Abaterea de trasare | distanța medie (dp) a degetului față de traseu | 48 |
| Matricea de confuzii | cât de des a ales X în loc de Y | 9, 14, 30, 23, 52 |
| Panta căutării | TR ca funcție de nr. distractori (ms / distractor) | 3 |
| Cereri spontane | cereri AAC inițiate de copil / sesiune | 19 |
| Subitizare | TR pentru cantități 1–4 fără numărare | 50 |

Regulă: un KPI se afișează doar peste un **număr minim de încercări** (ex. 20 pentru TR, 10 pentru acuratețe); sub prag, panoul
arată „date insuficiente”.

---

## 6. Ce refolosim din ce există

| Joc existent | Devine |
|--------------|--------|
| `culori`, `forme` | moduri ale `potriveste` (criteriu: culoare / formă) |
| `emotii` | `emotii` (EMO1–2), cu axa de intensitate |
| `da-nu` | `da-nu` (COM) |
| `numaram`, `comparam` | `numaram` |
| `adunam`, `scadem` | `calculam` |
| `alfabetul`, `opuse`, `ortografie` | `citim` (și `opuse` → mod de vocabular) |
| `povesti` | `asculta-povestea` |

Codul generatoarelor se păstrează; se schimbă doar adăugarea axelor, legarea de trepte și evenimentele.

---

## 7. Surse

Studii și paradigme pe care se sprijină catalogul (referințele exacte se verifică pe sursa originală înainte de teză):

- Steinbrenner et al. (2020), *Evidence-Based Practices for Children, Youth, and Young Adults with Autism* (NCAEP) — [raport ERIC](https://eric.ed.gov/?id=ED609029), [articol JADD](https://link.springer.com/article/10.1007/s10803-020-04844-2); critică: [Leaf et al., 2021](https://onlinelibrary.wiley.com/doi/abs/10.1002/bin.1771).
- Serious games pentru funcții executive la copii neurodivergenți (review sistematic, 2024) — [JMIR Serious Games](https://games.jmir.org/2024/1/e59053); review 2026 despre atenție și FE — [Frontiers](https://www.frontiersin.org/journals/child-and-adolescent-psychiatry/articles/10.3389/frcha.2026.1801077/full). Concluzie: efecte bune pe abilitățile antrenate, transfer limitat → de aici accentul pe generalizare și pe decizia specialistului.
- Go/No-Go și Flanker, cu dificultate manipulată prin interval, prepotență, nr. distractori și mărimea țintei — [Child Neuropsychology](https://www.tandfonline.com/doi/abs/10.1080/09297040701793647); Go/No-Go online la TSA — [PMC4938852](https://pmc.ncbi.nlm.nih.gov/articles/PMC4938852/); comparație inhibiție TSA/ADHD — [JADD 2012](https://link.springer.com/article/10.1007/s10803-012-1650-5).
- Dimensional Change Card Sort la copii cu TSA — [PMC3459256](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3459256/), [PMC4032814](https://pmc.ncbi.nlm.nih.gov/articles/PMC4032814/), [PhenX](https://www.phenxtoolkit.org/protocols/view/530102).
- Corsi pe tabletă (eCorsi) — [Frontiers in Psychology, 2014](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2014.00939/full).
- Emoții: Emotiplay — [European Child & Adolescent Psychiatry](https://link.springer.com/article/10.1007/s00787-017-0968-0); Zirkus Empathico, RCT multicentric — [Behaviour Research and Therapy](https://www.sciencedirect.com/science/article/abs/pii/S0005796722000390), [Zirkus Empathico 2.0](https://link.springer.com/article/10.1007/s11042-025-20826-x).
- Atenție comună și privire: joc cu avatar, RCT — [PMC9835110](https://pmc.ncbi.nlm.nih.gov/articles/PMC9835110/); tipuri de indicii în jocuri virtuale — [PMC11505074](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11505074/); pilot joc digital — [JDPD 2026](https://link.springer.com/article/10.1007/s10882-026-10088-2).
- Planificare în viața zilnică: ShopAutiPlan — [PMC13245710](https://pmc.ncbi.nlm.nih.gov/articles/PMC13245710/).
- Adaptare Elo, țintă ~75% reușită, acuratețe + timp de răspuns: Math Garden, Klinkenberg et al. (2011) — [Computers & Education](https://www.sciencedirect.com/science/article/abs/pii/S0360131511000418).
- Dificultate adaptivă în timp real într-un joc terapeutic (EndeavorRx / Project EVO, aprobat FDA ca dispozitiv medical pentru ADHD) — [Wikipedia](https://en.wikipedia.org/wiki/EndeavorRx). Relevant și ca exemplu de ce **nu** vrem să devenim (plan §8.2).
