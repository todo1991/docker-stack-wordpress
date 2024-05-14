#!/bin/bash
DOCKER="/usr/bin/docker"
cd /root/dockerlab/docker-stack-wordpress/
$DOCKER compose run --rm certbot --webroot --webroot-path=/var/www/html renew
$DOCKER restart nginx
