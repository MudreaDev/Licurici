# Ghid de ilustrații (ChatGPT / Codex `image_gen`) — Licurici

Cum se generează, se decupează și se predau ilustrațiile pentru aplicație, ca să arate ca **un singur set** și să poată fi
**animate din cod** (ADR-028: decupaje pe straturi + animație procedurală; fără Rive, fără cadre desenate de mână).
Exemplele reale (cu prompturile exacte) sunt în `packages/game_content/art/illustrations/README*.md`.

## 1. Reguli pentru toate imaginile

**Publicul:** copii mici și copii autiști. O imagine bună e **liniștită**: un singur subiect clar, mult spațiu gol,
contururi blânde, fără detalii care concurează pentru atenție.

- **Stil:** ilustrație pictată de carte pentru copii, contururi moi și rotunjite, lumină caldă, materiale ușor umbrite.
- **Paleta** (aceeași cu tokenii din `apps/child_app/lib/app/theme.dart`): mentă `#7FC0A3`, albastru-cer `#5B9BB5`,
  lavandă `#A9A3D1`, piersică `#F0B9A0`, galben-soare `#F2CF6B`, crem `#FFF8EC`.
- **Interzis:** text, litere, cifre, simboluri (jocurile de scris și numărat le desenează din cod), chenare, filigrane,
  roșu aprins, fețe înfricoșătoare, particule împrăștiate, fundaluri aglomerate, umbre pe sol (le pune codul).
- **Fundal transparent real** (RGBA) pentru tot ce nu e fundal de scenă — niciodată alb, verde sau „tablă de șah” desenată.
- **Distincte și pentru daltoniști:** două obiecte care trebuie deosebite într-un joc diferă și prin formă, nu doar prin culoare.

Începutul comun al promptului (se copiază, apoi urmează subiectul):

> Create one production illustration for Licurici, therapy games for young and autistic children. Soft painted children's
> storybook illustration, softly rounded outlines, warm gentle light, lightly shaded tactile materials, calm pastel palette
> mint #7FC0A3, sky blue #5B9BB5, lavender #A9A3D1, peach #F0B9A0, sunshine yellow #F2CF6B, cream #FFF8EC.
> No text, letters, numerals, watermark, border, harsh red, scary faces, or busy scattered particles.

## 2. Tipuri de imagini

| Dosar | Mărime finală | Fundal | Compoziție |
|---|---|---|---|
| `games/` (cardul jocului) | 512×512 | transparent | 1–4 obiecte simple, centrate, care spun mecanica (nu o scenă) |
| `domains/` (aria) | 768×576 (4:3) | aproape plat, crem → mentă | Licurici la stânga, un singur obiect al ariei la dreapta |
| `objects/` (stimuli: măr, minge…) | 256×256 | transparent | **un singur** obiect, frontal, centrat, ~80% din pânză, fără umbră |
| `faces/` (emoții) | 320×320 | transparent | aceeași față, aceeași poziție; se schimbă doar expresia |
| `actions/` (verbe) | 384×384 | transparent | un personaj, o acțiune clară, fără decor |
| `sprites/` (obiecte animate) | 384×384 | transparent | un obiect, orientat spre dreapta (codul îl întoarce) |
| `rewards/` (abțibilduri) | 384×384 | transparent | un personaj drăguț, contur alb gros ca la un sticker |
| `mascot/` (Licurici) | 512×512 | transparent | vezi §3 |
| `scenes/` (fundaluri) | 1536×1024 (3:2) | opac (cerul) / transparent (straturile) | vezi §4 |

Mărimile le face `tools/art/convert_codex.py` (WebP, decupare centrală la 4:3 pentru `domains/` și `scenes/`). Generează
mai mare (1024 px sau 1536×1024); nu micșora tu.

**Nume:** litere mici, fără diacritice, cu cratimă, identice cu id-ul din cod (`games/<id-ul jocului>.webp`,
`objects/<id-ul stimulului>.webp`). Un nume greșit = aplicația arată emoji-ul de rezervă (`Illustration(fallbackEmoji:)`).

## 3. Personaje pentru animație (decupaje pe straturi)

Codul animă personajele mișcând **straturi** (respirație, clipit, aripi, privire, salt) — deci straturile trebuie să se
suprapună perfect.

- **Aceeași pânză, aceeași poziție** pentru toate ipostazele: 1024×1024, aceeași linie a tălpilor, același vârf al pălăriei,
  același centru al trunchiului. Scrie coordonatele în prompt (ex. „hat top y=42, feet baseline y=981, torso center x=512”).
- **Părțile care se mișcă separat se generează separat:** corpul **fără aripi**, apoi fiecare aripă singură, pe pânză
  transparentă, cu rădăcina (punctul de prindere) într-o poziție dată în prompt.
- **Ipostazele noi se fac prin editarea ipostazei de bază** („identity-preserve: edit the supplied idle sprite… change ONLY
  the eyes”), nu de la zero — altfel personajul se schimbă ușor de la o imagine la alta.
- Expresiile = cadre întregi schimbate cu o tranziție scurtă (cross-fade + squash), nu animate cu oase.
- Pentru un personaj nou: o foaie de referință (față, profil, culori) + ipostaza de bază + aripi/brațe separate, apoi
  ipostazele (bucurie, încurajare, gândire, salut, somn, privire stânga/dreapta).

## 4. Fundaluri pe straturi (paralaxă)

O scenă = 3 imagini 1536×1024 suprapuse, mișcate din cod cu viteze diferite:

1. **Cerul** (`*_sky`): opac, foarte simplu, câțiva nori mari pe margini, **centrul gol** (acolo stau cardurile).
2. **Planul din spate** (`*_hills`): jumătatea de sus **complet transparentă**; dealuri largi doar în partea de jos;
   se continuă dincolo de marginile din stânga și dreapta (fără „insulă plutitoare”).
3. **Planul din față** (`*_front`): o fâșie foarte joasă (iarbă, câteva flori mici) **strict** în ultimii ~220 px;
   tot ce e deasupra, transparent.

Fără personaje sau animale în fundaluri (le pune codul, ca să se poată mișca). Contrast mic: fundalul nu are voie să
concureze cu stimulul jocului.

Acvariul e o excepție: e pictat din cod (`features/aquarium/reef*.dart`); briefurile pentru un fundal pictat sunt în
[brief-codex-acvariu.md](../brief-codex-acvariu.md).

## 5. Predarea

1. Pentru fiecare imagine, o secțiune într-un fișier `packages/game_content/art/illustrations/README-<lot>.md`:

   ```
   ## games/pe-rand.webp

   Sursă PNG: `C:/…/exec-….png`

   Prompt exact:

   > …
   ```

2. `python tools/art/convert_codex.py` → WebP-urile în dosarele lor (doar ce s-a schimbat).
3. `flutter test --dart-define=SHOTS=true --update-goldens` în `apps/child_app` și o privire pe capturi
   (`test/shots/`): imaginea se vede pe telefonul mic? se distinge de vecinele ei?

## 6. Verificarea fiecărei imagini

- [ ] Fundal transparent real (fără margine albă/verde; marginile netede, nu zimțate).
- [ ] Un singur subiect, recognoscibil la 96 px (cât e pe telefonul mic).
- [ ] Fără text, cifre, simboluri, chenare, umbre pe sol.
- [ ] În paleta setului; fără roșu aprins.
- [ ] Personaje: aceeași poziție ca ipostaza de bază (suprapune-le la 50% opacitate).
- [ ] Fundaluri: zonele care trebuie să fie goale chiar sunt goale (alpha 0).
- [ ] Nimic înfricoșător sau prea „aglomerat” pentru un copil sensibil la stimuli.
