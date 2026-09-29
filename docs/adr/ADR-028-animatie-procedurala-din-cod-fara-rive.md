# ADR-028: Animație procedurală din cod, fără Rive

Status: Propus · Data: 2026-09-29 · Înlocuiește: partea de Rive din ADR-021 și ADR-024

## Context
Platforma are ~50 de jocuri (catalogul pe arii), cu niveluri **generate algoritmic** (ADR-027): stimuli, poziții, personaje și scene se compun la rulare. Un singur dezvoltator, fără animator. Rive (ADR-021, ADR-024) cere muncă manuală în editor pentru fiecare personaj și obiect animat: oase, animații, state machine, export. Nu scalează la 50 de jocuri și nici nu se potrivește cu conținutul generat, pentru că nu poți anima de mână ceva ce apare abia la rulare. Rive nu poate fi nici editat de asistentul de cod: fișierele `.riv` sunt binare și se lucrează vizual.

## Decizie
- **Nu folosim Rive.** Toată animația e **cod** (Dart), parametrică și reutilizabilă.
- **Personajele** (Licurici + 2–3 personaje recurente) sunt **decupaje pe straturi** (corp, cap, ochi, aripi, brațe), tăiate automat din ilustrațiile ChatGPT (`tools/mascot-rig/split.py` → PNG-uri + `rig.json` cu pozițiile și punctele de articulație).
  Un singur widget generic (`CutoutRig`) le animă din cod: respirație, clipit, bătaie din aripi, privire spre o țintă, arătat cu mâna, săritură de bucurie, încurajare, somn. Stările sunt un mic automat în Dart.
- **Expresiile** (emoții) sunt **cadre desenate** (foaie de expresii ChatGPT) schimbate cu o tranziție scurtă (cross-fade + squash), nu animate cu oase.
- **Obiectele din jocuri** sunt ilustrații statice. Animația se aplică automat după **rolul** lor în mecanică (țintă, distractor, răspuns corect, recompensă, obiect tras), dintr-o bibliotecă comună de efecte („game feel”): apăsare, squash & stretch, plutire, legănare, magnet la plasare, pop, tremur blând, urme, particule. **Zero muncă de animație per joc.**
- **Scenele cu buclă** (acvariu, pescarul, labirint, cucu-bau): Flame, cu mișcări procedurale (sinusoide, curbe Bézier, boids pentru bancuri de pești, fizică simplă).
- Toate efectele au amplitudine/durată ca parametri și trec prin `MotionPolicy` (full / gentle / off) → modul calm și reduce-motion funcționează peste tot automat.

## De ce
- **Scalează:** un efect scris o dată merge în toate cele 50 de jocuri și pe orice stimul generat. Un joc nou primește animațiile gratis.
- **Se potrivește cu generarea algoritmică:** animația e o funcție de parametri (poziție, mărime, seed), deci merge pe conținut care nu există dinainte.
- **Totul e text:** codul e revizuibil, testabil, versionabil în git și poate fi scris și modificat de asistentul de cod. Nu există editor vizual obligatoriu.
- **Control terapeutic:** intensitatea animației devine un parametru (modul calm, sensibilitatea copilului), nu ceva „copt” într-un fișier.
- **Calitatea vizuală vine din ilustrații:** mișcarea e simplă (straturi care se rotesc, se scalează, se deplasează), dar ilustrațiile bune + easing-ul corect + game feel-ul dau rezultatul profesionist.
- Există deja începutul: `MotionPolicy`, cele 7 straturi de animație din `ChoiceMechanic`, mascota desenată în cod, scriptul de decupare.

## Alternative
1. Rive (decizia anterioară).
2. Spine (oase, editor plătit).
3. Lottie (animații After Effects).
4. Sprite sheets desenate cadru cu cadru.
5. Schimbarea stack-ului pe web (Phaser + Capacitor) pentru animații.

## De ce nu
1. **Rive:** muncă manuală în editor pentru fiecare personaj/obiect; nu merge pe conținut generat; binar, deci nu se poate edita din cod sau revizui în git.
2. **Spine:** aceeași problemă de muncă manuală, plus licență plătită.
3. **Lottie:** filme liniare, fără interactivitate, cer After Effects și un animator.
4. **Sprite sheets:** fiecare animație trebuie desenată cadru cu cadru; ChatGPT nu produce cadre consistente; fișiere mari.
5. **Phaser + Capacitor:** ar cere rescrierea `licurici_core` (74 de teste), a panoului și a sincronizării; WebView-ul adaugă variație de latență care strică măsurarea timpului de reacție (KPI din catalog); animația procedurală se scrie la fel de bine în Flutter.

## Când am alege altfel
- Dacă proiectul primește un **animator** și un personaj central are nevoie de „actorie” complexă (ex. un episod narativ): Rive sau Spine doar pentru acel personaj.
- Dacă apar jocuri de acțiune cu multe sprite-uri și fizică grea: Flame + `flame_forge2d` e suficient; un motor extern doar dacă Flame nu ajunge.

## Consecințe
- Ilustrațiile trebuie generate **pentru decupare**: personaj pe fundal verde uniform, părți separabile (aripi, brațe), o foaie de expresii cu același personaj în aceeași poziție. Regulile intră în `docs/art/ghid-ilustratii.md`.
- Personajele au mișcări mai simple decât o animație cu oase lucrată manual. Compensăm cu expresii desenate, easing bun, squash & stretch și sunet.
- De construit: `CutoutRig` + `rig.json`, biblioteca de efecte pe roluri, mișcări procedurale pentru Flame, teste de widget cu `MotionPolicy.off` (nicio animație nu rulează în modul calm).
- Pachetul `rive` nu se adaugă în proiect.
