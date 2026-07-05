#!/bin/bash
# Update this deployment to the latest version of the repo.
#
#   ./update.sh                 pull prebuilt images from GHCR (fast)
#   UPDATE_BUILD=1 ./update.sh  build the images locally instead
#
# Per-VM files are never touched: .env, docker-compose.override.yml,
# conf/mariadb/zz-*.cnf, conf/nginx/conf.d/local/*.conf
set -euo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

if [ ! -f .env ]; then
    echo ".env not found - run init.sh first."
    exit 1
fi
# shellcheck source=/dev/null
source .env

echo "==> Pulling latest changes from git"
git pull --ff-only

# Re-render the site config from the tracked template so template
# improvements reach this machine. Per-host tweaks belong in
# conf/nginx/conf.d/local/, which the template includes.
if [ -n "${DOMAIN:-}" ]; then
    sed "s/example.com/$DOMAIN/g" conf/nginx/site.conf.template > "conf/nginx/conf.d/${DOMAIN}.conf"
    echo "==> Re-rendered conf/nginx/conf.d/${DOMAIN}.conf from the template"
fi

if [ "${UPDATE_BUILD:-0}" = "1" ]; then
    echo "==> Building images locally (UPDATE_BUILD=1)"
    docker compose build --pull
else
    echo "==> Pulling prebuilt images"
    docker compose pull
fi

echo "==> Applying"
docker compose up -d --remove-orphans

echo "==> Removing dangling images"
docker image prune -f > /dev/null

docker compose ps
echo "Update complete."
