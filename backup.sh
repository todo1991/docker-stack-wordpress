#!/bin/bash
# Local backups for this stack, written to ./backups (gitignored).
#
#   ./backup.sh        database + per-host config   (cron: daily)
#   ./backup.sh full   + website files              (cron: weekly)
#
# Retention (days), override via environment:
#   BACKUP_KEEP_DAYS=7 BACKUP_KEEP_DAYS_FULL=28 ./backup.sh
#
# NOTE: these backups live on the same machine - copy them offsite
# (rclone/S3/another host) to survive the loss of the VM itself.
set -euo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

MODE="${1:-db}"
STAMP=$(date +%F_%H-%M-%S)
BACKUP_DIR="$SCRIPT_DIR/backups"
KEEP_DAYS="${BACKUP_KEEP_DAYS:-7}"
KEEP_DAYS_FULL="${BACKUP_KEEP_DAYS_FULL:-28}"

if [ ! -f .env ]; then
    echo ".env not found - run init.sh first."
    exit 1
fi
# shellcheck source=/dev/null
source .env
mkdir -p "$BACKUP_DIR"

echo "==> Backing up database '$MARIADB_DATABASE'"
db_file="$BACKUP_DIR/db-$STAMP.sql.gz"
# --single-transaction: consistent snapshot without locking the site
docker compose exec -T -e MYSQL_PWD="$MARIADB_PASSWORD" mariadb \
    mariadb-dump --single-transaction --quick --routines --triggers \
    -u "$MARIADB_USER" "$MARIADB_DATABASE" | gzip > "$db_file"
gzip -t "$db_file"
if ! zcat "$db_file" | tail -n1 | grep -q "Dump completed"; then
    echo "ERROR: dump is incomplete: $db_file"
    exit 1
fi
echo "    $(du -h "$db_file" | cut -f1)  $db_file"

echo "==> Backing up per-host config (.env, overrides, rendered nginx conf)"
config_items=(.env)
[ -e docker-compose.override.yml ] && config_items+=(docker-compose.override.yml)
[ -e ssl_renew.sh ] && config_items+=(ssl_renew.sh)
while IFS= read -r f; do
    config_items+=("$f")
done < <(
    find conf/mariadb -maxdepth 1 -name 'zz-*.cnf' 2>/dev/null
    find conf/nginx/conf.d -maxdepth 1 -name '*.conf' 2>/dev/null
    find conf/nginx/conf.d/local -maxdepth 1 -name '*.conf' 2>/dev/null
)
config_file="$BACKUP_DIR/config-$STAMP.tar.gz"
tar czf "$config_file" "${config_items[@]}"
echo "    $(du -h "$config_file" | cut -f1)  $config_file"

if [ "$MODE" = "full" ]; then
    echo "==> Backing up website files (public_html volume)"
    html_file="$BACKUP_DIR/html-$STAMP.tar.gz"
    docker run --rm -v public_html:/data:ro -v "$BACKUP_DIR:/backup" alpine \
        tar czf "/backup/$(basename "$html_file")" -C /data .
    gzip -t "$html_file"
    echo "    $(du -h "$html_file" | cut -f1)  $html_file"
fi

echo "==> Pruning backups older than ${KEEP_DAYS}d (db/config) / ${KEEP_DAYS_FULL}d (html)"
find "$BACKUP_DIR" -name 'db-*.sql.gz' -mtime +"$KEEP_DAYS" -delete
find "$BACKUP_DIR" -name 'config-*.tar.gz' -mtime +"$KEEP_DAYS" -delete
find "$BACKUP_DIR" -name 'html-*.tar.gz' -mtime +"$KEEP_DAYS_FULL" -delete

echo "Backup complete."
