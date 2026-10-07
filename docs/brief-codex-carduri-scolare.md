# Brief pentru Codex — cardurile jocurilor școlare noi

**NU modifica cod.** Generează cele 7 carduri de mai jos și notează-le într-un fișier nou
`packages/game_content/art/illustrations/README-cards11.md` (secțiuni `## games/<id>.webp`, cu `Sursă PNG:` și
`Prompt exact:`), apoi rulează `python tools/art/convert_codex.py`. Până atunci, aplicația arată emoji-ul jocului.

Toate folosesc același început și același final ca lotul `README-cards10.md` (stil, paletă, fundal transparent).
Mai jos e doar **subiectul** fiecărui card; restul promptului se copiază de acolo:

> Use case: illustration-story. Create one square 1024x1024 RGBA PNG Licurici game-card illustration for young children. Match the visible games/ce-face.webp, games/unde-e-ursul.webp and games/puzzle.webp as STYLE REFERENCES ONLY: soft painted children's storybook illustration, softly rounded outlines, warm gentle lighting, lightly shaded tactile materials, fine polished brushwork, large simple readable shapes and minimal detail. Subject: **‹SUBIECTUL›** Compact coherent composition centered inside the central 80% of the square canvas, all objects fully visible with generous transparent margins on every side. Calm pastel palette mint #7FC0A3, sky blue #5B9BB5, lavender #A9A3D1, peach #F0B9A0, sunshine yellow #F2CF6B, cream #FFF8EC. Real transparent alpha background, no white backdrop or checkerboard pixels. No scenery beyond the requested objects, floor, ground plane, external cast shadow, border, sticker rim, text, letters, numerals, labels, mathematical symbols, watermark, harsh red or extra decorations.

| Card | Subiectul |
|---|---|
| `games/bani.webp` | Exactly THREE soft pastel paper banknotes fanned slightly, one mint, one lavender, one peach, each with a plain round cream medallion and a thin cream border but NO numbers or letters, plus exactly TWO round sunshine-yellow coins in front of them. No wallet, hands or people. |
| `games/tabla.webp` | ONE small cream chalkboard-style slate with a soft sky-blue wooden frame, blank surface, leaning gently, with exactly THREE small sunshine-yellow five-pointed stars arranged in a neat row above it and ONE short mint chalk stick lying in front. Slate completely blank. |
| `games/probleme.webp` | ONE friendly child's hand-sized mint notebook lying open with blank cream pages, ONE light honey wooden pencil lying across it, and ONE small sunshine-yellow lightbulb glowing softly above the notebook. Pages blank. No people. |
| `games/gramatica.webp` | Exactly THREE rounded wooden toy blocks in a row, peach, mint and lavender, each with ONE simple painted picture and no letters: the peach block shows a tiny house, the mint block shows a tiny running shoe, the lavender block shows a tiny sunshine-yellow star. Blocks clearly separated. |
| `games/simboluri.webp` | ONE small friendly castle tower in cream stone with a sky-blue roof, and ONE gentle plain shield in lavender with a simple sunshine-yellow star painted on it, standing side by side. No flags, no national symbols, no text. |
| `games/trecut.webp` | Exactly TWO light sources side by side with a clear gap: on the left ONE old cream candle with a soft sunshine-yellow flame in a simple peach holder; on the right ONE modern round lightbulb glowing softly. Both the same height. |
| `games/engleza.webp` | ONE open storybook with a sky-blue cover and blank cream pages, with ONE small friendly mint speech bubble rising from it containing ONE small sunshine-yellow star, and ONE tiny red-free peach apple beside the book. Bubble empty except the star. No text. |

**Notă:** fără drapele în ilustrații (cardul „Simbolurile țării” rămâne neutru); drapelele apar doar în joc, din OpenMoji.
