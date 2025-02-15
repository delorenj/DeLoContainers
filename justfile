# Print the service map showing compose files and configurations
service-map:
    @tree -L 4 --dirsfirst -F \
        -P "compose.yml|docker-compose.yml|deploy-compose.yml|README.md|*.toml|*.yaml|*.yml" \
        --prune | grep -v '^$' > docs/service-directory.md && glow docs/service-directory.md

health:
    @bash -c 'echo "Simple Health Status Report for each compose.yml in the stacks directory:"; find stacks -type f -name "compose.yml" -print0 | while IFS= read -r -d "" file; do printf "%s: " "$$file"; if docker-compose -f "$$file" config > /dev/null 2>&1; then echo "HEALTHY"; else echo "UNHEALTHY"; fi; done'
