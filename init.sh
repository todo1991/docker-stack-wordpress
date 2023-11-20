#!/bin/bash

# Redirect input from the file to the 'read' command
while IFS= read -r line; do
    # Evaluate the line to set the variable
    eval "$line"
done < .env

set -x
git clone  https://github.com/coreruleset/coreruleset.git nginx/modsec/coreruleset
cp nginx/modsec/coreruleset/crs-setup.conf.example nginx/modsec/coreruleset/crs-setup.conf
cp nginx/modsec/coreruleset/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf.example nginx/modsec/coreruleset/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf
sed -i "s/example.com/$DOMAIN/g" nginx/conf.d/example.com.conf
mv nginx/conf.d/example.com.conf nginx/conf.d/$DOMAIN.conf
