# ADR-014: Docker Compose (nu Kubernetes)

Status: Acceptat · Data: 2026-09-26

## Context
Coordonatorul cere Docker; mediul trebuie să pornească identic pe orice calculator și pe server.

## Decizie
Docker pentru toate serviciile; Compose pentru dev și prod (un VPS).

## De ce
mediu reproductibil („la mine merge” dispare), onboarding cu o comandă, paritate dev/prod, imagini multi-stage mici (Node alpine/distroless).

## Alternative
Kubernetes (k3s); PaaS (Render, Fly.io, Railway); instalare directă pe VM.

## De ce nu
K8s — supradimensionat pentru un nod; PaaS — cost, date în afara controlului; instalare directă — nereproductibil.

## Când am alege altfel
k3s/K8s când avem nevoie de auto-scalare pe mai multe noduri sau zero-downtime la scară.
