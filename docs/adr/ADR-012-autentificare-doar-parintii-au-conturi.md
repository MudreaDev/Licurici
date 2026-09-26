# ADR-012: Autentificare: doar părinții au conturi

Status: Acceptat · Data: 2026-09-26

## Context
Utilizatorii sunt copii sub 14 ani: consimțământul îl dă părintele (Legea 195/2024), iar datele copilului trebuie minimizate.

## Decizie
conturile sunt ale **adulților** (e-mail + parolă Argon2id, sau Google/Apple Sign-In). Copilul are un **profil** (poreclă + avatar), fără credențiale, fără e-mail. Access token JWT scurt (15 min) + refresh token opac, rotit, stocat în Redis (revocare imediată). **Poartă parentală** în aplicație (ex. „ține apăsat 3 s” + întrebare pentru adulți) pentru zona de setări/cont.

## De ce
minimizarea datelor copilului (GDPR art. 5, 8, 25); consimțământul trebuie dat de părinte sub 14 ani (Legea 195/2024); cerințele Google Play Families și Apple Kids (poartă parentală înainte de link-uri externe/cumpărături).

## Alternative
conturi pentru copii; sesiuni server clasice (cookie); Auth-as-a-service (Auth0, Firebase Auth, Keycloak).

## De ce nu
conturi copii — date în plus fără beneficiu; sesiuni cookie — mai puțin potrivite pentru aplicația mobilă; Auth0/Firebase — date în SUA, cost; Keycloak — foarte bun dar greu (JVM, configurare) pentru un proiect mic.

## Când am alege altfel
Keycloak dacă apar instituții (grădinițe) cu SSO propriu.
