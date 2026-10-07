# Registrul activităților de prelucrare (RoPA)

> Ciornă — document intern de responsabilizare (Legea 195/2024; GDPR art. 30). Vezi [README](README.md).
> Operator: […]. Contact protecția datelor: […]. Ultima actualizare: 2026-10-08.

| # | Activitatea | Scop | Persoane vizate | Categorii de date | Temei | Destinatari | Transfer extra-SEE | Retenție | Măsuri |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Conturi și autentificare ✅ | Accesul adulților la panou | Părinți, specialiști | E-mail, hash parolă (Argon2id), rol, date creare/ștergere | Contract | Găzduire | Nu | Cât există contul; ștergere definitivă la 7 zile după cerere | TLS, Argon2id, JWT 15 min, refresh de unică folosință (hash în Redis) |
| 2 | Consimțăminte ✅ | Dovada acordului pe scopuri | Părinți | Scop, acordat/retras, versiunea politicii, data, hash IP | Obligație legală | Găzduire | Nu | Durata contului + 3 ani 🕓 (acum: cât există contul) | Jurnal append-only |
| 3 | Profilul copilului ✅ | Adaptarea conținutului | Copii | Poreclă, avatar, anul nașterii, clasa, setări senzoriale | Consimțământ parental | Găzduire (doar cu „Sincronizare”) | Nu | Cât există profilul | Fără nume real / dată completă / foto / diagnostic |
| 4 | Sesiuni de joc ✅ | Progres, dificultate adaptivă, rapoarte | Copii | Încercări (joc, nivel, alegere, corect, ajutor P0–P4, latență), dispoziția aleasă, cereri AAC, KPI agregate | Consimțământ parental („Sincronizare”) | Găzduire; specialistul invitat | Nu | 24 luni rulant 🕓 (job de expirare de făcut) | Idempotență, acces pe `parentId` / `CareLink` activ |
| 5 | Partajarea cu specialistul ✅ | Terapie coordonată | Copii, specialiști | Legătura copil–specialist, termen | Consimțământ („Partajare”) | Specialistul | Nu | Până la expirare (implicit 90 zile) / revocare | Doar citire, audit |
| 6 | Rezumate AI ✅ (opțional) | Rezumatul sesiunii în cuvinte | Copii (pseudonimizat) | Fapte agregate ale sesiunii (fără poreclă/id) → text rezumat | Consimțământ separat („Rezumate AI”) | **Anthropic** (împuternicit) | **Da (SUA)** — SCC/DPA | Rezumatul: cât există sesiunea; la Anthropic: conform DPA (fără antrenare) | Pseudonimizare, limită zilnică, cache |
| 7 | Export și ștergere ✅ | Drepturile persoanei | Părinți, copii, specialiști | Toate datele contului | Obligație legală | — | Nu | Audit: cât există contul | Parola cerută la ștergerea contului |
| 8 | Jurnal de audit ✅ | Securitate, responsabilizare | Părinți, specialiști | Actor, acțiune, țintă, dată | Obligație legală / interes legitim | Găzduire | Nu | Cât există contul | Fără conținut, doar evenimente |
| 9 | Jurnale tehnice 🕓 | Securitate, depanare | — | Fără PII, IP trunchiat | Interes legitim | Găzduire | Nu | 30 zile | Pino, fără corpul cererilor |
| 10 | Raport săptămânal pe e-mail 🕓 | Informarea părintelui | Părinți | E-mail, rezumat agregat | Consimțământ | Furnizor e-mail (de ales, UE) | De stabilit | — | — |
| 11 | Notificări 🕓 | Memento-uri | Părinți | Token dispozitiv | Consimțământ | Google FCM / Apple APNs | Posibil | Până la dezactivare | — |

**Prelucrări doar pe dispozitiv (nu ajung la operator):** setările locale, abțibildurile, stelele,
peștii din acvariu (desene), fotografia fișei de colorat (analizată pe loc și aruncată), sesiunile
nesincronizate. Operatorul nu are acces la ele.

**Vocea aplicației:** generată o singură dată, la construirea aplicației, din texte fixe ale jocurilor
(Microsoft edge-tts / Azure Speech). Nu se trimit date ale utilizatorilor.
