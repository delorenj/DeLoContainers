#!/bin/sh
chmod 600 /etc/traefik/acme.json 2>/dev/null || true
exec traefik
