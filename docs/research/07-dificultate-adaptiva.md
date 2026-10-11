# 07 · Dificultatea adaptivă: trei bucle, de la rundă la traseu

*Capitol de cercetare pentru teză (README §23). Starea din sesiunea a unsprezecea (11.10.2026). ADR-uri legate: 019, 025, 026, 027.*

## 1. Problema

Un copil cu TSA care greșește de mai multe ori la rând se poate retrage din activitate (frustrare, comportamente de evitare); unul care reușește totul fără efort se plictisește și nu învață nimic nou. Literatura ABA recomandă o rată de reușită ridicată, dar nu totală — în jur de **80%** — și învățare **fără eroare** pe material nou (Terrace, 1963; Mueller et al., 2007). Constrângerile noastre:

- totul pe tabletă, fără server (offline-first, `01-arhitectura.md`);
- 89 de jocuri cu axe de dificultate foarte diferite (număr de pahare, secunde de așteptare, lățimea drumului, numărul de pași dintr-o instrucțiune…);
- specialistul trebuie să poată **înțelege și limita** adaptarea (plafon, nivel de pornire — ADR-025);
- copilul nu vede niciodată „nivelul” și nu e pedepsit pentru greșeli.

## 2. Arhitectura: trei bucle cu orizonturi diferite

| Bucla | Orizont | Ce decide | Unde |
|---|---|---|---|
| **1. În rundă** | secunde | cât ajutor primește copilul acum (P0 → P4) | `PromptLadder`, `promptStrategyFor` |
| **2. Între ture** | o tură de joc (5–10 runde) | nivelul următor al *aceluiași joc* | `suggestedNextLevel` pe fiecare mecanică |
| **3. Între zile** | săptămâni | ce trepte se exersează azi, în ce joc, de la ce nivel | `progressFromSessions` → `SessionPlanner`, `skillLevel` |

Buclele mai rapide reacționează la zgomot (o zi proastă); buclele lente folosesc tot istoricul. Asta evită oscilațiile: un singur eșec scade cel mult nivelul jocului cu o treaptă, dar nu schimbă traseul.

### 2.1 Bucla 1 — ierarhia de ajutor

Fiecare rundă are un nivel de ajutor maxim primit: P0 (singur) · P1 (indiciu verbal) · P2 (repetare) · P3 (răspunsul pulsează) · P4 (mânuța arată). Două strategii (plan §3.3):

- **least-to-most** pe trepte cunoscute: ajutorul crește doar după greșeală sau după o pauză lungă (5 s → pulsare, 10 s → mânuța);
- **most-to-least** pe trepte noi (sub 5 reușite independente pe treaptă): răspunsul pulsează de la început, apoi întârzierea crește cu fiecare reușită (0 → 2 → 4 s, *progressive time delay*); o greșeală resetează.

### 2.2 Bucla 2 — nivelul jocului

Fiecare mecanică are o regulă simplă pe acuratețea turei, cu praguri asimetrice (urcă mai greu decât coboară):

| Mecanică | Urcă | Coboară |
|---|---|---|
| Alegere (`choice`) | ≥ 85% din prima → +1 | < 50% → −1 |
| Reacție (go/no-go) | ≥ 90% și fără impulsivitate → +2; ≥ 80% → +1 | < 60% → −1 |
| Celelalte (pahare, labirint, sortare…) | ≥ 80% → +1 | < 50% → −1 |

La reacție, impulsivitatea (comisii ≥ o treime din atingerile corecte) blochează urcarea chiar la acuratețe mare — un copil care atinge tot nu e „bun”, e impulsiv. Nivelul se păstrează pe tabletă per joc și e plafonat de specialist (`capLevel`).

### 2.3 Bucla 3 — rating pe trepte și planificarea zilei

Fiecare treaptă din traseele de dezvoltare (ex. `EMO3` „recunoaște emoția din context”) are un **rating Elo** al copilului, calculat din toate încercările pe treaptă, din toate jocurile ei:

- probabilitatea așteptată de reușită: `E = 1 / (1 + 10^((D − R) / 400))`;
- actualizarea: `R ← R + 32 · (scor − E)`, unde `scor = credit(ajutor)` dacă e corect (P0 = 1, P1 = 0,6, P2 = 0,35, P3 = 0,15, P4 = 0) și 0 dacă e greșit — o reușită cu mânuța nu crește rating-ul;
- dificultatea itemului vine din **nivelul jocului**: `D = 1000 + 40·(nivel − 1)`.

Din rating rezultă (a) **ordinea obiectivelor** în „Drumul de azi” (treptele cu rating mic primesc întâi timp) și (b) **nivelul de pornire** al unui joc deschis prima dată: cel mai greu nivel cu ≥ 80% șanse, minus unul (`skillLevel`). Astfel, un copil care a urcat la nivelul 6 în „Pescarul” (FEX2) nu începe un alt joc al aceleiași trepte de la 1.

## 3. O greșeală găsită (și ce ne învață)

Până în sesiunea 11, câmpul `Trial.difficulty` — documentat ca „dificultatea pe scara rating-ului” — era completat de fiecare joc cu mărimea de pe axa lui: 4 pahare, 2,5 secunde de așteptare, 1/lățimea drumului. Elo primea deci `D ≈ 4` față de `R ≈ 1000`:

| | `D` corect (nivelul 3 → 1080) | `D` greșit (4 pahare) |
|---|---|---|
| `E` la `R = 1000` | 0,39 | 0,997 |
| Reușită P0 | +19,5 | +0,1 |
| Greșeală | −12,5 | −31,9 |

Cu valorile greșite, rating-ul **nu putea decât să scadă**: orice reușită era „de la sine înțeleasă”, orice greșeală — o surpriză. Ordinea obiectivelor devenea, de fapt, „unde a greșit cel mai mult”, iar nivelul de pornire din rating ar fi fost mereu 1. Testele treceau, pentru că verificau doar direcția (crește după multe reușite la jocurile cu alegere, unde câmpul era gol și se folosea valoarea implicită 1000).

**Corecția:** încercarea păstrează acum separat `level` (nivelul jocului, pentru rating) și `difficulty` (mărimea pe axa jocului, pentru KPI de tipul „acuratețea față de numărul de pahare”). Sesiunile vechi, fără nivel, folosesc `D = 1000`. Serverul acceptă câmpul nou ca opțional, iar testul de contract Dart ↔ TypeScript îl acoperă. Teste noi fixează proprietățile care lipseau: aceeași reușită valorează mai mult la un nivel mare; o greșeală la un nivel mult prea greu costă puțin.

**Lecția pentru teză:** un model adaptiv are nevoie de teste pe *proprietăți* (monotonie, sensibilitate la dificultate), nu doar pe direcția rezultatului. Iar unitățile de măsură trebuie să aibă nume diferite (`level` ≠ `difficulty`) — un câmp numeric fără scară explicită e o capcană.

## 4. Adaptarea între zile — regulile planificatorului

`SessionPlanner` construiește orarul zilei (încălzire → 1–2 blocuri de obiective → menținere → final pe succes). Reguli adăugate în sesiunea 11, fiecare cu motivul ei clinic:

| Regulă | Motiv |
|---|---|
| **Pas înapoi:** dacă ultimele două sesiuni pe o treaptă au avut sub 30% independență (cu cel puțin 4 încercări fiecare), blocul zilei folosește **treapta dinainte** din traseu, pe jocul cunoscut; treapta grea rămâne obiectiv. | Momentum comportamental (Nevin, 1996): o serie de reușite înainte de sarcina grea crește complianța. Evită spirala „greșesc → mă retrag”. |
| **Rotirea jocurilor pe treaptă:** încălzirea și finalul folosesc jocul cel mai jucat; un obiectiv care merge (rating ≥ 1000) și verificarea de menținere folosesc jocul jucat cel mai demult. | Predictibilitate acolo unde contează succesul; **generalizare** (același obiectiv pe alt material) acolo unde copilul e pregătit — stăpânirea pe un singur joc nu e încă o abilitate (Stokes & Baer, 1977). |
| Obiectiv în achiziție (rating < 1000) rămâne pe jocul cunoscut. | Consecvența materialului în faza de achiziție. |
| Zi grea (obosit/trist/supărat) sau oboseală mare data trecută → un singur bloc, mai scurt, 50% material cunoscut. | Autoreglare (plan §3.4). |
| Blocurile din arii diferite; ce s-a exersat azi trece la coadă; la egalitate decide ziua (seed pe dată). | Practica distribuită; aceeași zi → același drum (predictibil). |

## 5. Alternative

| Model | Pentru | Împotrivă | Când l-am alege |
|---|---|---|---|
| **Praguri fixe pe acuratețe** (prototipul: fereastră de 20, < 60% mai ușor, > 90% mai greu) | Explicabil oricui | Nu compară jocuri și niveluri diferite; nu are memorie între jocuri | Păstrat ca buclă 2 (pe joc). |
| **Elo** (ales pentru bucla 3) | Un singur număr pe treaptă, comparabil între jocuri; actualizare O(1); explicabil („probabilitatea de reușită”) | Presupune itemi calibrați (aici: nivelul ≈ dificultate liniară); un singur parametru per copil-treaptă | — |
| **BKT** (Bayesian Knowledge Tracing, Corbett & Anderson, 1995) | Modelează explicit „știe / nu știe”, cu probabilități de ghicire și de alunecare | 4 parametri per abilitate de estimat din date pe care nu le avem (populație mică); binar — nu modelează nivelul de dificultate | Cu sute de copii și date pentru calibrare. |
| **IRT** (Item Response Theory) | Calibrare riguroasă a itemilor | Cere eșantioane mari pentru calibrare | Pentru o evaluare standardizată, nu pentru joacă zilnică. |
| **Învățare prin întărire / bandiți** | Optimizează direct implicarea | Opac; poate optimiza „ce îi place” în loc de „ce învață”; greu de justificat clinic | Niciodată pentru alegerea obiectivelor; poate pentru ordinea cosmetică. |

Elo e folosit în același mod în educație (de ex. Pelánek, 2016, pentru sisteme adaptive de exersare), tocmai pentru că nu cere calibrare prealabilă.

## 6. Limitări cunoscute

1. **Liniaritatea nivelurilor** (+40 de puncte pe nivel) e o aproximare; la unele jocuri saltul între niveluri nu e egal. Calibrarea pe date reale (după testarea cu copii) poate da câte o pantă pe joc.
2. ✅ *Rezolvat (sesiunea 11):* **scara comună a nivelurilor** (`level_scale.dart`). Fiecare joc își declară plafonul, adică nivelul de la care axele lui nu mai cresc („Construiește” — 7, „Felinarele” — 25, jocurile cu alegere — 7). Pe scara rating-ului, nivelul 1 al oricărui joc valorează 1000, iar plafonul 1400; între ele, liniar. Un test verifică plafonul declarat pe axele reale ale fiecărui joc (că nivelul de plafon e identic cu toate cele de peste el și diferit de cel de dedesubt) și a găsit două plafoane citite greșit din cod (labirintul și hrănirea peștilor). Rămâne o aproximare: liniaritatea între nivelul 1 și plafon (limitarea 1).
3. **Pragurile clinice** (80% pentru stăpânire, 30% pentru pas înapoi, 4 încercări minime) sunt din literatură, nu validate pe copiii noștri — sunt parametri, nu constante, și urmează validarea planului cu specialiștii (README §0.0 D).

## 7. Cum am verificat

| Proprietate | Test |
|---|---|
| Reușita la nivel mare crește rating-ul mai mult | `progress_test.dart` — „aceleași reușite valorează mai mult la un nivel mare” |
| Greșeala la un nivel prea greu costă puțin | `progress_test.dart` |
| Sesiunile vechi (fără nivel) se citesc | `progress_test.dart` — JSON fără `level` |
| Nivel de pornire prudent | `skillLevel` < nivelul cu 80% șanse; null fără date |
| Pas înapoi după două sesiuni grele, nu după una; sesiunile scurte nu contează | `progress_test.dart`, grupul „Drumul de azi adaptiv” |
| Rotirea jocurilor pe o treaptă, pe mai multe seed-uri | `progress_test.dart` |
| Plafonul declarat al fiecărui joc corespunde axelor lui | `level_scale_test.dart` (36 de jocuri) |
| Verificarea generalizării: o treaptă stăpânită pe un singur joc e verificată pe altul | `progress_test.dart`, grupul „generalizarea” |
| Paritatea cu prototipul (bucla 2 la jocurile cu alegere) | `difficulty_test.dart` — teste de paritate cu `difficulty.js` |
| Serverul acceptă noul câmp | `sync.spec.ts` — fixtura regenerată din Dart conține `level` |

## 8. Rezumat pentru susținere (60 s)

*Problema:* copilul trebuie să reușească ~80% din timp, pe 89 de jocuri foarte diferite, offline. *Ales:* trei bucle — ajutorul în rundă (P0–P4, most-to-least pe material nou), nivelul jocului după fiecare tură (praguri simple, explicabile), și un rating Elo pe fiecare treaptă de dezvoltare care alege obiectivele zilei, nivelul de pornire al jocurilor noi, pasul înapoi și jocul pe care se exersează generalizarea. *Alternative:* BKT și IRT cer date de calibrare pe care nu le avem; învățarea prin întărire e opacă clinic. *Verificat* prin teste pe proprietăți — care au și găsit o eroare reală de scară în modelul inițial.

## Surse

- Terrace, H. S. (1963). Discrimination learning with and without "errors". *Journal of the Experimental Analysis of Behavior*, 6(1).
- Mueller, M. M., Palkovic, C. M., & Maynard, C. S. (2007). Errorless learning: Review and practical application for teaching children with pervasive developmental disorders. *Psychology in the Schools*, 44(7).
- Nevin, J. A. (1996). The momentum of compliance. *Journal of Applied Behavior Analysis*, 29(4).
- Stokes, T. F., & Baer, D. M. (1977). An implicit technology of generalization. *Journal of Applied Behavior Analysis*, 10(2).
- Corbett, A. T., & Anderson, J. R. (1995). Knowledge tracing: Modeling the acquisition of procedural knowledge. *User Modeling and User-Adapted Interaction*, 4(4).
- Pelánek, R. (2016). Applications of the Elo rating system in adaptive educational systems. *Computers & Education*, 98.
