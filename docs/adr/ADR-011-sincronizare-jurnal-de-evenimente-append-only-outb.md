# ADR-011: Sincronizare: jurnal de evenimente append-only + Outbox + Idempotency Key

Status: Acceptat · Data: 2026-09-26

## Context
Aplicația merge offline; rezultatele trebuie trimise mai târziu fără pierderi și fără dubluri, chiar și cu rețea instabilă.

## Decizie
rezultatele de joc sunt **evenimente imuabile** (UUIDv7 generat pe client) → nu există conflicte de scriere. Setările/profilul → *last-write-wins* pe câmp cu `updatedAt`.

## De ce
cel mai simplu model corect pentru offline; reîncercările sunt sigure (serverul ignoră ID-urile deja primite); UUIDv7 e ordonabil în timp → indexuri eficiente.

## Alternative
CRDT-uri; sincronizare de stare completă (snapshot); soluții gata (PowerSync, ElectricSQL, Firebase).

## De ce nu
CRDT — util pentru editare colaborativă, aici nu există editare concurentă a aceluiași obiect; snapshot — pierde istoricul, trafic mare; soluții gata — dependență externă, locația datelor.

## Când am alege altfel
CRDT dacă părintele și terapeutul ar edita simultan același plan de lucru.
