#!/bin/sh
chmod 600 ./traefik-data/acme.json
exec "$@"
