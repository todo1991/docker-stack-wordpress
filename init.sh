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

main_ip="$(ip route get 1.1.1.1 | awk '{print $7}')"
resolved_ip=$(nslookup "$DOMAIN" | grep -oP 'Address: \K[^\s]+')

if [ "$resolved_ip" != "$main_ip" ]; then
    echo "IP host:   $main_ip"
    echo "IP domain: $resolved_ip"
    echo "Domain not resolve to host, please check and try again!"
    exit 0
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

git clone  https://github.com/coreruleset/coreruleset.git nginx/modsec/coreruleset
cp nginx/modsec/coreruleset/crs-setup.conf.example nginx/modsec/coreruleset/crs-setup.conf
cp nginx/modsec/coreruleset/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf.example nginx/modsec/coreruleset/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf
sed -i "s/example.com/$DOMAIN/g" nginx/conf.d/example.com.conf
mv nginx/conf.d/example.com.conf nginx/conf.d/$DOMAIN.conf
