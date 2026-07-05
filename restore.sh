#!/bin/bash
# Restore archives created by backup.sh. Pass one or more backup files;
# the type is detected from the filename:
#
#   ./restore.sh backups/db-2026-07-05_01-30-00.sql.gz
#   ./restore.sh backups/html-....tar.gz backups/db-....sql.gz
#
# Each step asks for confirmation (type YES). Set RESTORE_YES=1 to skip
# prompts (for scripted drills).
set -euo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <backups/db-*.sql.gz | backups/html-*.tar.gz | backups/config-*.tar.gz> ..."
    exit 1
fi

if [ ! -f .env ]; then
    echo ".env not found - run init.sh first."
    exit 1
fi
# shellcheck source=/dev/null
source .env

confirm() {
    if [ "${RESTORE_YES:-0}" = "1" ]; then
        return 0
    fi
    local answer
    read -r -p "$1 [type YES to continue] " answer
    [ "$answer" = "YES" ]
}

purge_page_cache() {
    docker exec nginx find /run/nginx-cache -type f -delete 2>/dev/null || true
}

STAMP=$(date +%F_%H-%M-%S)

for f in "$@"; do
    if [ ! -f "$f" ]; then
        echo "ERROR: file not found: $f"
        exit 1
    fi
    base=$(basename "$f")
    dir=$(dirname "$(realpath "$f")")

    case "$base" in
        db-*.sql.gz)
            confirm "Overwrite database '$MARIADB_DATABASE' with $base?" || continue
            echo "==> Safety dump of the CURRENT database first"
            mkdir -p backups
            docker compose exec -T -e MYSQL_PWD="$MARIADB_PASSWORD" mariadb \
                mariadb-dump --single-transaction --quick --routines --triggers \
                -u "$MARIADB_USER" "$MARIADB_DATABASE" | gzip > "backups/db-prerestore-$STAMP.sql.gz"
            echo "    saved backups/db-prerestore-$STAMP.sql.gz"
            echo "==> Importing $base"
            zcat "$f" | docker compose exec -T -e MYSQL_PWD="$MARIADB_PASSWORD" mariadb \
                mariadb -u "$MARIADB_USER" "$MARIADB_DATABASE"
            echo "==> Flushing redis object cache and nginx page cache"
            docker compose exec redis redis-cli flushall > /dev/null
            purge_page_cache
            echo "    database restored."
            echo "    NOTE: WORDPRESS_TABLE_PREFIX in .env must match the prefix inside the dump."
            ;;
        html-*.tar.gz)
            confirm "WIPE and overwrite ALL website files (public_html volume) with $base?" || continue
            echo "==> Restoring website files"
            docker run --rm -v public_html:/data -v "$dir:/backup:ro" alpine \
                sh -c "find /data -mindepth 1 -delete && tar xzf /backup/$base -C /data && chown -R 82:82 /data"
            purge_page_cache
            # a migrated code tree should not carry the old server's
            # wp-config.php; the wordpress image regenerates it from .env
            # on container start
            if ! docker run --rm -v public_html:/data:ro alpine test -e /data/wp-config.php; then
                if docker ps --format '{{.Names}}' | grep -q '^wordpress_instance$'; then
                    echo "    wp-config.php missing - restarting wordpress_instance to regenerate it from .env"
                    docker compose restart wordpress_instance
                else
                    echo "    wp-config.php missing - it will be generated from .env on 'docker compose up -d'"
                fi
            fi
            echo "    website files restored."
            ;;
        config-*.tar.gz)
            confirm "Overwrite per-host config (.env, rendered nginx conf, overrides) with $base?" || continue
            tar xzf "$f" -C "$SCRIPT_DIR"
            echo "    config restored - run 'docker compose up -d' to apply."
            ;;
        *)
            echo "ERROR: unrecognized backup file name: $base (expected db-/html-/config- prefix)"
            exit 1
            ;;
    esac
done

echo "Restore finished. Verify with: docker compose ps && curl -skI https://$DOMAIN/"
