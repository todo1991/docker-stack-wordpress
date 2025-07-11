#!/bin/bash
set -euo pipefail
# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install docker first!"
    exit 1
fi

# Update package list and install dnsutils, git, and cron
echo "Update and install necessary packages"
apt-get update > /dev/null
apt-get install -y dnsutils git cron > /dev/null

# domain infomation
while true; do
    # Prompt the user for input
    echo -n "Domain website: "

    # Read input and assign it to a variable
    read -r DOMAIN

    # Check if the input contains spaces
    if [[ "$DOMAIN" == *" "* ]]; then
        echo "Error: Input cannot contain spaces. Please retype."
    else
        break
    fi
done

# Determine the main IP address of the host
main_ip="$(ip route get 1.1.1.1 | awk '{print $7}')"

# Resolve the IP addresses for the domain and www subdomain
resolved_ip=$(nslookup "$DOMAIN" -type=a| grep -oP 'Address: \K[^\s]+')
resolved_ip_www=$(nslookup "www.$DOMAIN" -type=a| grep -oP 'Address: \K[^\s]+')

# Check for IP inconsistencies and handle errors
if [ "$resolved_ip" != "$main_ip" ] || [ "$resolved_ip" != "$resolved_ip_www" ] || [ "$main_ip" != "$resolved_ip_www" ]; then
    echo "IP host:   $main_ip"
    echo "IP domain: $resolved_ip"
    echo "IP domain (www): $resolved_ip_www"
    echo "Domain not resolve to host or www IPs mismatch, please check and try again!"
    exit 1  # Use a non-zero exit code to signal error
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
    # Prompt the user for input
    echo -n "Create DB Name: "

    # Read input and assign it to a variable
    read -r MARIADB_DATABASE

    # Check if the input contains spaces
    if [[ "$MARIADB_DATABASE" == *" "* ]]; then
        echo "Error: Input cannot contain spaces. Please retype."
    else
        break
    fi
done

while true; do
    # Prompt the user for input
    echo -n "Create DB User: "

    # Read input and assign it to a variable
    read -r MARIADB_USER

    # Check if the input contains spaces
    if [[ "$MARIADB_USER" == *" "* ]]; then
        echo "Error: Input cannot contain spaces. Please retype."
    else
        break
    fi
done

MARIADB_PASSWORD=$(openssl rand -base64 9 | tr -d '/+' | cut -c1-12)
MARIADB_ROOT_PASSWORD=$(openssl rand -base64 9 | tr -d '/+' | cut -c1-12)
# create file .env
env_file=".env"
if [ -e "$env_file" ]; then
    echo "File already exists. Recreating..."
    rm "$env_file"
fi
touch "$env_file"
cat <<EOF > "$env_file"
MARIADB_ROOT_PASSWORD=$MARIADB_ROOT_PASSWORD
MARIADB_DATABASE=$MARIADB_DATABASE
MARIADB_USER=$MARIADB_USER
MARIADB_PASSWORD=$MARIADB_PASSWORD
DOMAIN=$DOMAIN
EMAIL=$EMAIL
IPHOST=$main_ip
EOF

docker volume create mariadb
docker volume create public_html
docker volume create certbot-ssl
docker run -it --rm --name certbotssl -v "certbot-ssl:/etc/letsencrypt" -p 80:80 \
  certbot/certbot certonly --standalone --email "$EMAIL" --agree-tos \
  --no-eff-email --force-renewal -d "$DOMAIN" -d "www.$DOMAIN"

# add modsec
git clone  https://github.com/coreruleset/coreruleset.git conf/nginx/modsec/coreruleset > /dev/null
cp conf/nginx/modsec/coreruleset/crs-setup.conf.example conf/nginx/modsec/coreruleset/crs-setup.conf
cp conf/nginx/modsec/coreruleset/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf.example conf/nginx/modsec/coreruleset/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf
sed -i "s/example.com/$DOMAIN/g" conf/nginx/conf.d/example.com.conf
mv conf/nginx/conf.d/example.com.conf "conf/nginx/conf.d/${DOMAIN}.conf"

# add cronjob renewssl
SCRIPT_DIR=$(dirname "$(realpath "$0")")

cat <<EOF >> ssl_renew.sh
#!/bin/bash
DOCKER="/usr/bin/docker"
cd $SCRIPT_DIR
\$DOCKER compose run --rm certbot --webroot --webroot-path=/var/www/html renew
\$DOCKER restart nginx
EOF

SSL_RENEW_SCRIPT="$SCRIPT_DIR/ssl_renew.sh"
crontab -l > mycron 2>/dev/null || true
echo "0 2 * * * bash $SSL_RENEW_SCRIPT >/dev/null 2>&1" >> mycron
crontab mycron
rm mycron
echo "Cron job added to run ssl_renew.sh every day at 2AM."

# done
echo 'alias wpcli="docker compose run -ti --rm --no-deps --quiet-pull wpcli"' >> ~/.bash_aliases
# shellcheck source=/dev/null
source ~/.bash_aliases
echo "I have completed my mission, in the process of erasing myself."
rm init.sh
echo "Have a nice day !!!"
