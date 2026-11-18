# Progresul nivelurilor pe secțiuni

Sursa listei: `catalog` din `licurici_core`; `dart run tool/catalog_levels_inventory.dart` generează inventarul.
O bifă înseamnă că jocul a fost abordat în această trecere, are o creștere reală a dificultății și a fost testat; nu înseamnă dificultate infinită sau validare terapeutică pe dispozitiv. O bifă nu se pune doar pentru că numărul nivelului crește.

Ordine: **Atenție**, **Fac și eu** și **Potrivim** (prima trecere completă), apoi Ascult și înțeleg, Vorbim, Gândim, Emoții și prieteni, Memorie și răbdare, Singur, Mâini dibace, Numere și litere. Trecerea la secțiunea următoare se face după verificarea tuturor jocurilor din secțiunea curentă. Unele jocuri au primit extinderi înainte de această evidență; ele sunt revizuite în secțiunea lor.

## Atenție (ATN) — 6 jocuri

- [x] Prinde licuriciul (`prinde-licuriciul`, reaction) — deplasare mai mare până la nivelul 18; ținta păstrează minimum 64 dp.
- [x] Paznicul farului (`paznicul-farului`, reaction) — distractori mai frecvenți până la nivelul 15.
- [x] Ce s-a schimbat? (`ce-s-a-schimbat`, change) — timp de observare redus treptat până la nivelul 15.
- [x] Unde se uită? (`unde-se-uita`, gaze) — perechi de obiecte asemănătoare alese explicit de la nivelul 8, cu rezervă pentru imaginile excluse.
- [x] Caută (`cauta`, search) — distractori din aceeași grupă de la nivelul 15, cu rezervă pentru imaginile excluse.
- [x] Urmărește peștele (`urmareste-pestele`, track) — 6 pești identici de la nivelul 16.

Verificări: teste de generare și calibrare pentru toate cele șase jocuri; jocuri parcurse la nivelurile noi pe telefon mic simulat, inclusiv ținte de minimum 64 dp la jocurile de reacție. Testul pe tabletă reală și validarea terapeutică rămân necesare. Fiecare joc păstrează un plafon real al mecanicii.

## Fac și eu (IMI) — 4 jocuri

- [x] Oglinda (`oglinda`, mirror) — până la cinci atingeri la nivelul 10.
- [x] Construiește la fel (`construieste`, build) — modelul se vede 4 secunde de la 8 și 3 secunde de la 10, cu posibilitatea de a-l revedea.
- [x] Toba magică (`toba-magica`, rhythm) — până la opt bătăi la nivelul 13.
- [x] Fă ca Licurici (`fa-ca-licuriciul`, imitation) — patru acțiuni la nivelul 11.

Verificări: generatoarele și cele patru jocuri au fost parcurse la nivelurile noi pe telefon mic simulat. Testul pe dispozitiv real și validarea terapeutică rămân necesare.

## Potrivim (POT) — 8 jocuri

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

- [ ] Arată-mi (`arata-mi`, choice)
- [ ] Corpul meu (`corpul`, choice)
- [ ] Ce face? (`ce-face`, choice)
- [ ] Mare, mic, roșu (`mingea-rosie`, choice)
- [ ] Unde e ursulețul? (`unde-e-ursul`, choice)
- [ ] Sus, jos, stânga, dreapta (`pozitii`, choice)
- [ ] Povești (`povesti`, choice)
- [ ] Adu-mi (`adu-mi`, fetch)
- [ ] Pune ursulețul (`pune-ursul`, place)
- [ ] Colorează ce auzi (`coloreaza-ce-auzi`, paintByEar)
- [ ] Ascultă și fă (`asculta-si-fa`, listen)

## Vorbim (COM) — 7 jocuri

- [ ] Ce ai auzit? (`ce-ai-auzit`, choice)
- [ ] Primul sunet (`primul-sunet`, choice)
- [ ] Da sau nu? (`da-nu`, choice)
- [ ] Ce se aude? (`ce-se-aude`, choice)
- [ ] Memorie cu sunete (`memorie-sunete`, soundMemory)
- [ ] Vorbește (`vorbeste`, aac)
- [ ] Spune propoziția (`spune-propozitia`, order)

## Gândim (COG) — 11 jocuri

- [ ] Continuă șirul (`continua-sirul`, choice)
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
