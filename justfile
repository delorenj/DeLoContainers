# Print the service map showing compose files and configurations
service-map:
    @tree -L 4 --dirsfirst -F \
        -P "compose.yml|docker-compose.yml|deploy-compose.yml|README.md|*.toml|*.yaml|*.yml" \
        --prune
