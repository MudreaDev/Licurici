# Operare — producția Licurici

Pentru un VPS în UE cu Docker (README §18, ADR-17). **Netestat încă** pe un server real: primul deploy se face cu
lista de mai jos în mână și se notează aici ce a fost diferit.

## Primul deploy

1. DNS: `api.<DOMAIN>` și `panou.<DOMAIN>` → IP-ul serverului. Porturile 80 și 443 deschise; restul închise.
2. `cp infra/.env.example infra/.env` și completează:
   - parolele (`POSTGRES_PASSWORD`, `REDIS_PASSWORD`, `S3_SECRET_KEY`, `JWT_SECRET` — `openssl rand -hex 32`);
   - `NODE_ENV=production`, `DOMAIN`, `ACME_EMAIL`;
   - `SMTP_URL` = releul SMTP Brevo (`smtp://<login>:<cheie>@smtp-relay.brevo.com:587`), `MAIL_FROM` pe domeniul tău
     (cu SPF/DKIM configurate în Brevo);
   - `BACKUP_AGE_RECIPIENT` = cheia **publică** age (`age-keygen -o cheie.txt` pe calculatorul tău; cheia privată rămâne
     la tine, într-un manager de parole, **nu** pe server);
   - opțional `ANTHROPIC_API_KEY` (rezumatele AI, ADR-029).
3. `docker compose -f infra/docker-compose.yml -f infra/docker-compose.prod.yml up -d --build`
4. Verificări: `https://api.<DOMAIN>/health/ready` → `ok`; `https://panou.<DOMAIN>` se deschide; cont nou → e-mailul de
   confirmare ajunge; `docker compose … logs backup` arată primul backup.
5. Aplicația de pe tabletă: build cu `--dart-define=API_URL=https://api.<DOMAIN>/api/v1`.

## Actualizare

```bash
git pull
docker compose -f infra/docker-compose.yml -f infra/docker-compose.prod.yml up -d --build
```

`migrate` rulează migrările înainte ca `api` și `worker` să pornească. O migrare care șterge date se citește întâi.

## Backup și restaurare

- Zilnic, serviciul `backup` scrie `licurici-<data>.dump.age` în volumul `backups` (35 de zile).
- **Copia în afara serverului** (alt furnizor/bucket în UE), de exemplu zilnic din cron-ul gazdei:
  `rclone copy /var/lib/docker/volumes/licurici_backups/_data remote:licurici-backups --max-age 48h`.
- **Testul lunar de restaurare** (pe un calculator separat, niciodată peste producție):

  ```bash
  age -d -i cheie.txt licurici-<data>.dump.age > licurici.dump
  docker run --rm -d --name pgtest -e POSTGRES_PASSWORD=test postgres:17-alpine
  docker cp licurici.dump pgtest:/tmp/ && docker exec pgtest pg_restore -U postgres -d postgres --create /tmp/licurici.dump
  docker exec pgtest psql -U postgres -d licurici -c 'select count(*) from users;'
  ```

  Notează data și rezultatul în registrul de incidente/teste (`docs/gdpr/procedura-incident.md`).
- Ștergerea definitivă a unui cont (GDPR) nu atinge backup-urile vechi: ele expiră singure în 35 de zile — asta e scris în
  politica de retenție.

## Monitorizare

- `/health` (proces viu) și `/health/ready` (PostgreSQL + Redis) — de pus într-un monitor extern (UptimeRobot, Better Stack).
- Logurile sunt JSON fără date personale: `docker compose … logs -f api worker`.
- Cozile: Bull Board doar în dezvoltare; în producție, la nevoie, un tunel SSH către Redis și Bull Board local.
