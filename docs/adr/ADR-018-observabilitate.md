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
