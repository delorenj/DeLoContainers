default:
    @just --choose
    
# Print the service map showing compose files and configurations
service-map:
    @tree -L 4 --dirsfirst -F \
        -P "compose.yml|docker-compose.yml|deploy-compose.yml|README.md|*.toml|*.yaml|*.yml" \
        --prune | grep -v '^$' > docs/service-directory.md && glow docs/service-directory.md

health:
    @bash -c 'echo "Simple Health Status Report for each compose.yml in the stacks directory:"; find stacks -type f -name "compose.yml" -print0 | while IFS= read -r -d "" file; do printf "%s: " "$$file"; if docker-compose -f "$$file" config > /dev/null 2>&1; then echo "HEALTHY"; else echo "UNHEALTHY"; fi; done'

# List all services defined in compose.yml files with their human-readable names
# and show a checkmark for running services
list-services:
    @bash -c 'bash scripts/list-services.sh'

# Restart a compose service by bringing it down and up again
# Usage: just restart path/to/compose.yml
restart compose_path:
    @docker compose -f $(compose_path) down
    @docker compose -f $(compose_path) up -d
