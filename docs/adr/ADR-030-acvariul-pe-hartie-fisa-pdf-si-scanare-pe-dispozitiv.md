# ADR-030: Acvariul pe hârtie — fișa PDF și scanarea pe dispozitiv

Status: Propus · Data: 2026-10-08

## Context
Acvariul (README §2) are deja colorarea pe ecran. Partea cea mai valoroasă terapeutic e însă **pe hârtie**: copilul colorează cu carioca (motricitate fină, fără ecran), apoi „își trezește” peștele cu camera. Avem nevoie de trei lucruri noi:
1. fișa A4 de printat (din aplicație, pentru părinte);
2. o fotografie a fișei;
3. găsirea fișei în fotografie, îndreptarea perspectivei și decuparea peștelui.

Constrângeri: offline, fără trimiterea imaginii nicăieri (e creația copilului, README §13), aceleași contururi ca pe ecran, testabil fără dispozitiv.

## Decizie
- **`pdf`** (Dart pur) generează fișa A4: conturul peștelui (același model ca pe ecran), patru **marcaje proprii** în colțuri (pătrat negru – inel alb – miez negru, raport 1:1:3:1:1) și un **cod de 4 biți** pentru model, între marcajele de sus.
- **`printing`** deschide dialogul sistemului de printare / partajare a PDF-ului. Butonul e în **colțul părintelui** (după poarta pentru adulți), nu la copil.
- **`image_picker`** face fotografia cu aplicația de cameră a sistemului (pe web: alegerea unui fișier). Nu ținem camera deschisă în aplicație.
- **Detectarea, perspectiva și decuparea sunt cod Dart pur în `licurici_core`** (`paper_scan.dart`): binarizare adaptivă, componente conexe, perechi concentrice (marcajul), omografie din 4 puncte, eșantionare biliniară, egalizarea luminii după hârtia albă din jurul peștelui. Rezultatul intră în același `buildFishImage` ca desenul de pe ecran.
- Fotografia nu se salvează; se păstrează doar desenul decupat (1000×600), local, ca orice pește (README §11).

## De ce
- **Pachete mici, oficiale sau larg folosite**, fără cod nativ propriu: `image_picker` și `printing` sunt mature, merg pe Android, iOS și web.
- **Algoritmul în Dart pur** se testează complet cu fotografii sintetice (fișa randată, deformată în perspectivă, cu lumină inegală și zgomot), fără cameră și fără dispozitiv.
- **Marcajele proprii** (nu ArUco, nu QR) sunt ușor de găsit și cu algoritmi simpli; codul de 4 biți alege modelul singur, deci copilul nu trebuie să spună ce pește a colorat.
- Fără OpenCV: n-ar aduce nimic pe care să nu-l putem face simplu pentru o fișă cu marcaje cunoscute, dar ar adăuga ~10 MB și cod nativ pe platforme.

## Alternative
1. OpenCV (`opencv_dart`) pentru detectare și perspectivă.
2. Google ML Kit Document Scanner.
3. Camera în aplicație (`camera`) cu detectare în timp real.
4. Fără hârtie — doar colorare pe ecran.

## De ce nu
1. **OpenCV:** binare mari, build nativ pe fiecare platformă, nu merge pe web; pentru 4 marcaje cunoscute e prea mult.
2. **ML Kit Document Scanner:** doar Android, trimite prin Google Play Services, nu știe de marcajele noastre și decupează „documentul”, nu peștele.
3. **`camera`:** ecran de cameră propriu, permisiuni, ciclu de viață, cod de previzualizare pe platforme. Aplicația de cameră a sistemului e suficientă pentru o singură poză.
4. **Doar ecran:** pierdem colorarea cu mâna (motricitate fină, mai puțin timp pe ecran), care e scopul principal al acvariului.

## Când am alege altfel
- Dacă fotografiile reale (lumină slabă, hârtie îndoită) dau multe eșecuri, trecem la `camera` cu ghidaj în timp real („apropie telefonul”) și, la nevoie, la OpenCV doar pe mobil.

## Consecințe
- Trei pachete noi în `apps/child_app`: `pdf`, `printing`, `image_picker` (+ permisiunea de cameră pe iOS, `NSCameraUsageDescription`).
- `licurici_core` primește `paper_scan.dart` (fără dependențe noi) și testele cu fotografii sintetice.
- Fișa și scanarea folosesc aceeași geometrie a paginii (`PaperSheet`), definită o singură dată în core.
- Notă la ADR-028: acvariul s-a făcut cu `CustomPainter` + simulare pură, nu cu Flame. N-a fost nevoie de un motor de joc.
