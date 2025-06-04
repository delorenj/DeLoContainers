#!/usr/bin/env zsh

echo "Checking Traefik API status..."
echo "Traefik Dashboard: http://localhost:8099/dashboard/"

echo "\nChecking if Traefik detects the following routers:"
echo "- prowlarr.delo.sh"
echo "- movies.delo.sh"
echo "- get.delo.sh"

docker inspect --format '{{range .Spec.Labels}}{{println .}}{{end}}' $(docker ps -q -f name=prowlarr) | grep traefik
docker inspect --format '{{range .Spec.Labels}}{{println .}}{{end}}' $(docker ps -q -f name=jellyfin) | grep traefik
docker inspect --format '{{range .Spec.Labels}}{{println .}}{{end}}' $(docker ps -q -f name=qbittorrent) | grep traefik

# Log the last few lines from Traefik to check for any errors
echo "\nLatest Traefik logs:"
docker logs --tail 20 traefik
