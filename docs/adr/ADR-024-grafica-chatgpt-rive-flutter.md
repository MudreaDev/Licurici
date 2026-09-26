# ADR-024: Grafică și animație: ChatGPT → Rive → Flutter (nu Unity/Spine)

Status: Acceptat · Data: 2026-09-26

## Context
Aplicația trebuie să arate profesionist, la nivelul AutiSpark: personaje ilustrate, fundaluri pe straturi, animații (pasărea respiră, bate din aripi, zboară la cuib, se bucură, clipește). Există un singur dezvoltator, fără ilustrator. A fost propus pipeline-ul „ChatGPT (grafică) → Claude (cod) → Unity (joc) → Spine / Unity 2D Animation (animații)”.

## Decizie
- **Ilustrațiile** se generează cu ChatGPT (PNG transparent, stil fix, personaje recurente).
- **Personajele** se taie pe bucăți (corp, aripi, coadă, cap, ochi…) și se animă cu oase în **Rive**. Animații cu nume (`Idle`, `Fly`, `FlyToNest`, `Land`, `Happy`, `Blink`) și un **state machine** cu intrări (ex. `corect`, `zboara`).
- **Jocul** rămâne în **Flutter** (+ Flame unde e buclă de joc). Fișierele `.riv` sunt controlate din Dart cu pachetul `rive`.
- **Fundalurile** sunt PNG pe straturi, animate în cod (legănare, parallax).

## De ce
- Aplicația copilului e cerută în Flutter și e deja construită pe Flutter (ADR-001). Etapa „oase + animații” din pipeline-ul propus e corectă și standard în industrie; doar unealta se schimbă, nu metoda.
- Rive: editor gratuit, runtime oficial pentru Flutter, fișiere mici (zeci de KB), grafică vectorială clară pe orice ecran. **State machine-ul** mută logica tranzițiilor în fișierul de animație, iar codul doar trimite intrări.
- O singură tehnologie pentru jocuri *și* pentru restul aplicației: meniuri, setări, poarta parentală, consimțământ, accesibilitate, sincronizare, lucruri la care Unity e slab.

## Alternative
Unity + Spine; Unity 2D Animation; Spine în Flutter (`spine_flutter`); Lottie; sprite sheets PNG; animații doar în cod.

## De ce nu
- **Unity:** ar cere rescrierea aplicației în C# și abandonarea deciziei ADR-001. Build-urile sunt mari. Interfețele de tip aplicație și accesibilitatea sunt greoaie. Schimbarea tehnologiei la jumătatea proiectului e greu de argumentat.
- **Spine:** excelent, dar plătit (editorul 69–369 $, iar runtime-ul cere licență). Are runtime Flutter, deci rămâne o alternativă validă dacă un animator lucrează deja în Spine.
- **Lottie:** redă animații liniare (After Effects), fără state machine interactiv.
- **Sprite sheets:** fișiere mari, se pixelizează pe tablete.
- **Doar cod:** potrivit pentru efecte și fundaluri, dar nu pentru personaje expresive.

## Când am alege altfel
- **Unity**, dacă majoritatea jocurilor devin 3D sau jocuri cu fizică complexă.
- **Spine**, dacă un animator profesionist lucrează deja în Spine.

## Consecințe
- Trebuie învățat editorul Rive (gratuit). Specificația resurselor (listă, dimensiuni, nume, prompturi, cum se taie personajele) stă în `docs/art/ghid-ilustratii.md`.
- Consistența stilului ChatGPT se obține cu un ghid de stil fix și personaje refolosite. Resursele se versionează în `packages/game_content`.
