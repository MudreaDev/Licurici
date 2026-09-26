# ADR-005: Monolit modular + worker (nu microservicii)

Status: Acceptat · Data: 2026-09-26

## Context
Un dezvoltator, un domeniu mic, termen scurt (70% în semestrul 1), dar cerințe de cozi, timp real și job-uri grele (rapoarte, exporturi GDPR).

## Decizie
un singur proiect NestJS (`backend/`) împărțit în **module cu granițe clare** (auth, children, sync, stats, gdpr, content, live), cu **două puncte de intrare**: `main.ts` (API) și `worker.ts` (consumă cozile). O singură imagine Docker, două containere.

## De ce
o echipă de 1 persoană, domeniu mic; o singură bază de date tranzacțională; deploy simplu; modulele comunică prin interfețe/evenimente interne → pot fi extrase ulterior. Worker-ul separat izolează munca grea (rapoarte, exporturi, e-mail) de latența API-ului și scalează independent (`docker compose up --scale worker=3`).

## Alternative
microservicii (auth-service, stats-service…) cu API gateway; serverless (Lambda/Cloud Functions); BaaS (Firebase/Supabase).

## De ce nu
microservicii — complexitate operațională (N deploy-uri, tracing distribuit, consistență eventuală, date duplicate) fără beneficiu la această scară; serverless — cold starts, WebSocket dificil, vendor lock-in, greu de rulat local în Docker; BaaS — control redus asupra datelor copiilor, locația datelor.

## Când am alege altfel
microservicii când echipe diferite dețin domenii diferite sau o componentă are profil de încărcare radical diferit (ex. un serviciu de recunoaștere vocală cu GPU).
