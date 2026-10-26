#!/bin/bash
# Nightly backup of the POS database from the Docker container.
# Cron example (as the user that runs docker):
#   30 23 * * * /home/<user>/lab-pos/db/backup.sh >> /home/<user>/pos-backups/backup.log 2>&1
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-$HOME/pos-backups}"
KEEP_DAYS="${KEEP_DAYS:-30}"
mkdir -p "$BACKUP_DIR"

file="$BACKUP_DIR/abarrotes_pos_$(date +%F).dump"
docker exec pos-db pg_dump -U postgres -Fc abarrotes_pos > "$file.tmp"
mv "$file.tmp" "$file"
find "$BACKUP_DIR" -name 'abarrotes_pos_*.dump' -mtime +"$KEEP_DAYS" -delete
echo "$(date -Is) backup ok: $file ($(du -h "$file" | cut -f1))"
