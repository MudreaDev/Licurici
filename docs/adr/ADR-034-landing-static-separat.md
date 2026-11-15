# ADR-034: Landing static, separat de aplicație și panou

Status: Acceptat pentru prezentare · Data: 2026-11-14

## Context
Este necesară o prezentare publică a aplicației și a proiectului universitar, accesibilă pe telefon. Cererea explicită este să lucrăm pe o ramură separată și să publicăm pe Vercel fără modificări pe `main`/`master` sau asupra panoului existent.

## Decizie
HTML semantic, CSS responsiv și JavaScript nativ în `deploy/landing/`, cu Splide pentru carusel (ADR-035), fără server, formulare sau analytics. Fonturile Nunito și mascota sunt cele existente. Capturile sunt produse de Flutter, nu reconstruite. O ilustrație nouă este decorativă, fără reprezentarea inventată a interfeței.

Publicare în proiectul Vercel separat `licurici-prezentare`, din ramura `codex/landing-prezentare`. Proiectul `licurici-panou`, ramura sa de producție și infrastructura aplicației rămân independente. Publicarea se face explicit din commitul verificat, cu rădăcina `deploy/landing`.

## Argumente și alternative
- Pagina este informativă; HTML oferă încărcare rapidă, conținut indexabil și accesibilitate fără runtime Flutter.
- Flutter Web ar reutiliza tehnologia aplicației, dar ar încărca motorul pentru o pagină de prezentare.
- Un framework web suplimentar ar introduce dependențe și întreținere fără funcționalitate necesară.
- Integrarea în panoul existent ar amesteca prezentarea publică și produsul și ar încălca izolarea cerută.

## Consecințe
Conținutul academic se editează în `index.html`. Titlul oficial al tezei necesită confirmare; coordonatorul Mihail Musteață este confirmat explicit de utilizator. „Licență” urmează corecția explicită a utilizatorului din 14.11. Sliderul automat are pauză, oprire în afara ecranului și respectă reducerea mișcării. Nu se adaugă date despre copil. Nu se afirmă validarea clinică sau lansarea în magazine.
