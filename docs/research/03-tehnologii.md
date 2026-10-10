# 03 · Tehnologiile: ce am ales, ce am respins, ce am scos pe drum

*Capitol de cercetare pentru teză (README §23). Starea din sesiunea a unsprezecea (11.10.2026). ADR-uri legate: 001, 003, 006, 007, 008, 009, 013, 016, 028.*

## 1. Criteriile

Pentru fiecare alegere am cântărit aceleași cinci criterii, în această ordine:

1. **Copilul** — aspect identic pe orice dispozitiv (predictibilitate, TSA), animații fluide, funcționare offline.
2. **Datele copilului** — unde ajung, câți furnizori le ating, cât control avem.
3. **Un singur dezvoltator** — câte limbaje, câte piese de operat, cât de ușor de testat.
4. **Maturitate** — documentație, comunitate, întreținere pe termen lung.
5. **Cost** — zero pentru licențe; un VPS pentru găzduire.

## 2. Aplicațiile (client)

### 2.1 Flutter pentru aplicația copilului și pentru panou (ADR-001, ADR-013)

| Alternativă | De ce nu |
|---|---|
| React Native | Componente native → diferențe vizuale între Android și iOS; animațiile procedurale complexe (acvariul, mascota pe straturi) sunt mai costisitoare peste punte. |
| Kotlin Multiplatform / Compose MP | iOS și desktop mai puțin mature; ecosistem mic pentru jocuri 2D. |
| Unity | Excelent pentru 3D, slab pentru „aplicație”: formulare, setări, accesibilitate (TalkBack/VoiceOver), poarta pentru adulți; build-uri mari; licențiere. |
| Nativ (Swift + Kotlin) | De două ori codul pentru un singur dezvoltator. |
| Electron (prototipul) | Doar desktop, ~170 MB, fără mobil — copiii folosesc tablete. |

Flutter desenează singur fiecare pixel (Impeller/Skia), deci **ecranul arată identic** pe orice tabletă — o cerință clinică, nu estetică. Panoul adulților e tot Flutter (web): refolosește modelele și **aceeași implementare a KPI-urilor** din `licurici_core`, deci un procent din panou e calculat exact ca pe tabletă. Costul asumat: un pachet web inițial mai mare (~2 MB), acceptabil pentru un panou autentificat fără nevoie de SEO.

### 2.2 Nucleul în Dart pur, fără dependențe

`packages/licurici_core` (~15 000 de linii: dificultate, 89 de generatoare de jocuri, sesiune, rapoarte, Elo, scanarea fișei de hârtie, simularea acvariului) are **zero dependențe la rulare** — doar `test` și `lints` pentru dezvoltare. Consecințe:
- rulează identic pe tabletă, în panou (web), în teste și în unelte de linie de comandă (`tool/sync_fixture.dart`, `tool/bench_progress.dart`);
- 506 teste în ~20 de secunde, fără emulator;
- nicio actualizare de bibliotecă nu poate strica logica clinică.

Chiar și scanarea fișei de colorat (prag adaptiv, componente conexe, omografie) e scrisă de la zero în Dart (ADR-030), în loc de OpenCV: ~470 de linii testate cu fotografii sintetice, față de o dependență nativă de zeci de MB.

### 2.3 Starea și navigarea: Riverpod + go_router (ADR-003)

| Alternativă | De ce nu |
|---|---|
| BLoC | Mult cod repetitiv pentru zeci de jocuri mici. |
| Provider | Predecesorul Riverpod; dependent de `BuildContext`. |
| GetX | Stare globală „magică”, greu de testat și de argumentat. |

Riverpod permite înlocuirea oricărui serviciu în teste (stocarea sesiunilor în memorie în loc de SQLite, serverul simulat în testul cap-coadă).

### 2.4 Stocarea locală: Drift (SQLite) (ADR-004)

SQLite e baza de date cea mai testată din lume și există pe orice platformă; Drift adaugă interogări verificate la compilare și fluxuri reactive. Alternativele — Hive / Isar (NoSQL, întreținere incertă în 2025–2026), `shared_preferences` (nu e o bază de date) — nu ofereau tranzacții și interogări pentru outbox. Refresh tokenul stă separat, în stocarea securizată a sistemului (`flutter_secure_storage`: Keystore / Keychain / DPAPI).

### 2.5 Ce am scos pe drum (și de ce)

Planul inițial (README §6) avea mai multe biblioteci decât folosim. Fiecare eliminare e o decizie:

| Planificat | Stare | Motiv |
|---|---|---|
| **Rive** (animații) | scos — ADR-028 | Animația procedurală din cod (straturi decupate din ilustrații + mișcare calculată) dă control total, zero fișiere binare de editat într-un instrument extern și funcționează identic pe web. |
| **Flame** (motor de joc) | nefolosit | Nici acvariul cu fizică nu a avut nevoie: `CustomPainter` + o simulare în Dart pur (`docs/research/acvariul-pesti-3d.md`). |
| Shadere (fragment) | scoase | Pe web ieșeau negre; înlocuite cu texturi generate din cod (caustice Voronoi). |
| `dio` + client OpenAPI generat | înlocuit cu `http` | ~10 rute folosite de tabletă; un client generat ar fi adus mai mult cod decât economisește. |
| `freezed` / `json_serializable` | nefolosite | Modelele din nucleu au `toJson`/`fromJson` scrise de mână, testate prin contractul cu serverul; fără generare de cod în nucleu. |
| `workmanager` (sincronizare în fundal) | amânat | Sesiunile pleacă în prim-plan, la momente naturale (finalul sesiunii, pornirea) — suficient pentru câteva sesiuni pe zi. |
| Firebase (FCM, Sign-In) | nefolosit | Un împuternicit în plus pentru date de copii; raportul pe e-mail și panoul live acoperă nevoia. |

**Lecția:** fiecare dependență eliminată e una mai puțin de actualizat, de declarat în formularele magazinelor („Siguranța datelor”) și de justificat în DPIA.

## 3. Serverul

### 3.1 NestJS pe Node.js (ADR-006)

| Alternativă | Pentru | De ce nu |
|---|---|---|
| ASP.NET Core / Spring Boot | Mature, rapide | Mai verbose pentru un proiect mic; cozile ar cere RabbitMQ. |
| Go | Performanță, un binar | DI, validare și OpenAPI de construit manual. |
| FastAPI / Django | Rapid de scris | Tipuri mai slabe; WebSocket mai puțin natural. |
| **Serverpod / Dart Frog** | Un singur limbaj cu Flutter | Ecosistem și comunitate mici; mai greu de argumentat pentru producție. |

NestJS a adus integrări oficiale pentru exact ce ne trebuia: BullMQ, Socket.IO, Swagger, health checks. Un cost neprevăzut: **NestJS 12 e ESM și nu se încarcă în Jest** — de aici decizia (bună, în retrospectivă) ca serviciile de domeniu să fie TypeScript simplu, fără decoratori, legate de Nest într-un singur fișier (`04-patternuri.md` §4.2).

### 3.2 PostgreSQL + Prisma (ADR-007)

Relațiile sunt reale (părinte → copii → sesiuni; specialist ↔ copil cu termen; acorduri; audit) și cer tranzacții ACID. Sesiunile se păstrează ca **JSONB** (jurnalul brut al încercărilor + faptele calculate), deci formatul încercărilor poate evolua fără migrări (ex. câmpul `level`, sesiunea 11).

| Alternativă | De ce nu |
|---|---|
| MongoDB | Rapoartele și regulile de acces relaționale devin greoaie. |
| MySQL | JSON mai slab, fără indexuri parțiale. |
| TypeORM / Drizzle | TypeORM — istoric de bug-uri; Drizzle — foarte bun, alternativă validă, mai tânăr la momentul deciziei. |

Prisma 7 rulează cu driverul `pg` (fără motorul nativ Rust), deci imaginea Docker e mai mică și pornirea mai rapidă.

### 3.3 Redis + BullMQ (ADR-008, ADR-009)

O singură piesă de infrastructură acoperă: refresh tokenuri (rotite, `GETDEL`), limite de încercări, cozi de job-uri, pub/sub pentru canalul live, lock-uri, semnul „se joacă acum”. Alternative: Postgres pentru tot (`SKIP LOCKED`, `LISTEN/NOTIFY`) — ar încărca baza tranzacțională cu trafic efemer; RabbitMQ / Kafka / NATS — vezi `02-comunicare.md` §2.3.

**Licența:** Redis 8 e AGPL/RSAL; **Valkey** (fork BSD) are același API — schimbarea e o linie în `docker-compose.yml` dacă distribuirea comercială o cere.

### 3.4 Alte alegeri de server

| Nevoie | Ales | Alternativa respinsă |
|---|---|---|
| Parole | Argon2id (`@node-rs/argon2`) | bcrypt — fără rezistență la atacuri pe GPU prin memorie |
| 2FA | TOTP scris de mână pe `node:crypto` (~75 de linii, testat pe vectorii RFC 6238) | `otplib` / `speakeasy` — o dependență pentru o funcție de 20 de linii |
| Validare | zod (scheme `.strict()`) | `class-validator` — decoratori, mai greu de folosit în afara Nest |
| Loguri | pino, cu filtru de confidențialitate | winston — mai lent, fără avantaje aici |
| E-mail | nodemailer pe SMTP (ADR-032) | SDK-ul unui furnizor — legare de furnizor; SMTP merge cu Mailpit local și cu Brevo în producție |
| AI | SDK-ul oficial Anthropic, pe fapte agregate (ADR-029) | Model local — calitate slabă în română, hardware dedicat |

## 4. Infrastructura

| Nevoie | Ales | Alternativa | De ce nu |
|---|---|---|---|
| Orchestrare | Docker Compose (ADR-014) | Kubernetes | Un VPS, un dezvoltator; K8s are sens peste ~3 noduri. |
| Proxy + TLS | Traefik v3 + Let's Encrypt (ADR-017) | nginx + certbot | Traefik descoperă containerele și reînnoiește certificatele singur. |
| Stocare obiecte | RustFS local, S3 în UE în producție (ADR-015) | MinIO | Imaginea MinIO nu mai e publicată (2025). |
| Backup | `pg_dump` zilnic criptat cu **age**, 35 de zile | backup necriptat la furnizor | Datele copiilor nu stau în clar nicăieri în afara bazei. |
| Voce | TTS neural **pre-generat** (Azure / edge-tts) → 2 503 clipuri MP3 în aplicație (ADR-016) | TTS pe dispozitiv | Voci românești inconsistente sau absente pe dispozitive; copilul are nevoie de aceeași voce clară de fiecare dată; funcționează offline. |

## 5. Rezumat pentru susținere (60 s)

*Criterii:* copilul (aspect identic, offline), datele lui (câți furnizori le ating), un singur dezvoltator. *Ales:* Flutter pentru tabletă și panou, cu un nucleu Dart pur, fără dependențe, partajat între ele; NestJS + PostgreSQL + Redis/BullMQ în Docker Compose. *Respins cu motiv:* Unity (slab pentru UI de aplicație), React Native (diferențe vizuale), Kafka/RabbitMQ (supradimensionate), Kubernetes (un singur server). *Scos pe drum:* Rive, Flame, shadere, clientul OpenAPI generat, Firebase — fiecare eliminare înseamnă o dependență mai puțin de actualizat și de declarat. *Când aș schimba:* Valkey pentru licență, Serverpod pentru un singur limbaj, Kubernetes peste trei servere.
