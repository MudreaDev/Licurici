# ADR-006: NestJS (TypeScript) pentru backend

Status: Acceptat · Data: 2026-09-26

## Context
Backend-ul are nevoie de module clare, cozi (BullMQ), WebSocket, OpenAPI, validare și testare ușoară.

## Decizie
NestJS pe Node.js 24 LTS.

## De ce
arhitectură modulară din fabrică (module, DI, guards, interceptors, pipes) — se potrivește cu ADR-05; suport oficial pentru BullMQ, WebSocket (Socket.IO), OpenAPI (`@nestjs/swagger`), Redis, microservicii (dacă vreodată); TypeScript = tipuri stricte; I/O asincron potrivit pentru sync/WebSocket.

## Alternative
ASP.NET Core (C#); Spring Boot (Java/Kotlin); Go (Gin/Fiber); FastAPI/Django (Python); Dart pe server (Serverpod, Dart Frog).

## De ce nu
ASP.NET/Spring — excelente, dar mai verbose pentru un proiect mic și ecosistem de cozi mai greu (ar cere RabbitMQ); Go — performanță mare dar framework-uri minimaliste (DI, validare, OpenAPI de făcut manual); Python — tipare mai slabe, concurență mai puțin naturală pentru WebSocket; Dart server — un singur limbaj (plus mare), dar ecosistem mic, comunitate mică, mai greu de argumentat pentru producție.

## Când am alege altfel
Serverpod dacă vrem să partajăm modelele Dart 1:1 cu Flutter; Go dacă latența/costul pe request devin critice; .NET/Spring în medii enterprise existente.
