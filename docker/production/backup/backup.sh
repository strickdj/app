#!/bin/bash

# @TODO add backup user
# - backup integrity verification (test restore)
# - S3 upload + lifecycle policies
# - encryption (so backups aren’t plaintext on disk)

set -euo pipefail

: "${DB_BACKUP_USER:?DB_BACKUP_USER is required}"
: "${DB_BACKUP_PASSWORD:?DB_BACKUP_PASSWORD is required}"
: "${DB_DATABASE:?DB_DATABASE is required}"
: "${DB_HOST:=mysql}"

TIMESTAMP=$(date +%F-%H-%M)
FILE="/backups/backup-$TIMESTAMP.sql.gz"
TMP_BASE="/backups/backup-$TIMESTAMP.sql"
TMP_FILE="${TMP_BASE}.gz"

echo "[INFO] Starting backup: $TIMESTAMP"

MAX_RETRIES=3
RETRY_DELAY=10

attempt=1
while [ "$attempt" -le "$MAX_RETRIES" ]; do
  echo "[INFO] Attempt $attempt..."

  if MYSQL_PWD="$DB_BACKUP_PASSWORD" timeout 300 mysqldump \
    -h "$DB_HOST" \
    -u "$DB_BACKUP_USER" \
    --single-transaction \
    --routines \
    --quick \
    --events \
    --databases \
    --add-drop-database \
    "$DB_DATABASE" \
    > "$TMP_BASE"
  then
    gzip "$TMP_BASE"
    mv "$TMP_FILE" "$FILE"
    echo "[INFO] Backup completed (attempt: $attempt): $FILE"

    # keep last 7 days
    find /backups -type f -name "*.sql.gz" -mtime +7 -delete
    exit 0
  else
    rm -f "$TMP_FILE"
  fi

  echo "[WARN] Attempt $attempt failed"

  if [ $attempt -eq $MAX_RETRIES ]; then
    echo "[ERROR] All backup attempts failed" >&2
    if [ -n "${ALERT_WEBHOOK_URL:-}" ]; then
      curl -X POST "$ALERT_WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "{\"text\":\"Backup failed at $TIMESTAMP\"}" || true
    fi
    exit 1
  fi

  attempt=$((attempt + 1))
  sleep $RETRY_DELAY
done
