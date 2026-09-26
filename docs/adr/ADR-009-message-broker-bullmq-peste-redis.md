# ADR-009: Message broker: BullMQ peste Redis

Status: Acceptat · Data: 2026-09-26

## Context
API-ul trebuie să delege munca grea (statistici, e-mail, exporturi) unui proces separat, cu retry și programare.

## Decizie
**BullMQ** (cozi de job-uri peste Redis Streams/liste) pentru comunicarea asincronă API → worker.

## De ce
avem nevoie de **job queue** (task-uri cu retry, backoff exponențial, prioritate, întârziere, job-uri programate, dead-letter), nu de un bus de evenimente pentru zeci de servicii; refolosește Redis (deja cerut); dashboard de monitorizare (Bull Board); integrare oficială NestJS.

## Alternative
RabbitMQ; Apache Kafka; NATS / JetStream; Redis Streams „brut”; Postgres (pg-boss).

## De ce nu
RabbitMQ — rutare puternică (exchanges, topic), dar încă o componentă de operat pentru un singur consumator; Kafka — log distribuit pentru debit foarte mare și event sourcing, supradimensionat (ZooKeeper/KRaft, partiții) pentru câteva mii de evenimente/zi; NATS — excelent pentru microservicii, dar semantica de job (retry/backoff/programare) trebuie construită; Redis Streams brut — reinventăm ce oferă BullMQ; pg-boss — bun, dar încarcă Postgres.

## Când am alege altfel
RabbitMQ când apar consumatori în alte limbaje sau rutare complexă; Kafka când trebuie reluat istoricul evenimentelor (event sourcing, analytics la scară); NATS în arhitectură de microservicii.

## Cozi definite
`stats` (recalcul statistici), `mail` (e-mailuri), `reports` (raport săptămânal, cron), `gdpr` (export/ștergere), `content` (construire pachete), `push` (notificări părinți).
