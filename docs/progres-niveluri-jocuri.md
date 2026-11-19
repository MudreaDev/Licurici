# Progresul nivelurilor pe secțiuni

Sursa listei: `catalog` din `licurici_core`; `dart run tool/catalog_levels_inventory.dart` generează inventarul.
O bifă înseamnă că jocul a fost abordat în această trecere, are o creștere reală a dificultății și a fost testat; o excepție pentru un instrument de comunicare este indicată explicit. Nu înseamnă dificultate infinită sau validare terapeutică pe dispozitiv. O bifă nu se pune doar pentru că numărul nivelului crește.

Ordine: **Atenție**, **Fac și eu**, **Potrivim**, **Ascult și înțeleg** și **Vorbim** (prima trecere), apoi Gândim, Emoții și prieteni, Memorie și răbdare, Singur, Mâini dibace, Numere și litere. Trecerea la secțiunea următoare se face după verificarea tuturor jocurilor din secțiunea curentă. Unele jocuri au primit extinderi înainte de această evidență; ele sunt revizuite în secțiunea lor.

## Atenție (ATN) — 6 jocuri

**A doua trecere, începută la cererea utilizatorului pe 19.11:**

- [x] Prinde licuriciul — până la 22 de apariții la nivelul 23; nivelul parcurs pe telefon mic simulat.
- [x] Paznicul farului — durata apariției scade până la 1 secundă la nivelul 20; nivelul parcurs pe telefon mic simulat.
- [x] Ce s-a schimbat? — 9 obiecte la nivelul 17 și 10 la 19, fără scurtarea suplimentară a observării; nivelul parcurs pe telefon mic simulat.
- [x] Unde se uită? — 8 runde de la nivelul 10, cu reutilizarea imaginilor permise dacă este nevoie; testat pe telefon mic simulat.
- [x] Caută — 6 runde la nivelul 17 și 7 la 19; testat pe telefon mic simulat.
- [x] Urmărește peștele — 7 runde la nivelul 18 și 8 la 20; testat pe telefon mic simulat.

Prima trecere:

- [x] Prinde licuriciul (`prinde-licuriciul`, reaction) — deplasare mai mare până la nivelul 18; ținta păstrează minimum 64 dp.
- [x] Paznicul farului (`paznicul-farului`, reaction) — distractori mai frecvenți până la nivelul 15.
- [x] Ce s-a schimbat? (`ce-s-a-schimbat`, change) — timp de observare redus treptat până la nivelul 15.
- [x] Unde se uită? (`unde-se-uita`, gaze) — perechi de obiecte asemănătoare alese explicit de la nivelul 8, cu rezervă pentru imaginile excluse.
- [x] Caută (`cauta`, search) — distractori din aceeași grupă de la nivelul 15, cu rezervă pentru imaginile excluse.
- [x] Urmărește peștele (`urmareste-pestele`, track) — 6 pești identici de la nivelul 16.

Verificări: teste de generare și calibrare pentru toate cele șase jocuri; jocuri parcurse la nivelurile noi pe telefon mic simulat, inclusiv ținte de minimum 64 dp la jocurile de reacție. Testul pe tabletă reală și validarea terapeutică rămân necesare. Fiecare joc păstrează un plafon real al mecanicii.

## Fac și eu (IMI) — 4 jocuri

**A doua trecere, 19.11:**

- [x] Oglinda — 6 atingeri la nivelul 12, 7 la 14; coordonatele atingerii folosesc dimensiunea reală a feței, iar panoul și rama au fost rearanjate. Testat cu portrete pictate pe telefon și tabletă simulate; verificarea pe tabletă fizică rămâne necesară.
- [x] Construiește la fel — 3 distractori la nivelul 12, 4 la 14, model cu 4 tipuri de piese și paletă derulabilă pe telefon; testat pe telefon simulat.
- [x] Toba magică — 5 runde la nivelul 15 și 6 la 17; testat pe telefon simulat.
- [x] Fă ca Licurici — 5 acțiuni la nivelul 13; testat pe telefon simulat.

Prima trecere:

- [x] Oglinda (`oglinda`, mirror) — până la cinci atingeri la nivelul 10.
- [x] Construiește la fel (`construieste`, build) — modelul se vede 4 secunde de la 8 și 3 secunde de la 10, cu posibilitatea de a-l revedea.
- [x] Toba magică (`toba-magica`, rhythm) — până la opt bătăi la nivelul 13.
- [x] Fă ca Licurici (`fa-ca-licuriciul`, imitation) — patru acțiuni la nivelul 11.

Verificări: generatoarele și cele patru jocuri au fost parcurse la nivelurile noi pe telefon mic simulat. Testul pe dispozitiv real și validarea terapeutică rămân necesare.

## Potrivim (POT) — 8 jocuri

**A doua trecere, 19.11:**

- [x] Potrivește — de la nivelul 10 apare un distractor apropiat vizual, între șase variante; testat pe telefon și tabletă simulate.
- [x] Forma ascunsă — 13 linii de distragere la nivelul 14; testat pe telefon și tabletă simulate.
- [x] Intrusul — 10 runde de la nivelul 10; testat pe telefon și tabletă simulate.
- [x] Umbre — de la nivelul 10 apare un distractor apropiat vizual; testat pe telefon și tabletă simulate.
- [x] Culori — 10 runde de la nivelul 10; testat pe telefon și tabletă simulate.
- [x] Forme — 10 runde de la nivelul 10; testat pe telefon și tabletă simulate.
- [x] Găsește diferențele — până la 10 diferențe la nivelul 19; nivel parcurs pe telefon mic simulat.
- [x] Puzzle — 24 de piese la nivelul 14 cu model și 15 fără model; nivelul 15 parcurs pe telefon mic, cu piese și locuri de minimum 64 dp.

Prima trecere:

- [x] Potrivește (`potriveste`, choice) — șase obiecte din aceeași grupă de la nivelul 8.
- [x] Forma ascunsă (`forma-ascunsa`, choice) — 11 linii de distragere de la nivelul 12.
- [x] Intrusul (`intrusul`, choice) — cinci obiecte din grupă și unul diferit de la nivelul 8.
- [x] Umbre (`umbre`, choice) — șase variante din aceeași grupă de la nivelul 8.
- [x] Culori (`culori`, choice) — șase variante de la nivelul 8.
- [x] Forme (`forme`, choice) — șase variante de la nivelul 8.
- [x] Găsește diferențele (`diferente`, diff) — până la opt diferențe la nivelul 15.
- [x] Puzzle (`puzzle`, puzzle) — 20 de piese de la nivelul 12; nivelul 13 fără model. Pe telefon, tava și rama pot fi derulate, iar piesele și locurile au minimum 64 dp.

Verificări: generatoarele și ecranele celor opt jocuri au trecut teste pe telefon și tabletă simulate; nivelurile noi au fost verificate pe telefon, iar pentru jocurile cu alegere și pe tabletă. Puzzle-ul cu 20 de piese a fost parcurs complet pe telefon simulat. Testarea pe dispozitiv real și validarea terapeutică rămân necesare.

## Ascult și înțeleg (LRC) — 11 jocuri

**A doua trecere, 19.11:**

- [x] Arată-mi — distractor apropiat vizual de la nivelul 10; testat pe telefon/tabletă simulate.
- [x] Corpul meu — părți ale corpului apropiate ca distractori de la nivelul 10; testat pe telefon/tabletă simulate.
- [x] Ce face? — acțiuni apropiate ca distractori de la nivelul 10; testat pe telefon/tabletă simulate.
- [x] Mare, mic, roșu — 10 runde de la nivelul 10; ecranul testat pe telefon/tabletă simulate.
- [x] Unde e ursulețul? — 10 runde de la nivelul 10; ecranul testat pe telefon/tabletă simulate.
- [x] Sus, jos, stânga, dreapta — 10 runde de la nivelul 11; ecranul testat pe telefon/tabletă simulate.
- [x] Povești — 3 întrebări de la nivelul 12, cu toate fragmentele rostite în ordine; generator testat, ecran deschis pe telefon/tabletă simulate.
- [x] Adu-mi — 4 obiecte cerute la nivelul 10; nivel parcurs pe telefon mic simulat.
- [x] Pune ursulețul — 4 obiecte în poziții distincte la nivelul 9; nivel parcurs pe telefon mic simulat.
- [x] Colorează ce auzi — 4 obiecte și colorări la nivelul 11; nivel parcurs pe telefon mic, ținte ≥64 dp.
- [x] Ascultă și fă — până la 5 pași la nivelul 15; nivel parcurs pe telefon mic simulat.

Prima trecere:

- [x] Arată-mi (`arata-mi`, choice) — șase obiecte asemănătoare de la nivelul 8.
- [x] Corpul meu (`corpul`, choice) — șase variante de la nivelul 8.
- [x] Ce face? (`ce-face`, choice) — șase acțiuni de la nivelul 8.
- [x] Mare, mic, roșu (`mingea-rosie`, choice) — distractori suplimentari de mărime și culoare de la nivelul 8.
- [x] Unde e ursulețul? (`unde-e-ursul`, choice) — variante cu ambele repere, masă și cutie, de la nivelul 8.
- [x] Sus, jos, stânga, dreapta (`pozitii`, choice) — nouă compartimente și șase variante de la nivelul 9.
- [x] Povești (`povesti`, choice) — mai multe fragmente ascultate înaintea întrebărilor la nivelurile 8 și 10; povestea completă rămâne în ordine.
- [x] Adu-mi (`adu-mi`, fetch) — trei obiecte cerute de la nivelul 8.
- [x] Pune ursulețul (`pune-ursul`, place) — trei așezări de la nivelul 7.
- [x] Colorează ce auzi (`coloreaza-ce-auzi`, paintByEar) — trei colorări de la nivelul 9.
- [x] Ascultă și fă (`asculta-si-fa`, listen) — patru instrucțiuni în ordine de la nivelul 13.

Verificări: generatoarele au fost testate pe mai multe seed-uri; jocurile de acțiune au fost parcurse la nivelurile noi pe telefon simulat, iar jocurile cu alegere au fost deschise la nivelurile noi pe telefon și, pentru majoritatea, pe tabletă simulate. Poveștile au fost verificate pentru ordinea și integritatea fragmentelor și deschise pe telefon. Acoperire vocală: 2883/2883 fraze verificate, inclusiv valorile rare ale banilor. Validarea pe dispozitiv real și cu specialistul rămâne necesară.

## Vorbim (COM) — 7 jocuri

**A doua trecere, 19.11:**

- [x] Ce ai auzit? — 10 runde de la nivelul 12; ecran testat pe telefon/tabletă simulate.
- [x] Primul sunet — distractor cu sunet inițial apropiat la fiecare rundă de la nivelul 10; testat pe telefon/tabletă simulate.
- [x] Da sau nu? — 10 runde echilibrate de la nivelul 10; testat pe telefon/tabletă simulate.
- [x] Ce se aude? — surse cu sunete apropiate în variante de la nivelul 10; testat pe telefon/tabletă simulate.
- [x] Memorie cu sunete — 9 perechi de la nivelul 13, tavă derulabilă și ținte ≥64 dp pe telefon mic simulat; la excluderi se completează doar cu alte surse permise.
- [x] Vorbește — excepție revizuită: comunicarea AAC rămâne liberă, fără limitarea pictogramelor sau nivel obligatoriu.
- [x] Spune propoziția — 5 distractori de la nivelul 13; tavă derulabilă și nivel parcurs pe telefon mic simulat.

Prima trecere:

- [x] Ce ai auzit? (`ce-ai-auzit`, choice) — 5 variante la nivelul 8 și 6 la 10, inclusiv cuvinte asemănătoare.
- [x] Primul sunet (`primul-sunet`, choice) — 6 variante cu sunete inițiale diferite de la nivelul 8.
- [x] Da sau nu? (`da-nu`, choice) — la nivelul 8, imaginea nepotrivită poate avea aceeași inițială.
- [x] Ce se aude? (`ce-se-aude`, choice) — 6 variante de la nivelul 8.
- [x] Memorie cu sunete (`memorie-sunete`, soundMemory) — 7 perechi la nivelul 9 și 8 la 11; cartonașe de minimum 64 dp pe telefonul mic testat.
- [x] Vorbește (`vorbeste`, aac) — excepție revizuită: este o tablă de comunicare, nu un joc cu răspunsuri corecte; toate pictogramele rămân disponibile, fără nivel obligatoriu.
- [x] Spune propoziția (`spune-propozitia`, order) — 3 distractori la nivelul 9 și 4 la 11.

Verificări: generare la nivelurile noi și parcurgere pe telefon simulat; variantele cu alegeri au fost testate și pe tabletă simulată. Tabla AAC nu a fost transformată într-o probă obligatorie. Validarea pe dispozitiv real și cu specialistul rămâne necesară.

## Gândim (COG) — 11 jocuri

- [x] Continuă șirul (`continua-sirul`, choice) — de la nivelul 8, modele noi ABAC, ABBC și AABC; verificate prin generare și pe telefon/tabletă simulate.
- [ ] Anotimpuri (`anotimpuri`, choice)
- [ ] Unde trăiește? (`habitate`, choice)
- [ ] Sortăm (`sortam`, sort)
- [ ] La locul lui (`la-locul-lui`, sort)
- [ ] Cucu-bau (`cucu-bau`, shell)
- [ ] Autobuzul lui Licurici (`explorare-stiinte`, explore)
- [ ] Turnul (`turnul`, stacking)
- [ ] Atinge și vezi (`atinge-si-vezi`, cause)
- [ ] Ce urmează? (`ce-urmeaza`, order)
- [ ] Mare și mic (`mare-mic`, order)

## Emoții și prieteni (EMO) — 10 jocuri

- [ ] Cum se simte? (`cum-se-simte`, choice)
- [ ] Cât de tare? (`cat-de-tare`, choice)
- [ ] Cine e prietenul? (`cine-e-prietenul`, choice)
- [ ] Emoții (`emotii`, choice)
- [ ] Ce simte? (`ce-simte`, choice)
- [ ] Ce mă ajută? (`ce-ma-ajuta`, choice)
- [ ] Cine știe? (`cine-stie`, choice)
- [ ] Situații (`situatii`, choice)
- [ ] Sortăm emoțiile (`sortam-emotiile`, sort)
- [ ] Rândul meu, rândul tău (`pe-rand`, turns)

## Memorie și răbdare (FEX) — 12 jocuri

- [ ] Peștele din mijloc (`peste-in-mijloc`, choice)
- [ ] Pescarul (`pescarul`, reaction)
- [ ] Felinarele (`simon`, sequence)
- [ ] Licuricii din grădină (`licuricii`, sequence)
- [ ] Respiră (`respira`, calm)
- [ ] Acum sau mai mult? (`acum-sau-mai-mult`, delay)
- [ ] Stop! (`stop`, stop)
- [ ] Labirint (`labirint`, maze)
- [ ] Regula se schimbă (`regula-se-schimba`, rules)
- [ ] Semaforul (`semaforul`, wait)
- [ ] Floarea crește (`floarea-creste`, wait)
- [ ] Perechi (`perechi`, memory)

## Singur (AUT) — 6 jocuri

- [ ] Ajută-l pe Licurici (`ajuta-l-pe-licurici`, choice)
- [ ] Ce îmbrac? (`ce-imbrac`, choice)
- [ ] O zi bună (`explorare-viata`, explore)
- [ ] La magazin (`la-magazin`, shop)
- [ ] Pașii rutinei (`pasii-rutinei`, order)
- [ ] Orarul meu (`orarul-meu`, order)

## Mâini dibace (MOT) — 5 jocuri

- [ ] Atinge rapid (`atinge-rapid`, fitts)
- [ ] Hrănește peștii (`hraneste-pestii`, feed)
- [ ] Colorăm (`colorare`, color)
- [ ] Trasează (`traseaza`, trace)
- [ ] Unește punctele (`uneste-punctele`, trace)

## Numere și litere (PAC) — 29 jocuri

- [ ] Câte sunt? (`cate-sunt`, choice)
- [ ] Alfabetul (`alfabetul`, choice)
- [ ] Opuse (`opuse`, choice)
- [ ] Scriem corect (`ortografie`, choice)
- [ ] Silabe (`silabe`, choice)
- [ ] Citește cuvântul (`cuvinte`, choice)
- [ ] Unul și mai mulți (`plural`, choice)
- [ ] Ce fel de cuvânt? (`gramatica`, choice)
- [ ] Numărăm (`numaram`, choice)
- [ ] Comparăm (`comparam`, choice)
- [ ] Adunăm (`adunam`, choice)
- [ ] Scădem (`scadem`, choice)
- [ ] Semnele (`semne`, choice)
- [ ] Numărul lipsă (`numarul-lipsa`, choice)
- [ ] Zeci și unități (`zeci`, choice)
- [ ] Înmulțim (`inmultim`, choice)
- [ ] Împărțim (`impartim`, choice)
- [ ] Ceasul (`ceasul`, choice)
- [ ] Banii (`bani`, choice)
- [ ] Zilele și lunile (`calendar`, choice)
- [ ] Tabla înmulțirii (`tabla`, choice)
- [ ] Probleme (`probleme`, choice)
- [ ] Trecut și prezent (`trecut`, choice)
- [ ] Simbolurile țării (`simboluri`, choice)
- [ ] Personalități (`personalitati`, choice)
- [ ] Călătorie în timp (`explorare-istorie`, explore)
- [ ] Linia numerelor (`linia-numerelor`, numberLine)
- [ ] Scriem cifrele (`scriem-cifrele`, write)
- [ ] Scriem literele (`scriem-literele`, write)
