# Acvariul: pești „3D” desenați din cod, fără shadere și fără motor 3D

*Notă de cercetare pentru teză (README §23). Starea din sesiunea a noua (09.10.2026).*

## Problema
Copilul colorează un pește pe o fișă (pe ecran sau pe hârtie, ADR-030), iar peștele lui trebuie să **înoate** în acvariu ca un
pește adevărat: cu volum, cu adâncime, cu viraje credibile. Constrângeri: Flutter pur (ADR-028: fără Rive, fără Unity, fără
shadere — pe web ieșeau negre), offline, 60 de cadre pe secundă pe o tabletă obișnuită, desenul copilului rămâne recognoscibil.

## 1. Simularea (Dart pur, `licurici_core/lib/src/aquarium.dart`)
Fiecare pește e un **agent cu stare fizică**, nu o interpolare spre o țintă:

| Mărime | Rol |
|---|---|
| `pos` (x, y pe ecran), `z` ∈ [0, 1] | locul; `z` = adâncimea (0 = la geam). Perspectiva: `scale(z) = 1 − 0,42 z`. |
| `yaw` | direcția în planul orizontal (x – adâncime). `facing = cos(yaw)` (−1 stânga … +1 dreapta). |
| `turnRate` | viteza de rotire, limitată (1,9–7 rad/s după stare) și cu **inerție** (filtru de ordinul I). |
| `speed`, `thrust` | viteza câștigată din coadă (accelerație) și pierdută prin **frecare** (alunecare); `thrust` = cât bate coada. |
| `climb` | urcare/coborâre, mai lentă decât înaintarea (peștii nu înoată vertical). |

Pasul de simulare: (1) direcția dorită `atan2(dz, dx)` spre țintă (în coordonate „de lume”: dx împărțit la `scale`, dz înmulțit
cu adâncimea acvariului); (2) `turnRate` urmărește eroarea unghiulară; (3) viteza țintă scade în viraje strânse
(`cos(diferență)`) și la sosire; peste ea, **reprize de înot** (impuls 0,5–1,1 s, apoi alunecare); (4) urcarea e limitată;
(5) pe ecran, deplasarea se înmulțește cu `scale(z)` (peștii din spate par mai lenți). Separarea între pești se face în spațiu
(cu tot cu adâncimea). Totul e determinist (seed), deci testabil: 20 de teste (rămâne în apă, fuge de deget spre fundal, vine la
geam când e chemat, virajul are viteză de rotire mare și apoi se liniștește, caută pe fund, se învârte când e atins, banc mic).

Comportamente (o mașină de stări mică): plimbare în reprize, odihnă, căutat pe fund (capul aplecat, „ciugulit” = eveniment
pentru un norișor de nisip), venit la geam, înot în urma altui pește, fugă (pornire în „C”: smucitură a cozii, apoi țâșnire),
adunare la deget, mâncat. Peștele-balon se umflă în loc să fugă.

## 2. Randarea (`apps/child_app/lib/features/aquarium/fish_render.dart`)
Peștele e **desenul copilului întins pe o plasă** de 26 × 10 vârfuri (`Canvas.drawVertices`, textură = imaginea peștelui).
Ideea centrală: o **coloană vertebrală 3D proiectată**.

1. Fiecare coloană a plasei (o „felie” a corpului, de la coadă la cap) primește o direcție proprie
   `ψ(t) = yaw + undă(t) + îndoire(t)`, unde `t` ∈ [0, 1] e poziția de la cap la coadă:
   - **unda** (înotul carangiform): `A·(0,05 + 0,95 t²)·sin(fază − 2,5 t)`, cu amplitudinea `A` din `thrust` și bucurie;
   - **îndoirea din viraj**: `−turnRate·0,16·t^1,3` — coada rămâne în urma capului (corpul în „C”).
2. Coloana se **integrează** segment cu segment: `x += Δ·cos ψ`, `adâncime += Δ·sin ψ`. Proiecția pe ecran e `x`; deci coada care
   bate spre noi se scurtează (perspectivă), iar la întoarcere capul trece primul, coada vine după.
3. **Volumul în lateral**: vârfurile se deplasează cu `grosime·profil(t)·√(1 − rând²)·sin ψ`, deci burta se vede rotunjită când
   peștele e privit din unghi.
4. **Ordinea de desen**: fâșiile se sortează după adâncime (cele mai depărtate întâi) — la întoarcere, capul trece corect prin
   fața sau prin spatele cozii.
5. **Lumina per vârf** (culori de vârf, `BlendMode.modulate`): felia văzută din față e luminată, cea văzută pe muchie mai
   întunecată; peste, reflexe de apă care se mișcă (`sin` pe poziția din lume). Absorbția apei și **ceața** după `z` sunt
   ușoare (desenul copilului își păstrează culorile).
6. **Vederea din față/spate**: când capul e aproape perpendicular pe ecran (`|cos ψ| < 0,36`), peste plasă apare lin un corp
   rotund pe care e întinsă chiar bucata din desen din spatele capului, cu ambii ochi și gura (sau, din spate, coada care bate).

Volumul static (o dată pe model, `FishBody`): transformata distanței față de contur → grosime → normale → lumină difuză, luciu,
umbră spre burtă și margini mai întunecate. Linia neagră a fișei e înlocuită cu o nuanță închisă a culorii vecine (umplere
din vecini), iar înotătoarele sunt ușor translucide.

## 3. Scena
Fundul e în perspectivă (aceeași funcție în simulare și în desen: `Aquarium.floorAt(z)`), deci umbrele peștilor și „ciugulitul”
cad unde trebuie. Causticele sunt o textură Voronoi generată din cod (256², se repetă fără margini), în două straturi care se
mișcă în sensuri diferite. Nimic nu folosește `saveLayer` pe fiecare cadru în modul de zi (cost mic pe GPU); noaptea folosește
un singur strat (lumina degetului „găurește” întunericul).

## Ce rămâne de măsurat
- Fluiditatea pe tablete reale (în browserul ascuns animațiile sunt încetinite, măsurătoarea de acolo nu e relevantă).
- Dacă vederea din față e înțeleasă de copii ca „același pește” (observație în testarea cu copii).
