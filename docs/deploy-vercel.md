# Versiunea de test pe Vercel — panoul terapeutului și legarea tabletei

Versiune simplă, **până trecem pe stiva completă** (NestJS + PostgreSQL + Redis în Docker, README §4, §18):

- **panoul** Flutter Web (`apps/dashboard`) pe Vercel, cu funcția terapeutului „Adaugă copil”;
- un **API mic** (`deploy/vercel/lib/app.js`, aceleași rute ca backend-ul pentru ce folosesc panoul și tableta)
  într-o singură funcție Vercel;
- **baza de date simplă**: documente JSON în **Vercel Blob**, cu acces **privat** (`deploy/vercel/lib/store.js`).

## Cum funcționează

1. Terapeutul își face cont în panou („Sunt specialist”) → **Adaugă copil**: porecla (nu numele real), anul nașterii,
   obiectivele, observațiile. Primește un **cod de unică folosință** (ex. `6MVP-BD8E`) și o legătură
   `https://<domeniu>/c/6MVP-BD8E` pe care o trimite părintelui (butonul „Copiază mesajul pentru părinte”).
2. Pe tabletă, la **prima pornire** apare „Bun venit” → **Am un cod de la terapeut** (sau oricând: „Pentru părinți” →
   „Cod de la terapeut”). Părintele scrie codul sau lipește legătura, **bifează acordul** și apasă „Leagă tableta”.
3. Tableta devine un „cont” legat **doar de acel copil**: sesiunile pleacă singure la terapeut după „Gata pe azi”,
   iar planul ales de terapeut (jocuri, niveluri, imagini de evitat, muzica) vine pe tabletă.
4. În panou, la copil: tabul **„Fișa copilului”** (datele, starea tabletei, codul nou, „Deconectează tableta” — pentru
   o tabletă pierdută), plus Prezentare, Progres, Sesiuni, Confuzii, Jocuri. Panoul se actualizează la 30 s
   („Sesiune nouă de la …”, „Se joacă acum”).

Ce **nu** e în versiunea de test: e-mailuri (confirmare, parolă uitată), 2FA, partajarea cu alți specialiști,
rezumatele AI, Socket.IO. Rutele lor răspund „Nu e disponibil în versiunea de test.”.

## Deploy (o singură dată, ~5 minute) — îl face proprietarul contului Vercel

Cheia Vercel folosită de asistent poate doar citi (crearea proiectului dă 403), deci primii pași se fac din
[vercel.com](https://vercel.com):

1. **Add New → Project → Import Git Repository** → `MudreaDev/Licurici` (dacă cere, instalează aplicația Vercel
   pe GitHub pentru acest repo).
2. La configurare:
   - **Root Directory**: `deploy/vercel` (bifat „Include files outside the root directory” — e implicit);
   - **Framework Preset**: Other (build-ul și ieșirea vin din `deploy/vercel/vercel.json`);
   - **Environment Variables**: `AUTH_SECRET` = un șir lung aleator (de ex. rezultatul comenzii de mai jos).
3. **Deploy**. Primul build durează ~8–10 minute (instalează Flutter 3.47.2 și construiește panoul).
4. **Storage → Create Database → Blob** → acces **Private** → **Connect to project** `licurici-panou`
   (adaugă singur `BLOB_READ_WRITE_TOKEN`). Apoi **Redeploy** (fără Blob, datele ar sta doar în memorie și s-ar pierde).
5. Ramura: pentru deploy automat la fiecare push, **Settings → Git → Production Branch** = `feat/fundatia-terapeutica`
   (sau unește ramura în `main`).

```bash
node -e "console.log(require('crypto').randomBytes(32).toString('base64url'))"
```

Numele proiectului **`licurici-panou`** dă adresa `https://licurici-panou.vercel.app` — aceeași pe care o știe
aplicația când părintele scrie **doar codul**. Cu alt nume, legătura completă merge oricum (are adresa în ea);
pentru codul simplu, construiește APK-ul cu `--dart-define=LINK_SERVER=https://<domeniul-tău>`.

## Local, fără Vercel

```bash
cd deploy/vercel
npm install
npm test                 # testele API-ului (node:test)
node dev.js 5175         # după un build al panoului în public/ (vezi build.sh)
```

## Mai târziu: trecerea pe stiva completă

Rutele sunt aceleași ca în backend-ul NestJS (README §12), plus `POST /children` (terapeutul), `PATCH /children/:id`,
`GET|POST /children/:id/link` și `POST /device/link`. La migrare: aceste rute se adaugă în backend, iar documentele
JSON din Blob (`db/users`, `db/children`, `db/sessions`) se importă o dată în PostgreSQL.
