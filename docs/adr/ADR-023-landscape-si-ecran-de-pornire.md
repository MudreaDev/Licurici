# ADR-023: Landscape obligatoriu și ecran de pornire cu pre-încărcare

Status: Acceptat · Data: 2026-09-26

## Context
Aplicația copilului rulează pe telefoane și tablete. Pe telefon, jocurile (stimul + 2–5 variante mari + mascotă) nu încap bine în portret, iar copiii mici țin telefonul orizontal, ca la jocuri și desene animate. Cu ~58 de jocuri și sute de ilustrații și clipuri audio, trebuie să evităm ecranul alb la pornire și imaginile care apar „cu întârziere” în timpul animațiilor.

## Decizie
1. **Doar landscape** pe telefon și tabletă: `SystemChrome.setPreferredOrientations` + `android:screenOrientation="sensorLandscape"` + `UISupportedInterfaceOrientations` (fără portret) + `UIRequiresFullScreen` pe iPad. Ecran complet (`immersiveSticky`). Pe web, un telefon ținut în portret vede îndemnul „Întoarce telefonul”.
2. **Layout pe două panouri** când lățimea ≥ 1,2 × înălțimea: stimulul în stânga (se scalează după înălțime între 0,6× și 1,5×), variantele în dreapta, mascota într-un colț fix. Pe ecranul principal, jocurile se derulează **orizontal**, grupate pe materii.
3. **Pornire în două etape:**
   - splash nativ în culoarea aplicației (`#EEF5F4`), ca să nu apară ecran alb cât pornește motorul Flutter;
   - ecran de pornire în aplicație (mascota + bară de progres) cât se încarcă manifestul vocii și se pre-încarcă ilustrațiile interfeței și ale cardurilor de joc. Fiecare pas e tolerant la erori, iar ecranul stă vizibil minimum 600 ms, ca să nu „pâlpâie”.
4. **Pre-încărcare per joc:** înainte de prima rundă, aplicația încarcă în cache toate ilustrațiile lecției (`Lesson.art`).

## De ce
- **Nu se compilează nimic pe telefon.** Dart e compilat AOT în cod nativ la build, iar resursele sunt împachetate în APK/IPA. Pornirea înseamnă doar încărcarea motorului și citirea resurselor, deci un ecran scurt de pornire e suficient; nu e nevoie de un „loading” lung.
- Pre-încărcarea mută costul decodării SVG înainte de animații → 60 fps în timpul jocului.
- Landscape oferă mai mult spațiu orizontal pentru variante mari (≥ 64 dp) și pentru mascotă, fără derulare verticală. Asta ajută predictibilitatea: totul e pe un singur ecran.

## Alternative
Portret + landscape (layout adaptiv pentru ambele); doar portret; încărcare leneșă fără ecran de pornire; descărcarea resurselor la prima pornire.

## De ce nu
- **Ambele orientări:** dublează munca de layout și testare pentru ~58 de jocuri; rotirea accidentală în timpul jocului schimbă tot ecranul, ceea ce e neplăcut pentru copiii cu TSA.
- **Doar portret:** variantele devin prea mici sau trebuie derulat.
- **Fără ecran de pornire:** ecran alb, apoi imagini care apar pe rând.
- **Descărcare la prima pornire:** ar cere internet, contrar offline-first (ADR-04). Pachetele suplimentare de conținut vor avea propriul ecran de descărcare.

## Când am alege altfel
- Portret pentru jocuri anume, de exemplu trasarea literelor pe telefon, dacă testele cu copii arată că e mai natural. Orientarea se poate schimba doar pe ruta acelui joc.
- Un ecran de descărcare dedicat când apar pachetele de conținut din stocarea S3 (ADR-15).

## Verificare
`apps/child_app/test/layout_test.dart` randează aplicația la 640×360, 844×390, 915×412 și 1280×800. Orice depășire de layout pică testul, iar testul verifică și îndemnul de rotire la 390×844. Cu `--dart-define=SHOTS=true --update-goldens` generează capturi PNG pentru inspecție.
