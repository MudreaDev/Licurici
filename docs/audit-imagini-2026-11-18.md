# Audit imagini jocuri — 18.11.2026

Sarcina solicitată: verificarea imaginilor pictate din jocuri, corectarea celor nepotrivite și documentarea pentru Claude. Auditul nu este finalizat.

## Turnul

- `stacking_screen.dart`: piesa `parts/ring` este întinsă în dreptunghi și colorată prin `Part`; țarușul este un strat separat în spatele inelelor. Utilizatorul a semnalat aspectul plat, fără volum.
- A fost generată o propunere de inel din lemn cu gaură vizibilă și volum, cu instrumentul integrat de generare a imaginilor. Sursă locală neversionată: `output/imagegen/inel-turn-propunere.png`.
- Prompt: „Create one isolated horizontal wooden stacking toy ring for a children's educational game, viewed slightly from above and in front so its central hole and rounded three-dimensional thickness are unmistakable. Single neutral cream-colored ring, soft painted children's storybook illustration, gentle shading, centered, no pole, no other objects, no text, transparent background. Wide oval silhouette, clear empty hole.”
- Imaginea a fost integrată în `parts/ring.webp`. Inelele folosesc aceeași piesă la mărimi și culori diferite. Capturile pe tabletă simulată arată gaura, volumul și un inel așezat pe țaruș; verificarea pe dispozitivul real rămâne de făcut.
- Filtrul comun `tintBase` decupa luminile la alb și aplatiza piesele. A fost modificat; capturile arată umbre și pe cubul din „Rândul meu” și pe borcanele din „Colorează ce auzi”.
- Testul funcțional `stacking_test.dart` trece pe telefon și tabletă; 14 capturi `art_shots_test.dart` au fost regenerate. Capturile sunt locale, ignorate de git.

## Continuare — verificarea obiectelor și a pieselor

- Au fost inspectate planșe de contact pentru cele 214 obiecte, piesele, cardurile de joc și cele 96 de portrete `faces2`; verificarea marginilor transparente a găsit imagini cu siluete tăiate sau fragmente din celule vecine.
- S-au refăcut 37 de obiecte: `alarm_clock`, `boot`, `boy`, `bus`, `cart`, `chair`, `coat`, `dad`, `deer`, `eagle`, `fries`, `girl`, `grandma`, `grandpa`, `handshake`, `hug`, `jellyfish`, `lettuce`, `lion`, `lobster`, `lock_open`, `mom`, `palm`, `park`, `parrot`, `paws`, `raise_hand`, `school`, `shield`, `snowman`, `squid`, `sunglasses`, `swimming`, `tap`, `train`, `trash`, `wave`. Sursele și prompturile sunt în `README-objects-audit-20261118.md`; vechile intrări au fost păstrate ca arhivă.
- Piesa `parts/block` din „Rândul meu” a fost refăcută cu față, muchie superioară și latură; capturile cu mai multe blocuri așezate au fost inspectate pe telefon și tabletă simulate. Blocurile rămân colorate procedural.
- Convertorul `tools/art/convert_codex.py` acceptă opțional `Decupare: contur cu margine` în lista imaginii, pentru a încadra personajele generate cu margini transparente largi. Imaginile vechi nu sunt decupate automat. Testul `painted_assets_audit_test.dart` încarcă cele 37 de obiecte și verifică transparența marginilor; verificarea tuturor obiectelor nu mai găsește pixeli semnificativi pe margine.
- Formele educative și contururile pentru colorare rămân intenționat din cod. Planșele și capturile sunt verificări pe simulator, nu înlocuiesc testarea pe dispozitiv și nu acoperă fiecare stare sau combinație din cele 109 jocuri.

Sursele PNG sunt locale și ignorate de git; WebP-urile și prompturile sunt versionate.
