# Landing Licurici — 14.11.2026

Pagina: **https://licurici-mudrea.vercel.app**

- Sursă: `deploy/landing/`; ramură: `codex/landing-prezentare`.
- Proiect Vercel: `licurici-prezentare` (`prj_GDDQs9IB4fKC1s9bFIUIzKP9TMbf`), echipa `mudreadevs-projects`.
- Checkout izolat: `tmp/landing-prezentare/` în checkout-ul original. Modificările locale anterioare ale aplicației nu sunt incluse.
- **Nu se împinge această ramură pe `main` sau `master`.** Excepția pentru sarcina aceasta provine din cererea explicită a utilizatorului, nu schimbă regulile generale ale proiectului. Nu se modifică `licurici-panou`.

## Carusel
Splide 4.1.4, MIT, livrat local și verificat prin hash-uri. ADR-035 documentează selecția bibliotecii. Motorul propriu anterior a fost înlocuit.

## Ce conține
Prezentare responsivă, șase capturi de telefon într-un autoslider Splide 4.1.4 la 5 secunde, dialog pentru mărire, acvariu, principii, rolurile adulților, prezentarea tezei și întrebări cu răspunsuri. Fără conturi, formulare, analytics sau dependențe externe la încărcarea paginii. Respectă `prefers-reduced-motion`, are navigare cu tastatura, link de salt și etichete pentru capturi.

Sliderul pornește când intră în ecran. Se oprește la ascunderea paginii, la deschiderea imaginii, la focus în comenzi și în dialog. Navigarea folosește track real, loop și glisare tactilă; `prefers-reduced-motion` îl pornește oprit. Butoane anterioară/următoare/pauză, fără anunțuri live repetate la schimbările automate.

Secțiuni suplimentare: șase lumi ilustrate cu legături la exemple, pașii unei sesiuni și trei direcții de cercetare. Resursele `domain-*.webp` provin din `packages/game_content/art/illustrations/domains/`.

## Date academice de confirmat
- **Proiect de licență**, confirmat explicit de utilizator în corecția din 14.11. Mențiunea inițială despre master a fost înlocuită.
- Autor: **Mudrea Mihail**, UTM. Coordonator: **Mihail Musteața**, confirmat explicit de utilizator; înlocuiește referința inițială la coordonatorul laboratorului PSI.
- „Licurici — platformă educativă adaptivă pentru copii” este **titlu de lucru**, nu formulare oficială pretinsă.

## Resurse vizuale și proveniență
- `assets/home.png`, `emotions.png`, `language.png`, `tower.png`, `mirror.png`, `painting.png`: capturi Flutter la 844×390, generate la 14.11.2026 prin `apps/child_app/test/landing_shots_test.dart`. Testul preîncarcă `MascotRig.available()` și verifică `LayeredMascot` în meniul principal, prevenind revenirea la desenul vechi de rezervă în captură. Fără date reale de copii; numele din poveștile jocurilor sunt conținut fictiv. Pictograme Material încărcate explicit în test; fără panglica debug.
- `assets/aquarium.png`: captura existentă `apps/child_app/test/shots/acvariu-pictat.png`, din verificarea scenei pictate. Nu este o captură a modificărilor locale necomise.
- `assets/mascot.webp`: ilustrația existentă `packages/game_content/art/illustrations/mascot/wave.webp`.
- `assets/meadow.webp`: ilustrație nouă generată pentru acest landing, convertită WebP cu Pillow (aceeași bibliotecă folosită în `tools/art/`). Sursa PNG rămâne local în `tmp/landing-meadow-source.png`, în checkout-ul original.
- Prompt: „Wide landscape watercolor illustration for a Romanian children's educational app presentation. No lettering, text, devices or UI. Warm ivory paper, calm pastel sage meadow, rounded trees at borders, golden fireflies, winding pale footpath, airy empty sky and open center. Muted sage, buttery yellow, peach, teal; subtle pencil grain. Gentle editorial picture book art, not 3D, glossy or neon.”
- Fonturi locale Nunito, licența inclusă în `assets/OFL.txt`.
- Referințe de compoziție consultate: [App Presentation / Dribbble](https://dribbble.com/tags/app-presentation), [mobile app landing page / design.dev](https://design.dev/templates/landing-pages/mobile-app-landing-page/). Nu s-au copiat imagini sau template-uri.

## Rulare și verificare
Din rădăcina checkout-ului acestei ramuri:
```powershell
node tools/preview/serve.mjs deploy/landing 5181
node tools/landing/check.mjs
node --check deploy/landing/app.js
```
Capturi, din `apps/child_app` (după rezolvarea dependențelor):
```powershell
flutter test --no-pub --update-goldens --dart-define=SHOTS=true test/landing_shots_test.dart
flutter analyze --no-pub test/landing_shots_test.dart
```
Pe Windows rezolvarea inițială a dependențelor a avertizat despre symlink-uri/Developer Mode. Pachetele s-au rezolvat, iar testele cu `--no-pub` au trecut fără schimbarea setărilor sistemului.

## Publicare
Fără build sau instalare de dependențe. Vercel primește sursa din commitul împins pe ramura dedicată, `rootDirectory: deploy/landing`, `outputDirectory: .`, `framework: null`, comenzi de build/install goale. Ținta `production` se referă **numai la noul proiect de prezentare**, nu la panoul existent. Nu se configurează auto-deploy din `main` pentru acest proiect.

Vezi ADR-034 pentru motivarea separării. După modificări se verifică pagina, imaginile, galeria, închiderea dialogului cu Escape și butonul dedicat, întrebările, legăturile și lățimile mobile înainte de o nouă publicare.

**Actualizare landing 15.11.2026:** fundal pictat cu tonuri salvie și miere, mișcare lentă și șase puncte luminoase fără clipire; fără buton separat pentru fundal, la cererea utilizatorului; respectă în continuare preferința de mișcare redusă. Carusel Splide 4.1.4 local; coordonator Mihail Musteața. Publicare exclusiv din `codex/landing-prezentare`, fără schimbări pe main/master.
