# 06 · Designul pentru copii cu TSA: de la dovezi la ecran

*Capitol de cercetare pentru teză (README §23). Starea din sesiunea a unsprezecea (11.10.2026). Documente legate: [DESIGN.md](../../DESIGN.md), [planul terapeutic](../plan-dezvoltare-terapeutica.md), ADR-023, ADR-026, ADR-028.*

## 1. Problema

Un copil cu tulburare din spectrul autist (TSA) poate avea, în proporții foarte diferite de la copil la copil: sensibilitate senzorială (sunete, lumini, mișcare), nevoie mare de predictibilitate, dificultăți de comunicare și de recunoaștere a emoțiilor, toleranță scăzută la frustrare. O aplicație „educativă” obișnuită — sunete puternice, animații care pornesc singure, „Greșit!” cu X roșu, clasamente, reclame — poate fi pentru el nu doar ineficientă, ci aversivă.

Întrebarea capitolului: **ce spune cercetarea, și cum am transformat fiecare principiu într-o regulă de cod, verificabilă?**

## 2. Cadrele de intervenție și ce am luat din fiecare

| Cadru | Ideea centrală | Unde apare în Licurici |
|---|---|---|
| **ABA** (Applied Behavior Analysis) | Abilități sparte în pași mici; încercări discrete; întărire imediată; date despre fiecare încercare | Traseele pe trepte (`development.dart`), fiecare rundă = un `Trial` cu ajutorul primit (P0–P4), latență, ce a ales; graficele ABA ale independenței în panou, cu linia de 80% |
| **Învățare fără eroare** (Terrace; Mueller et al., 2007) | Pe material nou, ajutor de la început, retras treptat | *Most-to-least* cu întârziere progresivă (0 → 2 → 4 s) pe trepte noi; runda se termină mereu pe răspunsul corect |
| **TEACCH** | Structură vizuală: început clar, ce am de făcut, când am terminat | „Drumul de azi” (orar vizual: încălzire → obiective → final pe succes); aceeași structură în toate jocurile (Template Method — `04-patternuri.md`); finalul comun cu stele |
| **PECS / AAC** | Comunicare prin imagini | Jocul „Vorbește” (tabla AAC: „Vreau apă”, „Mă simt obosit”); cererile copilului apar în raportul pentru părinte |
| **Social Stories** | Scenarii scurte, literale, la persoana întâi | „Situații”, „Ce simte?”, „Cine știe?” (teoria minții) |
| **Zones of Regulation** | Verificarea stării + o unealtă de calmare | „Cum te simți?” la început și la final; „Respiră” (floarea care se deschide 4-2-4 s); „Drumul de azi” mai blând într-o zi grea |
| **PRT** (Pivotal Response Training) | Interesele copilului ca motivație; răsplătim încercarea | Acvariul cu peștele colorat de copil; stele pentru efort, nu doar pentru corectitudine |
| **Momentum comportamental** (Nevin, 1996) | Câteva reușite ușoare înainte de sarcina grea | Încălzirea pe o treaptă stăpânită; pasul înapoi după două sesiuni grele (`07-dificultate-adaptiva.md`) |

## 3. Principiu → regulă în cod → cum se verifică

### 3.1 Predictibilitate

| Principiu | Implementare | Verificare |
|---|---|---|
| Aspect identic pe orice dispozitiv | Flutter desenează fiecare pixel (ADR-001); **doar landscape** (ADR-023), deci așezarea nu se schimbă când copilul rotește tableta | Teste de interfață la 5 dimensiuni de ecran (`layout_test.dart`) |
| Navigație fixă | Bara de sus cu butoane rotunde, **fiecare culoare are un singur sens** (kitul „candy”) | Același widget pe toate ecranele copilului |
| Aceeași zi → același drum | Ordinea zilei e aleatoare, dar cu seed pe dată (ariile se rotesc de la o zi la alta, nu de la o deschidere la alta) | `todayPlanProvider`: `Random(an·10000 + lună·100 + zi)` |
| Aceeași voce | 2 503 clipuri pre-generate, aceeași voce neurală, acoperire 100% (orice text rostit are clip — `tool/voice_coverage.dart`) | Raportul de acoperire |
| Jocul nu se schimbă sub degete | Nivelul se schimbă doar **între** ture, niciodată în timpul uneia | Regula din fiecare `suggestedNextLevel` |

### 3.2 Fără pedeapsă

| Principiu | Implementare |
|---|---|
| Fără X roșu, buzzer, „Greșit!” | Nu există sunet de greșeală (`tools/audio/gen_sfx.py` nu generează unul); cardul greșit doar se clatină ușor; răspunsul corect primește o bifă verde |
| Greșeala nu scade nimic | Fără scor care scade, fără vieți, fără cronometru vizibil (excepție deliberată: „Semaforul” — antrenează tocmai așteptarea, și o face cu un felinar, nu cu un ceas) |
| Fără clasamente | Nicio comparație între copii; harta arată doar felinarele copilului |
| Copilul nu vede „nivelul” | Harta are **felinare aprinse** (treaptă stăpânită), **care pâlpâie** (începută) și stinse — lumină, nu numere |
| Ieșire blândă dintr-o situație fără soluție | Dacă imaginile de evitat lasă un joc fără conținut: ecran liniștit „Hai la alt joc!”, nu o eroare |

### 3.3 Sensibilitate senzorială

| Principiu | Implementare |
|---|---|
| Nimic nu pornește singur | Sunetele doar la atingere; bucla de apă din acvariu niciodată în modul calm |
| Mișcare comutabilă | `MotionPolicy` (full / gentle / off) aplicată celor 7 straturi de animație; respectă setarea de sistem *reduce motion* |
| „Modul calm” | Fundaluri statice, sunete mai încete, doar notele jocului, fără efecte |
| Paletă moale | Fundaluri cu saturație joasă; fără roșu aprins pe suprafețe mari; text `#2f3d3b`, nu negru pur |
| Imagini care sperie | **Imagini de evitat** alese de adult (câini, insecte, fețe furioase, foc, baloane, doctor…): jocurile cu alegere sar peste runde, celelalte regenerează nivelul fără ele (`avoid.dart`, sesiunea 10) |
| Contrast pentru deficiențe de vedere | „Contrast mare” (sesiunea 9) |

### 3.4 Accesibilitate motorie

| Principiu | Implementare | Verificare |
|---|---|---|
| Ținte mari | ≥ 48 dp pe tot ce se apasă (ghidul Android); cardurile de răspuns mult mai mari | `a11y_test.dart`, `a11y_games_test.dart` — 33 de ecrane |
| Alternativă la tragere | La „Sortăm”: tragi lucrul în cutie **sau** îl atingi, apoi atingi cutia | Test de widget |
| Urmărirea traseului cu toleranță | La „Trasează”, personajul înaintează doar cât degetul e pe drum; drumul se îngustează treptat | `trace_test.dart` |
| Cititor de ecran | Etichete semantice pe toate zonele de joc (au lipsit 11 — găsite de teste, reparate) | `a11y_games_test.dart` |

### 3.5 Autoreglare

- **„Cum te simți?”** (5 fețe pictate ale aceluiași copil) la primul joc și la „Gata pe azi”; dispoziția intră în raport (înainte/după).
- **„Drumul de azi” mai scurt** dacă copilul e obosit, trist sau supărat, sau dacă data trecută a obosit mult (timpii au crescut cu ≥ 40%) sau a abandonat: un singur bloc de obiective, mai scurt, cu 50% material cunoscut.
- **Pauza** ilustrată și **„Respiră”** oricând; folosirea lor se notează în sesiune (pentru specialist: „a cerut pauză după 12 minute” e o informație utilă).

### 3.6 Copilul și adultul — două lumi separate

- **Poarta pentru adulți** (o înmulțire cu numerele scrise în cuvinte, cu 4 variante — un copil mic n-o rezolvă din întâmplare, un adult trece în câteva secunde) înainte de setări, trimitere pe server, printarea fișei, ștergerea datelor.
- **Fără chat AI pentru copil** (siguranță, previzibilitate); AI-ul e doar în panoul adulților, pe date agregate.
- **Fără reclame, fără cumpărături, fără linkuri externe** în zona copilului.

## 4. Comparație cu aplicațiile existente

| | AutiSpark | Otsimo | Licurici |
|---|---|---|---|
| Limba română | parțial / nu | nu | **da**, voce neurală, 100% din text |
| Offline complet, fără cont | parțial | nu (cont) | **da**, implicit |
| Conținut nerepetitiv | bancă fixă | bancă fixă | **niveluri generate procedural**, seed reproductibil |
| Date măsurabile pentru specialist (ajutor P0–P4, independență, generalizare, menținere) | limitat | rapoarte de progres | **da**, pe trepte de dezvoltare, grafice ABA |
| Specialistul ajustează jocurile | nu | parțial | **da**: jocurile copilului, nivelul de pornire, plafonul, rundele, imaginile de evitat |
| Model de abonament | da | da | fără (proiect de licență) |

*Notă:* comparația reflectă funcțiile publice ale aplicațiilor la momentul scrierii și e orientativă; nu a fost făcută o evaluare sistematică a lor.

## 5. Ce nu știm încă

1. **Eficacitatea.** Toate deciziile de mai sus sunt fundamentate pe literatură, nu pe măsurători cu copiii noștri. Testarea cu copii (cu acord parental, README §13.6) e în semestrul 2.
2. **Pragurile.** 80% independență pentru stăpânire, 30% pentru pasul înapoi, 5 reușite pentru „treaptă cunoscută” — din literatură, nevalidate de specialiști pe acest produs (README §0.0 D).
3. **Variabilitatea senzorială.** Un singur „mod calm” e o simplificare; unii copii pot avea nevoie de combinații (sunet da, mișcare nu). Setările sunt separate tocmai ca să permită asta, dar nu am testat combinațiile cu utilizatori.

## 6. Rezumat pentru susținere (60 s)

*Problema:* aplicațiile educative obișnuite pot fi aversive pentru un copil cu TSA. *Ce am folosit din cercetare:* ABA (pași mici, încercări măsurate, ajutor gradat), învățare fără eroare, TEACCH (orar vizual, aceeași structură), PECS (tabla AAC), Zones of Regulation („Cum te simți?”, „Respiră”). *Cum devine cod:* fără sunet de greșeală, fără scor care scade, fără nivel vizibil (felinare în loc de numere), mișcare și sunet comutabile, imagini de evitat alese de adult, ținte ≥ 48 dp verificate automat pe 33 de ecrane. *Ce lipsește:* validarea cu specialiști și testarea cu copii, în semestrul 2.

## Surse

- Terrace, H. S. (1963). Discrimination learning with and without "errors". *JEAB*, 6(1).
- Mueller, M. M., Palkovic, C. M., & Maynard, C. S. (2007). Errorless learning: review and practical application for teaching children with pervasive developmental disorders. *Psychology in the Schools*, 44(7).
- Nevin, J. A. (1996). The momentum of compliance. *JABA*, 29(4).
- Mesibov, G. B., Shea, V., & Schopler, E. (2004). *The TEACCH Approach to Autism Spectrum Disorders.* Springer.
- Bondy, A. S., & Frost, L. A. (1994). The Picture Exchange Communication System. *Focus on Autistic Behavior*, 9(3).
- Kuypers, L. (2011). *The Zones of Regulation.* Think Social Publishing.
- Koegel, R. L., & Koegel, L. K. (2006). *Pivotal Response Treatments for Autism.* Brookes.
- W3C (2023). WCAG 2.2 — Success Criterion 2.5.8 Target Size (Minimum).
- Restul surselor de design: [DESIGN.md](../../DESIGN.md) §Surse.
