# Versiuni descărcabile

Versiunile de test sunt publicate în [GitHub Releases](https://github.com/MudreaDev/Licurici/releases).
APK-urile și arhivele compilate sunt atașamente ale versiunii, nu fișiere adăugate în istoricul Git.

## 0.1.1 (build 2) — 25.10.2026

Tag: `v0.1.1-preview.1`. Aplicația copilului și panoul au aceeași versiune.

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
