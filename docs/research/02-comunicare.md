# 02 · Comunicarea: REST, WebSocket, cozi și garanțiile de livrare

*Capitol de cercetare pentru teză (README §23). Starea din sesiunea a unsprezecea (11.10.2026). ADR-uri legate: 009, 010, 011, 032.*

## 1. Cine vorbește cu cine

| Canal | Între | Tehnologie | Stil | Implementat în |
|---|---|---|---|---|
| Sincronizarea sesiunilor | tabletă → API | HTTPS, JSON, `POST /api/v1/children/:id/sessions` | sincron, în loturi, idempotent | `sync/sessions.ts`, `child_app/lib/data/sync.dart` |
| Planul de jocuri | tabletă ↔ API ↔ panou | `GET/PUT /children/:id/plan` | sincron, „ultimul câștigă” | `children/plan.ts` |
| Panoul adulților | browser → API | REST + JSON, OpenAPI (Swagger) | sincron | `api/controllers.ts` |
| Vești pentru panou | API → browser | Socket.IO pe `/api/v1/live`, doar WebSocket | asincron, push | `live/` |
| Între instanțele API | API ↔ API | Redis pub/sub (adapterul Socket.IO) | asincron | `live/redis-io.adapter.ts` |
| Muncă grea | API → worker | cozi BullMQ peste Redis (`mail`, `gdpr`, `reports`, `stats`) | asincron, *at-least-once* | `queues/`, `*.processor.ts` |
| Sarcini programate | worker | `upsertJobScheduler` (BullMQ) | cron | raportul de luni 08:00, retenția zilnică |
| E-mail | worker → releu SMTP | SMTP (nodemailer) | asincron, cu reîncercări | `mail/` (ADR-032) |
| AI (opțional) | API → Claude API | HTTPS | sincron, cu cache și limită zilnică | `reports/` (ADR-029) |

## 2. Alegerile și alternativele

### 2.1 Stilul API-ului: REST vs GraphQL vs gRPC

| | REST + JSON (ales) | GraphQL | gRPC |
|---|---|---|---|
| Clienți | Flutter (mobil + web), curl | la fel, cu client dedicat | web are nevoie de gRPC-Web + proxy |
| Cache HTTP / proxy | nativ | greu (un singur `POST /graphql`) | nu |
| Autorizare pe resursă | o regulă pe rută (`ChildAccess.assert`) | pe fiecare câmp/resolver — ușor de uitat una | pe metodă |
| Depanare | curl, Swagger | GraphiQL | unelte speciale |
| Când câștigă alternativa | — | multe ecrane cu nevoi de date foarte diferite, echipe frontend separate | servicii interne cu trafic mare și contracte stricte |

Avem ~30 de rute, două aplicații client scrise de aceeași persoană și o regulă de acces care trebuie aplicată **identic** peste tot (părinte / specialist cu legătură activă / nimeni altcineva — iar un copil străin dă 404, nu 403, ca să nu aflăm că există). REST face acea regulă vizibilă la fiecare rută. GraphQL ar fi mutat-o în resolvere, unde o scăpare expune date despre un copil.

### 2.2 Push către panou: WebSocket vs SSE vs polling

| | Socket.IO / WebSocket (ales) | Server-Sent Events | Polling (la 30 s) |
|---|---|---|---|
| Direcție | ambele | doar server → client | client → server |
| Reconectare | automată (Socket.IO) | automată (EventSource) | n/a |
| Abonare la copii anume | camere (`child:{id}`) + mesajul `watch` | câte o conexiune per filtru sau filtrare pe client | — |
| Mai multe instanțe API | adapterul Redis | pub/sub de scris de mână | gratuit |
| Cost la 100 de panouri deschise | 100 de conexiuni inactive | la fel | 200 cereri/minut, majoritatea fără noutăți |

Am ales Socket.IO pentru camere și adapterul Redis gata făcut. **SSE ar fi fost suficient** (traficul e doar server → client), iar dacă ar trebui scos Socket.IO (de exemplu pentru o dependență mai mică în panou), SSE e înlocuitorul natural. Polling-ul rămâne **plasa de siguranță**: panoul reîncarcă datele la deschidere, deci un eveniment pierdut nu lasă panoul greșit, doar întârziat.

Restricții deliberate pe canal:
- **doar `transports: ['websocket']`** — fără long-polling, deci fără sesiuni „lipicioase” în Traefik;
- autentificare la conectare cu tokenul de acces (JWT, 15 min); fără token valid, conexiunea se închide;
- `watch` aplică aceeași regulă de acces ca REST (`LiveAccess.canWatch`); un copil străin = `{ok: false}`, fără detalii;
- evenimentele conțin **doar id-uri și numere** (`session.synced {childId, count}`, `plan.changed {childId, by}`, `presence {childId, playing}`) — niciun conținut clinic nu trece pe canal; panoul îl cere apoi prin REST, cu autorizarea obișnuită.

**Aplicația copilului nu are canal live.** Copilul n-are cont (ADR-012), iar o conexiune permanentă de pe tableta copilului ar fi exact genul de flux de date pe care principiul „nimic fără acord” îl evită. „Se joacă acum” e un singur `POST /children/:id/presence`, cu acordul de sincronizare, care pune în Redis un semn cu termen de 20 de minute (`PRESENCE_TTL_SECONDS`) — dacă tableta pierde rețeaua, semnul se stinge singur.

### 2.3 Broker: BullMQ vs RabbitMQ vs Kafka vs NATS

Pe scurt (detalii în ADR-009): Redis există deja (tokenuri, limite, pub/sub), iar BullMQ adaugă peste el exact ce ne trebuie — reîncercări cu backoff, job-uri programate, întârzieri („șterge definitiv peste 7 zile”), un panou (Bull Board). RabbitMQ ar adăuga un al doilea sistem de operat pentru aceleași garanții; Kafka e un jurnal distribuit pentru volume cu câteva ordine de mărime peste ale noastre; NATS JetStream e elegant, dar nu are programare de job-uri și panou fără muncă în plus.

**Când am alege altfel:** RabbitMQ dacă alte limbaje/servicii ar consuma cozile (BullMQ e legat de Node); Kafka dacă am avea nevoie de reluarea istoricului de evenimente pentru analize (event sourcing real).

## 3. Garanțiile de livrare

Rețelele mobile pierd cereri, iar procesele cad. Fiecare canal are o garanție aleasă explicit:

| Canal | Garanție | Cum se obține | Ce se întâmplă la eșec |
|---|---|---|---|
| Sesiuni tabletă → server | **exact o dată efectiv** (at-least-once + idempotență) | sesiunea are un UUID generat pe tabletă; serverul face `upsert` după el; tableta marchează sesiunea trimisă **abia după** răspunsul 2xx | rămâne în outbox, pleacă la următoarea încercare (la „Gata pe azi” sau la pornire) |
| Plan de jocuri | **convergență** (last-write-wins) | fiecare scriere are `updatedAt`; tableta și serverul păstrează versiunea cu data mai nouă | o scriere concurentă mai veche pierde; istoricul schimbărilor rămâne în `audit_log` |
| Job-uri în worker | **at-least-once** | BullMQ: 5 încercări, backoff exponențial 1–16 s (`defaultJobOptions`) | după 5 eșecuri → lista *failed*, vizibilă în Bull Board (și în Sentry, dacă e configurat) |
| Vești live | **at-most-once** (cel mult o dată) | emitere simplă în cameră | pierdută; panoul reîncarcă la deschidere, deci starea rămâne corectă |
| E-mailuri | at-least-once, **idempotent unde contează** | raportul săptămânal are `jobId = weekly-{părinte}-{săptămână}`, deci BullMQ nu-l pune de două ori în coadă; tokenurile de confirmare/parolă sunt de unică folosință | un retry după o trimitere reușită ar putea dubla un e-mail de confirmare — acceptat (inofensiv) |

### 3.1 De ce idempotență și nu „exactly-once”

„Exact o dată” peste o rețea nesigură nu se poate garanta la nivel de transport (problema celor doi generali): dacă răspunsul se pierde, clientul nu știe dacă serverul a salvat. Singura soluție practică este ca **retrimiterea să fie inofensivă**. Pentru sesiuni, cheia de idempotență este chiar id-ul sesiunii (nu o cheie separată `Idempotency-Key` cum prevedea planul inițial din README §9): sesiunea e imuabilă după încheiere, deci același id înseamnă același conținut, iar un `upsert` e suficient. Nu e nevoie de un depozit de răspunsuri în Redis.

### 3.2 Job-uri idempotente — regula din cod

Fiecare procesor e scris astfel încât rularea de două ori să ducă la aceeași stare:

- **Ștergerea definitivă a copilului / contului** (`gdpr`): ștergerea a ceva deja șters nu face nimic; arhiva consimțămintelor se scrie înainte de ștergerea contului, iar un retry o rescrie identic.
- **Retenția** (`expire-sessions`, zilnic): o condiție pe dată, nu o listă de id-uri — oricâte rulări, același rezultat.
- **Raportul săptămânal**: job-ul de e-mail are id-ul `weekly-{părinte}-{săptămâna ISO}`; BullMQ refuză un al doilea job cu același id, deci o rulare repetată a programatorului nu dublează e-mailurile.
- **Statisticile** (`stats`): se recalculează **integral** din sesiuni, nu incremental; un lock Redis per copil (`SET NX PX 30000` + eliberare cu compare-and-delete în Lua) previne două recalculări simultane; dacă lock-ul e ocupat, job-ul eșuează intenționat și BullMQ îl reîncearcă (sărirea lui ar pierde sesiunile noi).

### 3.3 Ordinea apelurilor pe tabletă

Refresh tokenul se **rotește** la fiecare folosire (cel vechi devine invalid). Două apeluri simultane — de exemplu „Se joacă acum” la începutul sesiunii și trimiterea sesiunii anterioare — ar folosi același token, iar al doilea ar fi refuzat, ceea ce ar opri trimiterea automată. Soluția din `AutoSync`: o coadă locală (`_serial`) — apelurile către server merg strict unul după altul. E un exemplu mic, dar real, unde o garanție de securitate (rotirea, detectarea reutilizării) impune o constrângere de concurență pe client.

## 4. Formatul datelor și contractul

- **JSON** peste tot. Corpul sincronizării este `SessionRecord.toJson()` din `licurici_core` (Dart), validat pe server cu zod `.strict()`: orice câmp necunoscut e respins. Asta e și o măsură de confidențialitate — un câmp nou cu date despre copil nu poate „scăpa” pe server fără o schimbare explicită în schema serverului (și deci în README §11/§13, RoPA).
- **Testul de contract**: `licurici_core/tool/sync_fixture.dart` generează JSON-ul exact pe care îl trimite tableta; `sync.spec.ts` îl validează. O schimbare de format pe o parte rupe testul celeilalte.
- **Limitele** sunt în schemă: cel mult 200 de sesiuni pe lot (tableta trimite câte 50), 2000 de încercări pe sesiune, șiruri scurte pentru id-uri. O cerere mare sau malformată se oprește la validare, înainte de baza de date.
- **Erorile** au un singur format (`common/errors.ts` → `DomainErrorFilter`): 400 validare, 401 autentificare (`details: ['totp']` când trebuie codul 2FA), 403 lipsă de acord, 404 și pentru „nu ai acces”, 503 când Postgres sau Redis nu răspund (clientul reîncearcă).

## 5. Ce n-am făcut (încă) și de ce

| Din planul inițial (README §8) | Stare | Motiv |
|---|---|---|
| `Idempotency-Key` + răspuns salvat în Redis | înlocuit | id-ul sesiunii e cheia naturală (§3.1). |
| Backoff exponențial cu jitter pe tabletă | parțial | Tableta nu reîncearcă în buclă: încearcă la momente naturale (finalul sesiunii, pornirea). Pentru câteva sesiuni pe zi, asta e mai blând cu bateria și serverul decât un timer. Dacă apar mulți utilizatori sincronizați la aceeași oră, adăugăm jitter. |
| Circuit breaker pentru furnizori externi | nu | Apelurile externe sunt în worker (SMTP), unde reîncercările cu backoff ale BullMQ fac același lucru; apelul către Claude are rezervă: fără cheie sau la eroare, panoul rămâne pe rezumatul calculat din reguli. |
| Push către telefonul părintelui (FCM) | nu | Ar adăuga Google ca împuternicit. Raportul săptămânal pe e-mail și panoul live acoperă nevoia. |
| Evenimente interne de domeniu (`@nestjs/event-emitter`) | nu | Interfețe injectate (`LiveEvents`) — explicite și testabile (vezi `01-arhitectura.md` §6). |

## 6. Cum am verificat

| Garanție | Test |
|---|---|
| Idempotența sincronizării | `sync.spec.ts` — același lot trimis de două ori → același număr de sesiuni |
| Fără acord, nimic salvat | `sync.spec.ts` — 403 fără `SYNC` și după retragere |
| Autorizarea canalului live | `live.spec.ts` — token invalid → conexiune refuzată; copil străin → `watch` refuzat |
| Canalul live de la cap la coadă | `npm run test:smoke` — server Socket.IO real, client real, eveniment primit doar de cine are acces |
| Programarea job-urilor idempotentă | `retention.spec.ts`, `weekly.spec.ts` |
| Tableta → server, inclusiv marcarea „trimis” | `flow_test.dart` / `integration_test/flow.dart` — server HTTP local cu aceleași rute |
| **Neverificat încă** | redeliverarea reală a job-urilor după căderea worker-ului și adapterul Redis cu două instanțe API — cer Docker (README §0.0 A) |

## 7. Rezumat pentru susținere (60 s)

*Problema:* o tabletă care e des offline trimite date clinice; adulții vor să vadă noutățile fără să reîncarce. *Ales:* REST + JSON validat strict (contract testat între Dart și TypeScript), WebSocket doar spre panou, cozi BullMQ pentru munca grea. *Garanții:* sesiunile sunt at-least-once cu idempotență după id-ul sesiunii — deci efectiv o singură dată; job-urile sunt idempotente; veștile live pot fi pierdute fără consecințe. *Alternative:* GraphQL — autorizarea pe resolvere e mai ușor de greșit; SSE — ar fi mers, Socket.IO a câștigat prin camere și adapterul Redis; RabbitMQ — al doilea sistem de operat fără câștig. *Verificat* prin testul de contract, testele de idempotență și testul de fum cu Socket.IO real.
