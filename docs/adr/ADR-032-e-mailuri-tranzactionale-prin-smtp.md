# ADR-032: E-mailurile tranzacționale prin SMTP (nodemailer), din coada `mail`

Status: Propus · Data: 2026-10-09

## Context
Autentificarea adulților (ADR-012) nu avea confirmarea adresei și nici „Am uitat parola”: un părinte care își uita parola
își pierdea accesul la rapoarte, iar o adresă greșită la înscriere nu se observa. README §6 și §17 aleg **Brevo** pentru
e-mail (UE, DPA) și **Mailpit** în dezvoltare; coada BullMQ `mail` exista, dar fără consumator.

## Decizie
- **Confirmarea adresei:** la înregistrare pleacă o legătură (token aleator de 256 de biți, de unică folosință, 48 h);
  `POST /auth/verify-email` o consumă și setează `users.verifiedAt` (coloana exista). Retrimitere din panou:
  `POST /me/verify-email`; starea: `GET /me` (`emailVerified`). Contul neconfirmat **funcționează** (nu blocăm părintele).
- **Parola nouă:** `POST /auth/password/forgot` răspunde la fel pentru orice adresă (nu dezvăluie cine are cont);
  `POST /auth/password/reset` (token 1 h, o singură dată) schimbă parola, confirmă adresa și **închide toate sesiunile**
  (o „generație” a refresh tokenurilor în Redis — `TokenService.revokeAll`).
- În Redis stă doar **hash-ul** tokenurilor; limită de 3 e-mailuri pe oră pe cont/adresă.
- Trimiterea e **asincronă**: API-ul pune în coada `mail` doar `{kind, userId, token}`; worker-ul citește adresa din bază
  (în Redis nu stau e-mailuri) și trimite prin **SMTP** cu **nodemailer**. `SMTP_URL` = Mailpit în dezvoltare, releul SMTP
  Brevo în producție; lipsă = job-ul se încheie fără trimitere. Retry cu backoff exponențial (ADR-09).
- Legăturile duc în panou (`APP_URL/#/confirmare`, `#/parola-noua`), care trimite tokenul la API.

## De ce
- SMTP e standard: același cod merge cu Mailpit, Brevo sau orice alt furnizor (Adapter `MailProvider`, README §9).
- Coada separă API-ul de un furnizor extern lent sau căzut (README §8) și dă retry gratuit.
- Tokenuri opace în Redis (hash, TTL, GETDEL) — același model ca refresh tokenurile (ADR-012), fără migrare.

## Alternative
1. **API-ul HTTP Brevo** (`@getbrevo/brevo`).
2. Trimitere **sincronă** din API.
3. Tokenuri **JWT** în legătură (fără Redis).
4. Blocarea contului până la confirmare.

## De ce nu
1. Leagă codul de un furnizor; SMTP-ul Brevo face același lucru, iar Mailpit (dezvoltare) vorbește doar SMTP.
2. Un furnizor lent ar întârzia înregistrarea; o eroare de rețea ar pierde e-mailul.
3. Un JWT nu se poate folosi „o singură dată” fără stare; ar trebui oricum o listă de revocare.
4. Părintele poate folosi tableta fără cont; blocarea panoului ar adăuga fricțiune fără câștig de securitate real
   (confirmarea contează pentru recuperarea parolei și pentru rapoarte pe e-mail).

## Când am alege altfel
- Volume mari sau șabloane gestionate de echipa de conținut → API-ul HTTP al furnizorului (șabloane la ei, statistici).
- Dacă vin rapoartele săptămânale pe e-mail, confirmarea adresei devine condiție pentru ele.
