#!/usr/bin/env zsh

echo "Checking Traefik API status..."
echo "Traefik Dashboard: http://localhost:8099/dashboard/"

echo "
Checking if Traefik detects the following routers:"
echo "- prowlarr.${DOMAIN}"
echo "- movies.${DOMAIN}"
echo "- get.${DOMAIN}"

docker inspect --format '{{range .Config.Labels}}{{println .}}{{end}}' $(docker ps -q -f name=prowlarr) | grep traefik
docker inspect --format '{{range .Config.Labels}}{{println .}}{{end}}' $(docker ps -q -f name=jellyfin) | grep traefik
docker inspect --format '{{range .Config.Labels}}{{println .}}{{end}}' $(docker ps -q -f name=qbittorrent) | grep traefik

# Log the last few lines from Traefik to check for any errors
echo "
Latest Traefik logs:"
docker logs --tail 20 traefik

