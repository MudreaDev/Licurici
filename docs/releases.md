# Versiuni descărcabile

Versiunile de test sunt publicate în [GitHub Releases](https://github.com/MudreaDev/Licurici/releases).
APK-urile și arhivele compilate sunt atașamente ale versiunii, nu fișiere adăugate în istoricul Git.

## Aplicația copilului și panoul 0.1.4 (build 5) — pregătită pentru publicare

Versiunea include treptele documentate pentru toate secțiunile și corecția zonei tactile din Atinge rapid. Cele trei APK-uri și panoul web au fost construite; toate APK-urile au semnătura de test Android folosită în 0.1.3. Arhiva web conține `index.html`, `main.dart.js` și `c.html`, fără audio nefolosit. Teste: 679 nucleu, 584 copil (15 capturi opționale sărite), 37 panou, 90 backend, 7 Vercel; analiză Flutter curată și voce 2883/2883. Compilarea JavaScript a reușit; verificarea opțională Wasm semnalează incompatibilitatea cunoscută `socket_io_common`.

Publicarea și verificarea pachetelor se consemnează după încărcare; testarea pe dispozitiv fizic și validarea cu specialistul rămân necesare. Pachetele sunt pentru test, nu pentru magazine.

## Aplicația copilului și panoul 0.1.3 (build 4) — 19.11.2026

Publicată ca versiune de test: [v0.1.3-preview.1](https://github.com/MudreaDev/Licurici/releases/tag/v0.1.3-preview.1), din commitul `89fb73d`. Conține corecția coordonatelor și a indicatorului la Oglinda, rama rearanjată, cele două clipuri „Super” regenerate și nivelurile suplimentare documentate în [progresul pe jocuri](progres-niveluri-jocuri.md). Pronunția și atingerea pe tabletă fizică necesită verificare.

Cele trei APK-uri Android, arhiva panoului web și `SHA256SUMS.txt` sunt publicate; dimensiunile și digesturile SHA-256 de pe GitHub coincid cu cele locale. Semnătura APK-ului arm64 coincide cu cea din 0.1.2. Pachetul web necesită găzduire și API pe aceeași origine. Nu folosi această versiune ca versiune pentru magazine.

## Aplicația copilului 0.1.2 (build 3) — 18.11.2026

Publicată ca versiune de test: [v0.1.2-preview.1](https://github.com/MudreaDev/Licurici/releases/tag/v0.1.2-preview.1), din commitul `38648e7`. Cufărul răspunde și în modul calm / reduce motion: imagine deschisă timp de 1,2 s, fără mișcarea capacului sau bule. Ținta are minimum 64 dp și etichetă pentru cititorul de ecran. Bara de comenzi este separată de apă, ca să nu acopere cufărul pe telefon. Zi/noapte se schimbă instant când sistemul dezactivează animațiile.

Cele trei APK-uri Android sunt atașate; SHA-256 afișat de GitHub coincide cu cel local. Pentru majoritatea tabletelor se folosește `app-arm64-v8a-release.apk`. Panoul web a primit între timp setări noi; nu reutiliza arhiva precedentă ca fiind actualizată. Verificarea aplicației pe tableta reală rămâne necesară.

## 0.1.1 (build 2) — 25.10.2026

Publicată: [v0.1.1-preview.1](https://github.com/MudreaDev/Licurici/releases/tag/v0.1.1-preview.1), sursa `fc8baea`. Aplicația copilului și panoul au aceeași versiune. Cele 5 atașamente și digesturile SHA-256 au fost verificate pe GitHub după încărcare.

- `licurici-0.1.1-arm64-v8a.apk`: tablete și telefoane Android actuale.
- `licurici-0.1.1-armeabi-v7a.apk`: dispozitive Android mai vechi, pe 32 de biți.
- `licurici-0.1.1-x86_64.apk`: dispozitive / emulatoare Android x86_64.
- `licurici-panou-0.1.1-web.zip`: panoul compilat pentru găzduire web; nu se deschide direct prin dublu clic. API-ul trebuie să fie pe aceeași origine, la `/api/v1`. Include `c.html` pentru legarea tabletei; nu include backendul sau secretele serverului. Pentru Vercel, urmează [ghidul](deploy-vercel.md).
- `SHA256SUMS.txt`: sumele de control ale celor patru pachete.

Versiune de test pentru instalare directă, nu publicare în magazine. iOS nu este construit (necesită Mac/Xcode sau build în cloud). Panoul online rămâne la https://licurici-panou.vercel.app.

## Publicarea următoarei versiuni

1. Actualizează `version:` în `apps/child_app/pubspec.yaml` și `apps/dashboard/pubspec.yaml`; crește și numărul de build Android (după `+`).
2. Rulează verificările din `CODEX-CONTINUARE.md` §4. Termină testele Flutter înainte de build-uri; nu le rula simultan cu construirea Android.
3. Construiește copilul: din `apps/child_app`, `flutter build apk --release --split-per-abi`.
4. Construiește panoul: din `apps/dashboard`, `flutter build web --release --dart-define=API_URL=/api/v1 --dart-define=LIVE_POLL=true --dart-define=THERAPIST_CHILDREN=true`.
5. Arhivează conținutul `apps/dashboard/build/web/` fără `assets/packages/game_content/audio/` (nefolosit în panou), plus `deploy/vercel/static/c.html`. Calculează SHA-256 pentru arhivă și cele 3 APK-uri.
6. Actualizează README, predarea comună și acest istoric; commit și push pe ambele ramuri. Creează release-ul inițial ca draft, cu tag legat explicit de commit-ul sursă. Încarcă toate cele 5 fișiere, verifică numele/dimensiunile/sumele de control, apoi publică drept prerelease.
7. Nu înlocui fișierele unei versiuni deja publicate cu alt conținut: creează un tag nou pentru următoarea livrare. Nu încărca chei de semnare, `.env`, fotografii sau date despre copii.
