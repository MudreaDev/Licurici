# ADR-010: Comunicare: REST + OpenAPI, WebSocket, cozi

Status: Acceptat · Data: 2026-09-26

## Context
Trei tipuri de clienți: aplicația copilului (sync în lot, offline), dashboard-ul web (citiri + timp real) și worker-ul (asincron). Detaliile fiecărui canal sunt în README §8.

## Decizie
- **REST + JSON, descris cu OpenAPI 3.1**, pentru aplicația copilului și dashboard. Clientul Dart se generează din specificație.
- **Sincronizare în lot** (`POST /sync/events`, până la 500 de evenimente, gzip, `Idempotency-Key`) pentru aplicația copilului.
- **WebSocket (Socket.IO)** doar pentru dashboard (sesiune live, notificări), cu adapterul Redis pentru mai multe instanțe de API.
- **Cozi BullMQ** între API și worker (asincron, at-least-once, job-uri idempotente).
- **Evenimente de domeniu în proces** (`@nestjs/event-emitter`) între modulele API-ului.

## De ce
- REST e simplu, cacheabil, ușor de testat cu curl/Postman și are generatoare de client pentru Dart.
- Clientul copilului face aproape numai scrieri în lot și citiri simple de stare, deci un API bogat în interogări nu aduce nimic.
- WebSocket numai acolo unde e nevoie de push: aplicația copilului nu ține conexiuni deschise, deci consumă mai puțină baterie și nimic nu depinde de rețea.

## Alternative
GraphQL; gRPC; Server-Sent Events (SSE); long polling; WebSocket pentru tot.

## De ce nu
- **GraphQL:** adaugă complexitate (N+1, caching la nivel de câmp, autorizare pe resolver) fără beneficiu pentru un client care face sync în lot.
- **gRPC:** suport slab în browser (necesită gRPC-Web + proxy), debugging mai greu; aduce valoare între servicii interne, pe care nu le avem (ADR-05).
- **SSE:** e suficient pentru push într-o singură direcție, dar sesiunea live are nevoie și de mesaje de la dashboard; Socket.IO oferă și reconectare și camere (`child:{id}`).
- **Long polling:** latență și trafic inutil.
- **WebSocket pentru tot:** stare pe conexiune, greu de făcut cache, iar o conexiune permanentă pe tableta copilului nu aduce nimic.

## Când am alege altfel
- GraphQL dacă dashboard-ul ar avea multe ecrane cu nevoi de date foarte diferite.
- gRPC dacă sistemul s-ar sparge în microservicii cu latență critică între ele.
- SSE dacă sesiunea live ar deveni strict unidirecțională.
