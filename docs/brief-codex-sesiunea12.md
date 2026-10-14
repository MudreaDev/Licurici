# Brief pentru Codex — acvariul pe ecranul principal și butoanele acvariului (sesiunea a douăsprezecea)

**NU modifica cod.** Generează doar imaginile de mai jos și notează-le într-un fișier nou
`packages/game_content/art/illustrations/README-aquarium2.md` (secțiuni `## <folder>/<nume>.webp`, cu
`Sursă PNG:` și `Prompt exact:`, ca în `README-cards10.md`), apoi rulează `python tools/art/convert_codex.py`.

Referințe de stil (doar stil, nu subiect): `games/puzzle.webp`, `games/ce-face.webp`, `scenes/pond.webp`,
`sprites/fish_colorful.webp` din `packages/game_content/art/illustrations/`.

Început comun pentru toate (copiază-l în fiecare prompt):

> Use case: illustration-story. Create one production illustration for Licurici, therapy games for young and autistic children. Match the supplied style references as one coherent set: soft painted children's storybook illustration, softly rounded outlines, warm gentle light, lightly shaded tactile materials, fine polished brushwork, large simple readable shapes, minimal detail. Calm pastel palette mint #7FC0A3, sky blue #5B9BB5, lavender #A9A3D1, peach #F0B9A0, sunshine yellow #F2CF6B, cream #FFF8EC. References are style only, do not reproduce their subjects. No text, letters, numerals, labels, watermark, border, harsh red, frightening shapes.

## 1. `scenes/aquarium_mini.webp` — fereastra acvariului de pe ecranul principal (opac)

Codul o pune într-o ramă rotunjită pe ecranul principal și desenează peste ea **peștii colorați de copil**, care
înoată. Deci imaginea **nu are pești** și are mijlocul liber.

> Landscape 3:2, target 1536x1024, OPAQUE full-bleed. The cosy inside of a small friendly home aquarium seen straight from the front, filling the whole canvas edge to edge (no glass frame, no tank edges, no table, no room). Clear calm turquoise water, lighter near the top with a soft glowing water surface band in the top 8%, gently deeper blue lower down, very low contrast. A pale sandy floor across the bottom 18% with a few round pebbles. On the LEFT within the outer 22% of the width: one tall mint seaweed clump and one pink-peach branching coral. On the RIGHT within the outer 22%: one small closed wooden treasure chest with a sunshine-yellow lock, one lavender tube coral, two round shells. The whole centre (middle 56% of the width, from the surface down to the sand) is open calm water, empty. A few soft light dapples on the sand. No fish, no animals, no characters, no bubbles, no light rays, no particles.

## 2. Butoanele acvariului (transparente, pătrate)

Fiecare: `Square 1024x1024 RGBA PNG with real transparent alpha background. One isolated object centered inside the central 80% of the canvas, generous transparent margins, no ground plane, no cast shadow, no scenery.`

| Fișier | Subiectul |
|---|---|
| `sprites/food_jar.webp` | ONE small round glass jar of fish food with a sunshine-yellow screw lid, filled with colourful pastel flakes (peach, mint, sunshine yellow), a few flakes gently falling from its tilted open top. |
| `sprites/brush_fish.webp` | ONE chunky children's paintbrush with a light honey wooden handle and a mint ferrule, its tip loaded with peach paint, painting ONE small simple fish outline drawn on a little cream paper card behind it; the fish is half coloured peach. |
| `sprites/camera_sheet.webp` | ONE friendly rounded sky-blue toy-like photo camera with a big round lens, in front of ONE cream paper sheet showing a simple fish outline coloured with crayon strokes. |
| `sprites/moon_night.webp` | ONE soft sunshine-yellow crescent moon with a gentle sleepy smile-free face (no face at all), with TWO tiny cream stars beside it, glowing softly. |
| `sprites/sun_day.webp` | ONE round sunshine-yellow sun with short soft rounded rays, no face, glowing warmly. |

## Verificare după generare

- `scenes/aquarium_mini` trebuie să fie opac, fără pești, cu mijlocul liber.
- Spritele: alfa reală (fără tablă de șah pictată), obiectul întreg, fără umbră pe podea.
