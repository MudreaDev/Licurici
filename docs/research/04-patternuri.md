# 04 · Pattern-uri de proiectare: unde, de ce, ce costă

*Capitol de cercetare pentru teză (README §23). Starea din sesiunea a unsprezecea (11.10.2026).*

Fiecare pattern de mai jos are: **problema** concretă din Licurici, **unde** e aplicat (fișierul), **ce s-ar fi întâmplat fără el** și **costul**. La final, pattern-urile din planul inițial (README §9) care **nu** au fost implementate, cu motivul — un pattern nefolosit e o decizie, nu o omisiune.

## 1. Date și sincronizare

### 1.1 Transactional Outbox (pe tabletă)
- **Problema:** sesiunea trebuie să ajungă pe server o singură dată, chiar dacă aplicația e închisă sau rețeaua cade în timpul trimiterii.
- **Unde:** tabela `sessions` din Drift are coloana `synced` (`apps/child_app/lib/data/local_db.dart`). Salvarea sesiunii și „de trimis” sunt **aceeași scriere** — nu există o coadă separată care să poată rămâne nesincronizată cu datele. `markSynced` se apelează abia după răspunsul 2xx; o sesiune modificată după trimitere își resetează `synced` și se retrimite.
- **Fără el:** trimiterea directă la finalul sesiunii ar pierde sesiunea la prima cădere de rețea; o coadă separată ar putea diverge de date.
- **Cost:** o coloană și o interogare `unsyncedIds()`.

### 1.2 Idempotency Key (cheia naturală)
- **Problema:** retrimiterea după un timeout nu trebuie să dubleze sesiunea.
- **Unde:** `SyncService.push` → `upsert` după id-ul sesiunii (UUID v4 generat pe tabletă, `SessionRecorder._newId`). Job-urile BullMQ cu efecte unice au `jobId` derivat din date: `purge-account-{userId}`, `weekly-{userId}-{săptămână}`.
- **Fără el:** fiecare retry ar crea un rând nou — rapoarte umflate, KPI greșite.
- **Cost:** id-ul trebuie generat pe client (nu de baza de date). Varianta „cheie separată + răspuns salvat în Redis” din plan a fost respinsă: sesiunea e imuabilă, deci cheia naturală ajunge (`02-comunicare.md` §3.1).

### 1.3 Repository
- **Problema:** logica de domeniu nu trebuie să știe de Prisma, Drift sau HTTP — și trebuie testată fără ele.
- **Unde:** server — interfețe în fiecare modul (`SessionRepo`, `PlanRepo`, `SharingRepo`, `SkillStatsRepo`…), o singură implementare Prisma (`data/repos.ts`, „singurul loc care știe de tabele”); tabletă — `SessionStore` cu `DriftSessionStore` și `MemorySessionStore`.
- **Fără el:** testele backend-ului ar cere Postgres (care nu rulează încă pe mașina de dezvoltare — fără Docker). Cu el: 84 de teste rulează în ~20 s, fără nicio bază de date.
- **Cost:** o interfață în plus per modul; tentația unor interfețe prea generice (evitată: fiecare repo are doar metodele de care are nevoie serviciul lui).

### 1.4 CQRS-lite (read model)
- **Problema:** panoul specialistului vrea statistici pe trepte, fără să agrege mii de încercări la fiecare deschidere.
- **Unde:** scrierea în `therapy_sessions` (sincronizare) → job `stats/recompute` → `child_skill_stats` → `GET /children/:id/skills` (`stats/`).
- **Detaliu:** recalculul e **integral**, nu incremental — un retry sau o sesiune retrimisă dau același rezultat (idempotent). Deduplicarea BullMQ (`keepLastIfActive`) garantează cel mult un job în așteptare per copil.
- **Fără el:** agregare la fiecare cerere — acceptabil azi (zeci de sesiuni), problematic la 24 de luni de date.
- **Cost:** consistență eventuală (statisticile pot întârzia câteva secunde după sincronizare); o tabelă de întreținut.

### 1.5 Unit of Work (tranzacții)
- **Unde:** `prisma.$transaction` la înlocuirea statisticilor (șterge + scrie), la ștergerea definitivă a contului (arhivarea consimțămintelor, apoi ștergerea — `gdpr.processor.ts`).
- **Fără el:** un cititor ar putea vedea statisticile goale între ștergere și scriere; un cont ar putea fi șters fără dovada consimțămintelor.

### 1.6 Last-Write-Wins (registru)
- **Problema:** planul de jocuri al copilului poate fi schimbat și pe tabletă, și în panou (de părinte sau de specialist).
- **Unde:** `children/plan.ts` + `data/sync.dart`: fiecare parte păstrează data ultimei schimbări (`updatedAt` / `hiddenGamesAt`), câștigă cea mai nouă; istoricul schimbărilor e în `audit_log`.
- **De ce nu CRDT:** planul e o mulțime mică, schimbată rar, de doi-trei adulți; un conflict real (două schimbări în aceeași secundă) e improbabil, iar pierderea uneia e vizibilă și reversibilă.

## 2. Comportament

### 2.1 Strategy
- **Mecanicile de joc** — peste 20 de mecanici cu ecrane proprii (alegere, reacție, secvență, sortare, labirint…), cu aceeași interfață spre sesiune: produc încercări (`Trial`) prin `SessionRecorder`.
- **Strategia de ajutor** — `promptStrategyFor(gameId, istoric)` alege *most-to-least* (treaptă nouă) sau *least-to-most* (treaptă cunoscută) (`trial.dart`).
- **Furnizori** — `MailProvider` (SMTP azi), `Summarizer` / `Asker` (Claude sau nimic).
- **Fără el:** `if`-uri pe tipul jocului în ecranul de sesiune, în raport și în sincronizare.

### 2.2 Template Method
- **Unde:** `GameSpec.build(ctx) = scaleLesson(generate(ctx), …)` (`game.dart`): fiecare joc cu alegere scrie doar `generate` (generos: multe runde, multe variante); motorul comun taie după dificultate, păstrând mereu răspunsul corect. Port direct din `engine.js` al prototipului.
- **De ce contează clinic:** toate jocurile au aceeași structură previzibilă (instrucțiune → runde → final), un principiu TEACCH.

### 2.3 Registry
- **Unde:** `catalog.dart` (`catalogEntry(id)`) — fiecare joc e o intrare cu id, arie, trepte, mecanică, rută; ecranul principal, harta, „Drumul de azi”, planul specialistului și testele de accesibilitate se construiesc din catalog.
- **Fără el:** un joc nou ar cere modificări în 5–6 locuri; testul „toate jocurile pe telefonul mic și pe tabletă” n-ar putea itera automat peste toate.

### 2.4 Null Object (degradare elegantă)
- **Unde:** `SummaryFlow` primește `Summarizer | null`; fără `ANTHROPIC_API_KEY`, rezumatul rămâne cel din reguli (calculat pe tabletă). Sentry, SMTP: aceeași idee — absența configurării dezactivează funcția, nu pornirea.
- **Fără el:** dezvoltarea locală ar cere chei externe; o cădere a furnizorului AI ar strica panoul.

### 2.5 Observer (fluxuri reactive)
- **Unde:** Riverpod în ambele aplicații Flutter — „Drumul de azi” se recalculează când se schimbă dispoziția copilului sau sesiunile salvate (`stepProgressProvider` invalidat la finalul sesiunii); canalul live Socket.IO pentru panou.

### 2.6 Generator determinist (seed)
- **Problema:** niveluri generate procedural (ADR-027), dar reproductibile — pentru teste, pentru depanare și pentru „aceeași zi → același drum”.
- **Unde:** fiecare generator primește un `Random(seed)`; seed-ul se salvează în încercare (`Trial.seed`). „Imaginile de evitat” regenerează nivelul cu alt seed, determinist (`generateAvoiding`).
- **Fără el:** testele cu niveluri aleatoare ar fi instabile; o problemă raportată de un părinte n-ar putea fi reprodusă.

## 3. Concurență și reziliență

### 3.1 Distributed Lock (cu eliberare sigură)
- **Unde:** `stats.processor.ts` — `SET lock:stats:{copil} {proprietar} NX PX 30000`, eliberat cu un script Lua *compare-and-delete* (șterge doar dacă încă îl deține același job).
- **De ce compare-and-delete:** dacă un job depășește 30 s, lock-ul expiră și îl ia altul; un `DEL` simplu la final ar șterge lock-ul celuilalt.
- **Dacă e ocupat:** job-ul eșuează intenționat și e reîncercat cu backoff — nu e sărit (ar pierde sesiunile noi).

### 3.2 Retry cu backoff exponențial
- **Unde:** toate cozile (`defaultJobOptions`: 5 încercări, 1 → 16 s). Job-urile sunt idempotente (§1.2, §1.4), deci retry-ul e sigur.

### 3.3 Rate Limiter (fereastră fixă în Redis)
- **Unde:** autentificarea — blocare 15 minute după 5 parole greșite (`AuthService`, cheia = hash-ul e-mailului, aplicată și adreselor fără cont, ca să nu dezvăluie cine e înscris); e-mailurile — cel mult 3 pe oră per adresă (`email-flows.ts`); AI — limită zilnică de rezumate per adult (`ai-summary:{utilizator}:{zi}`).
- **De ce fereastră fixă (INCR + EXPIRE) și nu token bucket:** pentru praguri mici (5, 3) diferența de precizie nu contează, iar două comenzi Redis sunt ușor de testat.

### 3.4 Rotirea tokenurilor cu detectarea reutilizării
- **Unde:** `auth/tokens.ts` — refresh tokenul e opac, păstrat ca hash în Redis și consumat cu `GETDEL` (atomic: un token folosit de două ori e refuzat a doua oară). O „generație” per utilizator invalidează **toate** sesiunile deodată (parolă nouă, cont șters) fără să le enumere.
- **Consecința pe client:** apelurile tabletei sunt serializate (`AutoSync._serial`) — două apeluri paralele ar folosi același token.

### 3.5 Soft delete + purge programat
- **Unde:** ștergerea copilului sau a contului: acces tăiat imediat (`deletedAt`), ștergere definitivă după 7 zile prin job întârziat (`gdpr`), cu `jobId` unic (idempotent).
- **De ce:** anularea unei greșeli (un părinte care apasă din greșeală) fără să încălcăm termenul GDPR de o lună (art. 12(3)).

## 4. Structurale

### 4.1 Adapter
- `MailProvider` ← nodemailer; `RedisIoAdapter` ← Socket.IO + Redis; `PrismaRepos` ← Prisma. Domeniul vede interfețe mici, nu bibliotecile.

### 4.2 Dependency Injection — cablat de mână
- **Unde:** `api/api.module.ts` — serviciile de domeniu sunt clase TypeScript simple, construite cu `useFactory`; Nest doar le leagă.
- **De ce nu decoratori Nest în domeniu:** testele ar cere containerul Nest; mai mult, NestJS 12 e ESM și nu se încarcă în Jest. Costul: un fișier de cablaj de ~180 de linii care trebuie ținut la zi (testul de pornire a API-ului îl verifică).

## 5. Din plan, dar neimplementate (decizii)

| Pattern (README §9) | De ce nu |
|---|---|
| Outbox pe server (tabelă → job) | Singurele job-uri care pornesc din cereri (statistici, e-mail) sunt fie recalculabile, fie reîncercabile de utilizator; o pierdere rară nu strică date. Ar deveni necesar pentru notificări care *trebuie* să ajungă (ex. facturare). |
| Circuit Breaker | Apelurile externe sunt în worker, unde retry + backoff fac același lucru; singurul apel extern din cerere (Claude) are rezervă din reguli. |
| Cache-aside (catalog, statistici) | Catalogul e în aplicație (nu pe server); statisticile au read model. Cheia `cache:stats` e ștearsă la recalcul, pregătită pentru când un cache va fi necesar. |
| Feature flags | Un singur mediu de producție, un dezvoltator; planul de jocuri per copil acoperă „activăm treptat” pentru jocuri. |
| Evenimente interne (`event-emitter`) | Interfețe injectate (`LiveEvents`, `StatsQueue`) — dependențele rămân vizibile în constructor. |

## 6. Rezumat pentru susținere (60 s)

*Problema:* date de copii trimise de pe o tabletă des offline, prelucrate asincron, citite de doi tipuri de adulți. *Pattern-urile care duc greul:* Outbox + cheie naturală de idempotență (nimic pierdut, nimic dublat), Repository (84 de teste backend fără bază de date), Strategy + Template Method + Registry (89 de jocuri cu aceeași structură previzibilă), lock distribuit cu compare-and-delete și job-uri idempotente (worker-e multiple în siguranță), rotirea tokenurilor cu GETDEL. *Ce n-am folosit:* circuit breaker, feature flags, outbox pe server — fiecare are o condiție clară în care l-am adăuga. *Verificat* prin testele de idempotență, de acces și de pornire.
