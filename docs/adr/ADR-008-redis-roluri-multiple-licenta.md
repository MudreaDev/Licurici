# ADR-008: Redis: roluri multiple, licență

Status: Acceptat · Data: 2026-09-26

## Context
Coordonatorul cere Redis; avem nevoie de cache, sesiuni, rate limiting, cozi, pub/sub și lock-uri distribuite.

## Decizie
Redis 8 (sau **Valkey**, fork BSD compatibil) pentru: cache, sesiuni/refresh tokens, rate limiting, cozi (BullMQ), pub/sub (WebSocket), lock-uri, idempotență. Detalii în §10.

## De ce
în memorie → latență sub-milisecundă; structuri de date bogate (hash, sorted set, streams); o singură piesă de infrastructură acoperă 6 nevoi → mai puține componente de operat.

## Alternative
Memcached; cache în proces (LRU); Postgres pentru tot (LISTEN/NOTIFY, `SKIP LOCKED` pentru cozi); KeyDB/Dragonfly.

## De ce nu
Memcached — doar cheie-valoare, fără persistență, fără pub/sub/streams; cache în proces — nu se partajează între instanțe; Postgres-pentru-tot — funcționează la scară mică, dar încarcă baza tranzacțională cu trafic efemer; Dragonfly — licență BSL.

## Când am alege altfel
Postgres-only pentru un MVP minimal; Valkey dacă licența AGPL/RSAL a Redis 8 e o problemă pentru distribuire comercială (API-ul e identic → schimbare de imagine Docker).
