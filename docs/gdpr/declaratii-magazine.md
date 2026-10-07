# Declarațiile pentru magazine

> Ciornă. Vezi [README](README.md). De verificat la fiecare versiune: dacă se adaugă un SDK sau o
> colectare nouă, declarațiile se schimbă înainte de publicare.

## Google Play — Data safety (aplicația copilului)
- **Aplicația colectează date?** Da, **doar dacă părintele activează sincronizarea** (cont + acord). Fără
  asta: nu.
- **Partajare cu terți:** Nu (specialistul invitat și furnizorii împuterniciți nu sunt „terți” în sensul
  Play; rezumatele AI pleacă de pe server, nu din aplicație).
- **Tipuri de date (doar cu sincronizare):**
  - *Informații personale → Adresă de e-mail* (contul părintelui; colectat în panou / la autentificare),
    scop: gestionarea contului.
  - *Activitate în aplicație → Interacțiuni în aplicație* (rezultatele jocurilor), scop: funcționalitatea
    aplicației, personalizare.
- **Criptare în tranzit:** Da (TLS).
- **Ștergerea datelor:** Da — din panou („Șterg contul”) sau la cerere prin e-mail.
- **Families Policy:** fără reclame, fără SDK-uri de analytics/publicitate, fără ID de publicitate,
  fără locație; publicul-țintă include copii.
- **Permisiuni:** cameră (doar când copilul fotografiază fișa de colorat, prin aplicația de cameră a
  sistemului; poza nu se păstrează), internet (sincronizare opțională).

## Apple — App Privacy („nutrition label”) și Kids Category
- **Data Used to Track You:** Niciuna.
- **Data Linked to You** (doar cu sincronizare): *Contact Info → Email Address* (App Functionality);
  *Usage Data → Product Interaction* (App Functionality).
- **Data Not Linked to You:** Niciuna.
- **Kids Category:** fără reclame terțe, fără tracking, linkurile externe și setările doar după poarta
  pentru adulți ✅; `NSCameraUsageDescription` explică folosirea camerei ✅.

## De făcut înainte de prima publicare
- [ ] Link public către politica de confidențialitate (versiune finală, verificată).
- [ ] Verificarea că niciun pachet nou nu aduce SDK-uri de colectare (de ex. Firebase Analytics).
- [ ] Contul de dezvoltator pe numele operatorului din politică.
