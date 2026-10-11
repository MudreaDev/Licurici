# ADR-018: Observabilitate

Status: Acceptat · Data: 2026-09-26

## Context
Trebuie să aflăm despre erori și încetiniri fără a loga date personale.

## Decizie
loguri JSON structurate (pino) cu `requestId`, **fără PII**; Sentry (regiune UE, scrubbing PII) pentru erori; endpoint `/health` (liveness/readiness pentru Postgres, Redis, MinIO); Bull Board pentru cozi; opțional Prometheus + Grafana (metrici HTTP, lungimea cozilor).

## Alternative
ELK/Loki stack complet; OpenTelemetry + Jaeger; nimic.

## Când am alege altfel
OpenTelemetry + tracing distribuit dacă trecem la microservicii.

## Actualizare (11.10.2026) — metricile Prometheus implementate
- `prom-client` în API: `GET /metrics` (în afara prefixului `/api/v1`), doar cu `Authorization: Bearer <METRICS_TOKEN>`; fără token configurat, ruta răspunde 404. În producție Traefik nu rutează `/metrics` deloc.
- Metrici: `licurici_http_request_duration_seconds` (metodă, **rută-șablon** — niciodată id-uri —, clasa codului), `licurici_synced_sessions_total`, `licurici_queue_jobs` (coadă × stare, citit la colectare, cu termen de 1 s ca un Redis căzut să nu blocheze colectarea), plus metricile implicite ale procesului.
- Prometheus + Grafana (cu panou gata făcut) în `docker-compose.prod.yml`, profilul `monitoring`, opțional; Grafana doar pe `127.0.0.1`. Detalii: [docs/operare.md](../operare.md).
- De ce nu OpenTelemetry acum: un singur serviciu, fără nevoie de tracing distribuit; `prom-client` e o dependență mică, fără agent. Rămâne alegerea dacă trecem la mai multe servicii.
