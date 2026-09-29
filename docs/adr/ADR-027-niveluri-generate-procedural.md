# ADR-027: Niveluri generate procedural, cu rating adaptiv și fără repetări

Status: Propus · Data: 2026-09-29 · Detalii: [plan-dezvoltare-terapeutica.md §3.5](../plan-dezvoltare-terapeutica.md)

## Context
Scopul e dezvoltarea continuă a copilului, nu parcurgerea unui set fix de niveluri. Un joc cu 5–10 niveluri scrise de mână se epuizează, iar copilul memorează răspunsurile (poziția, imaginea) în loc să învețe abilitatea — risc mare la TSA. Specialistul are nevoie și ca progresul să fie fin (micro-niveluri între trepte) și ca orice nivel greșit să poată fi revăzut exact.

## Decizie
- Fiecare joc declară **axe de dificultate** (ex. nr. variante, asemănarea distractorilor, lungimea instrucțiunii, viteza). Treapta fixează axele calitative; generatorul mișcă continuu axele cantitative.
- Nivelul copilului pe fiecare treaptă e un **rating Elo**, actualizat după fiecare încercare (reușitele cu ajutor contează puțin). Generatorul țintește ~80% șanse de reușită (configurabil).
- Conținutul e o **bază de stimuli cu atribute** (JSON). Întrebările, distractorii și instrucțiunile se compun după reguli; ilustrațiile se compun din straturi.
- **Istoric de expunere** per copil (fără repetarea combinațiilor) + **repetare spațiată** (Leitner) a itemilor greșiți, în altă formă.
- Nivelurile sunt **deterministe**: `(generator, versiune, treaptă, axe, seed)`; seed-ul se salvează în fiecare încercare.
- Fiecare generator e testat pe 10 000 de seed-uri (un singur răspuns corect, fără ambiguitate, resurse existente, dificultate monotonă).
- AI doar la crearea materialului (verificat de om), niciodată la rulare.

## De ce
- Spațiu practic infinit de niveluri din conținut finit: 200 de stimuli × niveluri de asemănare × așezări × teme = zeci de mii de runde.
- Elo e simplu (câteva linii), rapid, merge offline, pornește fără date istorice și e dovedit pe copii (Math Garden, Klinkenberg et al., 2011).
- Determinismul face datele verificabile de specialist și testele reproductibile.
- `GameContext` are deja `Random` injectat și `speak` pe fragmente, deci baza există.

## Alternative
1. Niveluri scrise de mână (sau generate o dată și salvate) — liste fixe.
2. Doar `tier` numeric (situația actuală).
3. Modele statistice complexe de la început: IRT, Bayesian Knowledge Tracing.
4. Generare cu AI la rulare.

## De ce nu
1. Se epuizează, se memorează, cost de producție proporțional cu nr. de niveluri.
2. O singură axă nu poate descrie dificultatea reală (asemănarea distractorilor contează mai mult decât numărul lor).
3. Cer multe date pentru calibrare, pe care nu le avem înainte de pilot; rămân subiect pentru semestrul 2.
4. Cost per utilizare, internet obligatoriu, imprevizibil, nesigur pentru copii (README §2.1).

## Când am alege altfel
Cu date de la sute de copii: calibrarea dificultății itemilor prin IRT sau Elo pe itemi. Cu o echipă de conținut: niveluri narative lucrate manual, peste generatorul de bază.

## Consecințe
- `Difficulty(tier)` rămâne pentru compatibilitate; jocurile noi folosesc `DifficultyAxes`.
- Conținutul trebuie adnotat cu atribute (categorie, culoare, formă, gen gramatical, familiaritate) — muncă de date, parțial asistată de AI.
- Ilustrațiile trebuie gândite pe straturi (personaj, expresie, accesoriu, fundal) — se adaugă în ghidul de ilustrații.
- Vocea trebuie să acopere fragmentele combinabile, inclusiv formele acordate (roșu/roșie).
