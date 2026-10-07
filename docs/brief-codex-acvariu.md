# Brief pentru Codex — straturile pictate ale acvariului

**NU modifica cod.** Generează doar imaginile de mai jos și notează-le, ca de obicei, într-un fișier nou
`packages/game_content/art/illustrations/README-aquarium.md` (secțiuni `## scenes/<nume>.webp`, cu
`Sursă PNG:` și `Prompt exact:`), apoi rulează `python tools/art/convert_codex.py`.

Aplicația le folosește automat (`features/aquarium/aquarium_screen.dart`): dacă un fișier lipsește, rămâne
recif desenat din cod. **Codul adaugă deja peste ele** razele de lumină, sclipirile de pe nisip, bulele,
particulele și algele care se leagănă — imaginile **nu** trebuie să le conțină (ar apărea dublate).

Ambele straturi sunt aliniate **jos** pe ecran și tăiate sus pe telefoanele late: pe un ecran 2:1 se
vede doar ~70% din înălțime, de jos în sus. Deci nimic important în treimea de sus.

## 1. `scenes/aquarium_back.webp` — fundalul (opac)

> Create one production illustration for Licurici, therapy games for young and autistic children. Match the supplied style references (scenes/meadow_sky.webp, scenes/pond.webp, games/puzzle.webp) as one coherent set: soft painted children's storybook illustration, softly rounded outlines, warm gentle light, lightly shaded tactile materials, calm pastel palette mint #7FC0A3, sky blue #5B9BB5, lavender #A9A3D1, peach #F0B9A0, sunshine yellow #F2CF6B, cream #FFF8EC. These references are style only, do not reproduce their subjects. Landscape aspect ratio 3:2, target 1536x1024. Asset scenes/aquarium_back.webp: OPAQUE full-bleed underwater view of a calm, friendly coral reef, seen straight from the side like looking into an aquarium. Water: soft turquoise near the top gently deepening to calm medium blue lower down, very low contrast, no harsh dark areas. A pale sandy floor occupies ONLY the bottom 11% of the canvas (its top edge around y=910, gently wavy), smooth sand with a few tiny pebbles. Far in the background, very faded blue-tinted silhouettes of rounded rocks and branching corals, like seen through water haze. Near the LEFT and RIGHT edges only (each within the outer 18% of the width), resting on the sand: a few soft rounded rocks, one pink branching coral, one peach coral, one lavender tube coral cluster, one small yellow brain coral. The entire central 64% of the width, from the top down to the sand, must stay calm open water with nothing in it, because the children's fish swim there. No fish, no animals, no characters, no light rays, no bubbles, no seaweed, no particles, no water surface line, no text, letters, numerals, watermark, border, harsh red or scary shapes.

## 2. `scenes/aquarium_front.webp` — prim-planul (transparent)

> Create one production illustration for Licurici, therapy games for young and autistic children. Same style references and palette as scenes/aquarium_back.webp. Landscape aspect ratio 3:2, target 1536x1024. Asset scenes/aquarium_front.webp: transparent foreground layer for an aquarium. Everything is true alpha=0 EXCEPT two small clusters in the bottom corners: in the bottom-left corner (x 0–230, y 700–1023) and in the bottom-right corner (x 1306–1535, y 700–1023), a few large soft rounded rocks with a little mint moss and one or two small sea anemones or round shells, slightly darker and closer than the background, softly lit from above. The whole middle of the canvas and the entire upper area are empty transparent pixels. No seaweed (the code draws swaying seaweed), no fish, no animals, no bubbles, no sand strip across the width, no ground plane, no cast shadow, no text, letters, numerals, watermark, border, harsh red. Real transparent alpha background, no white backdrop or checkerboard pixels.

## Verificare după generare

- Deschide `/acvariu` în aplicație (web: `flutter build web`, apoi serverul `child-app-web`).
- Nisipul pictat trebuie să fie la aceeași înălțime cu umbrele peștilor (linia de nisip din cod e la ~86% din
  înălțimea ecranului). Dacă nu se potrivește, regenerează cu marginea nisipului mai sus/jos — nu muta codul.
- Mijlocul acvariului trebuie să rămână liber și calm (peștii copilului sunt vedetele).
