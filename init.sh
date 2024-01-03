#!/bin/bash

while true; do
    # Prompt the user for input
    echo -n "Domain website: "

    # Read input and assign it to a variable
    read DOMAIN

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
resolved_ip=$(nslookup "$DOMAIN" | grep -oP 'Address: \K[^\s]+')
resolved_ip_www=$(nslookup "www.$DOMAIN" | grep -oP 'Address: \K[^\s]+')

# Check for IP inconsistencies and handle errors
if [ "$resolved_ip" != "$main_ip" ] || [ "$resolved_ip" != "$resolved_ip_www" ] || [ "$main_ip" != "$resolved_ip_www" ]; then
    echo "IP host:   $main_ip"
    echo "IP domain: $resolved_ip"
    echo "IP domain (www): $resolved_ip_www"
    echo "Domain not resolve to host or www IPs mismatch, please check and try again!"
    exit 1  # Use a non-zero exit code to signal error
fi


while true; do
    # Prompt the user for input
    echo -n "Create DB Name: "

    # Read input and assign it to a variable
    read MARIADB_DATABASE

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
    read MARIADB_USER

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

echo "MARIADB_ROOT_PASSWORD=$MARIADB_ROOT_PASSWORD" >> .env
echo "MARIADB_DATABASE=$MARIADB_DATABASE" >> .env
echo "MARIADB_USER=$MARIADB_USER" >> .env
echo "MARIADB_PASSWORD=$MARIADB_PASSWORD" >> .env 
echo "DOMAIN=$DOMAIN" >> .env


git clone  https://github.com/coreruleset/coreruleset.git nginx/modsec/coreruleset
cp nginx/modsec/coreruleset/crs-setup.conf.example nginx/modsec/coreruleset/crs-setup.conf
cp nginx/modsec/coreruleset/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf.example nginx/modsec/coreruleset/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf
sed -i "s/example.com/$DOMAIN/g" nginx/conf.d/example.com.conf
mv nginx/conf.d/example.com.conf nginx/conf.d/$DOMAIN.conf

echo "I have completed my mission, in the process of erasing myself."
rm init.sh
asfdasf
