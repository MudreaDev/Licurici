# ADR-007: PostgreSQL (+ Prisma)

Status: Acceptat · Data: 2026-09-26

## Context
Datele sunt relaționale (părinte → copii → sesiuni → evenimente), cu nevoi de tranzacții (consimțământ + profil) și agregări pentru statistici.

## Decizie
PostgreSQL 17; ORM Prisma 7 (driver `pg` prin `@prisma/adapter-pg`, fără motor nativ) cu migrări SQL versionate în `backend/prisma/migrations/`. Am ales Prisma 7.10 stabil, nu 8.0-rc.

## De ce
date relaționale clare (părinte → copii → sesiuni → evenimente); tranzacții ACID (consimțământ + creare profil); **JSONB** pentru payload-ul variabil al evenimentelor de joc; indexuri parțiale, partiționare pe timp pentru `game_events`; `pgcrypto` pentru criptare la nivel de coloană.

## Alternative
MongoDB; MySQL/MariaDB; SQLite pe server; ORM-uri: TypeORM, Drizzle, MikroORM.

## De ce nu
MongoDB — relațiile și rapoartele agregate devin greoaie, tranzacțiile multi-document sunt adăugate târziu; MySQL — JSON mai slab, fără indexuri parțiale; SQLite server — un singur scriitor. TypeORM — bug-uri istorice, tipare slabe; Drizzle — foarte bun, dar mai tânăr (alternativă validă).

## Când am alege altfel
Mongo pentru conținut foarte eterogen fără relații; TimescaleDB (extensie Postgres) dacă evenimentele cresc la sute de milioane.
