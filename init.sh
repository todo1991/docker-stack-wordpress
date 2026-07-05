#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

# This script installs packages and writes to /etc/logrotate.d, so it needs root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script as root (sudo bash init.sh)."
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install docker first!"
    exit 1
fi

# Update package list and install dnsutils, git, cron and logrotate (Debian/Ubuntu only)
if ! command -v apt-get &> /dev/null; then
    echo "This script currently supports Debian/Ubuntu (apt-get) only."
    echo "Please install dnsutils, git, cron and logrotate manually, then re-run."
    exit 1
fi
echo "Update and install necessary packages"
apt-get update > /dev/null
apt-get install -y dnsutils git cron logrotate > /dev/null

# domain information
while true; do
    echo -n "Domain website: "
    read -r DOMAIN

    if [[ "$DOMAIN" == *" "* ]] || [[ -z "$DOMAIN" ]]; then
        echo "Error: Input cannot be empty or contain spaces. Please retype."
    else
        break
    fi
done

# Determine the main IP address of the host
main_ip="$(ip route get 1.1.1.1 | awk '{print $7; exit}')"

# A domain may resolve to several A records (e.g. behind a load balancer or
# round-robin DNS); accept as long as the host IP is among them for @ and www.
resolved_ips=$(dig +short A "$DOMAIN")
resolved_ips_www=$(dig +short A "www.$DOMAIN")

if ! grep -qx "$main_ip" <<< "$resolved_ips" || ! grep -qx "$main_ip" <<< "$resolved_ips_www"; then
    echo "IP host:         $main_ip"
    echo "IP domain:       ${resolved_ips:-<none>}"
    echo "IP domain (www): ${resolved_ips_www:-<none>}"
    echo "Domain does not resolve to this host for @ and/or www, please check DNS and try again!"
    exit 1
fi

while true; do
    echo -n "Enter your email address: "
    read -r EMAIL

    if [[ $EMAIL =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
        break
    else
        echo "Invalid email format. Please try again."
    fi
done

while true; do
    echo -n "Create DB Name: "
    read -r MARIADB_DATABASE

    if [[ "$MARIADB_DATABASE" == *" "* ]] || [[ -z "$MARIADB_DATABASE" ]]; then
        echo "Error: Input cannot be empty or contain spaces. Please retype."
    else
        break
    fi
done

while true; do
    echo -n "Create DB User: "
    read -r MARIADB_USER

    if [[ "$MARIADB_USER" == *" "* ]] || [[ -z "$MARIADB_USER" ]]; then
        echo "Error: Input cannot be empty or contain spaces. Please retype."
    else
        break
    fi
done

MARIADB_PASSWORD=$(openssl rand -base64 18 | tr -d '/+=')
MARIADB_ROOT_PASSWORD=$(openssl rand -base64 18 | tr -d '/+=')

# create file .env
env_file=".env"
if [ -e "$env_file" ]; then
    echo "File $env_file already exists. Recreating..."
fi
cat <<EOF > "$env_file"
MARIADB_ROOT_PASSWORD=$MARIADB_ROOT_PASSWORD
MARIADB_DATABASE=$MARIADB_DATABASE
MARIADB_USER=$MARIADB_USER
MARIADB_PASSWORD=$MARIADB_PASSWORD
DOMAIN=$DOMAIN
EMAIL=$EMAIL
WORDPRESS_TABLE_PREFIX=wpstack_
EOF

docker volume create mariadb
docker volume create public_html
docker volume create certbot-ssl

# Issue the initial certificate only if one does not exist yet,
# to avoid hitting Let's Encrypt rate limits when re-running this script.
if ! docker run --rm -v "certbot-ssl:/etc/letsencrypt" certbot/certbot certificates -d "$DOMAIN" 2>/dev/null | grep -q "Certificate Name"; then
    docker run -it --rm --name certbotssl -v "certbot-ssl:/etc/letsencrypt" -p 80:80 \
      certbot/certbot certonly --standalone --email "$EMAIL" --agree-tos \
      --no-eff-email -d "$DOMAIN" -d "www.$DOMAIN"
else
    echo "Certificate for $DOMAIN already exists, skipping issuance."
fi

# add modsec core rule set (skip if already cloned)
if [ ! -d conf/nginx/modsec/coreruleset ]; then
    git clone https://github.com/coreruleset/coreruleset.git conf/nginx/modsec/coreruleset > /dev/null
    cp conf/nginx/modsec/coreruleset/crs-setup.conf.example conf/nginx/modsec/coreruleset/crs-setup.conf
    cp conf/nginx/modsec/coreruleset/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf.example conf/nginx/modsec/coreruleset/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf
fi

# render the site config from the tracked template (conf.d only holds
# rendered/untracked files, so git updates never fight with it)
sed "s/example.com/$DOMAIN/g" conf/nginx/site.conf.template > "conf/nginx/conf.d/${DOMAIN}.conf"

# generate a per-host testcookie secret (kept out of git so updates
# never overwrite it and the secret is never public)
if [ ! -e conf/nginx/conf.d/local/00-testcookie-secret.conf ]; then
    printf 'testcookie_secret %s;\n' "$(openssl rand -hex 24)" > conf/nginx/conf.d/local/00-testcookie-secret.conf
fi

# ssl renew helper: renew via webroot, then reload (not restart) nginx so
# there is no downtime; reload is a no-op when nothing was renewed.
cat <<EOF > ssl_renew.sh
#!/bin/bash
DOCKER="/usr/bin/docker"
cd $SCRIPT_DIR
\$DOCKER compose run --rm certbot renew --webroot --webroot-path=/var/www/html
\$DOCKER exec nginx nginx -s reload
EOF
chmod +x ssl_renew.sh

# add cronjob renew ssl (only once)
SSL_RENEW_SCRIPT="$SCRIPT_DIR/ssl_renew.sh"
if ! crontab -l 2>/dev/null | grep -qF "$SSL_RENEW_SCRIPT"; then
    (crontab -l 2>/dev/null; echo "0 2 * * * bash $SSL_RENEW_SCRIPT >/dev/null 2>&1") | crontab -
    echo "Cron job added to run ssl_renew.sh every day at 2AM."
fi

# rotate nginx logs in ./logs so they don't grow unbounded
sed "s|__LOGDIR__|$SCRIPT_DIR/logs|" conf/logrotate/nginx-docker > /etc/logrotate.d/nginx-docker
echo "Logrotate config installed to /etc/logrotate.d/nginx-docker."

# WP cron runs from here instead of on page views (DISABLE_WP_CRON is set)
WPCRON_CMD="cd $SCRIPT_DIR && /usr/bin/docker compose run --rm --no-deps --quiet-pull wpcli cron event run --due-now"
if ! crontab -l 2>/dev/null | grep -qF "cron event run"; then
    (crontab -l 2>/dev/null; echo "*/5 * * * * $WPCRON_CMD >/dev/null 2>&1") | crontab -
    echo "Cron job added to run WordPress cron every 5 minutes."
fi

# wp-cli alias (only once)
if ! grep -qs 'alias wpcli=' ~/.bash_aliases; then
    echo 'alias wpcli="docker compose run -ti --rm --no-deps --quiet-pull wpcli"' >> ~/.bash_aliases
    echo "Added wpcli alias to ~/.bash_aliases (re-login or 'source ~/.bash_aliases' to use it)."
fi

echo "Init completed. You can now run: docker compose up -d"
echo "Have a nice day !!!"
