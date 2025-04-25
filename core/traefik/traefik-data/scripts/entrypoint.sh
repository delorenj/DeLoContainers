#!/bin/sh
chmod 600 /etc/traefik/acme.json
exec "$@"
