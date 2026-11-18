# Audit imagini jocuri — 18.11.2026

Sarcina solicitată: verificarea imaginilor pictate din jocuri, corectarea celor nepotrivite și documentarea pentru Claude. Auditul nu este finalizat.

## Turnul

- `stacking_screen.dart`: piesa `parts/ring` este întinsă în dreptunghi și colorată prin `Part`; țarușul este un strat separat în spatele inelelor. Utilizatorul a semnalat aspectul plat, fără volum.
- A fost generată o propunere de inel din lemn cu gaură vizibilă și volum, cu instrumentul integrat de generare a imaginilor. Sursă locală neversionată: `output/imagegen/inel-turn-propunere.png`.
- Prompt: „Create one isolated horizontal wooden stacking toy ring for a children's educational game, viewed slightly from above and in front so its central hole and rounded three-dimensional thickness are unmistakable. Single neutral cream-colored ring, soft painted children's storybook illustration, gentle shading, centered, no pole, no other objects, no text, transparent background. Wide oval silhouette, clear empty hole.”
- Imaginea a fost integrată în `parts/ring.webp`. Inelele folosesc aceeași piesă la mărimi și culori diferite. Capturile pe tabletă simulată arată gaura, volumul și un inel așezat pe țaruș; verificarea pe dispozitivul real rămâne de făcut.
- Filtrul comun `tintBase` decupa luminile la alb și aplatiza piesele. A fost modificat; capturile arată umbre și pe cubul din „Rândul meu” și pe borcanele din „Colorează ce auzi”.
- Testul funcțional `stacking_test.dart` trece pe telefon și tabletă; 14 capturi `art_shots_test.dart` au fost regenerate. Capturile sunt locale, ignorate de git.

## Restul jocurilor

Nu a fost efectuată încă o verificare vizuală completă; prezența fișierelor nu demonstrează calitatea în joc. Lista utilizărilor `Part` se găsește prin `rg "hasPart\(|Part\(" apps/child_app/lib/features/games`; obiectele prin `StimulusArt` necesită și ele examinare. Nu înlocui formele educative sau contururile de colorat intenționate.

Nu s-a verificat vizual fiecare joc sau fiecare stare a jocurilor. Nu considera auditul complet.
