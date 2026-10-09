#!/bin/sh
# Backup zilnic al bazei (rulat de serviciul `backup` din docker-compose.prod.yml).
# pg_dump (format custom, comprimat) → criptat cu age pentru BACKUP_AGE_RECIPIENT → /backups.
# Fișierele mai vechi de 35 de zile se șterg. Fără cheie publică, nu pornește (nu lăsăm
# backup-uri necriptate pe disc).
set -eu
apk add --no-cache age >/dev/null
if [ -z "${BACKUP_AGE_RECIPIENT:-}" ]; then
  echo "BACKUP_AGE_RECIPIENT lipsește: backup-ul nu rulează." >&2
  exit 1
fi
while true; do
  name="/backups/licurici-$(date -u +%Y%m%dT%H%M%SZ).dump.age"
  if pg_dump --format=custom --no-owner | age -r "$BACKUP_AGE_RECIPIENT" > "$name.tmp"; then
    mv "$name.tmp" "$name"
    echo "backup: $(basename "$name") ($(du -h "$name" | cut -f1))"
  else
    rm -f "$name.tmp"
    echo "backup eșuat" >&2
  fi
  find /backups -name 'licurici-*.dump.age' -mtime +35 -delete
  sleep 86400
done
