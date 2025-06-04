# DeLoContainers Commands & Guidelines

## Commands
- `just service-map` - Display service directory structure
- `just health` - Check health status of all stacks
- `docker compose -f <stack>/compose.yml up -d` - Start a stack
- `docker compose -f <stack>/compose.yml down` - Stop a stack
- `docker compose -f <stack>/compose.yml logs` - View stack logs
- `mise run up <stack>` - Start a specific stack
- `mise run logs <stack>` - View logs for a stack
- `mise run update <stack>` - Update a stack

## Stack Structure Guidelines
- Each stack should follow template in `scripts/init-stack.sh`
- Stack types: media, ai, proxy, utils
- Each service requires README.md with documentation
- Use environment variables in .env files for configuration
- Follow directory structure: config/, data/, scripts/

## Code Style
- YAML indentation: 2 spaces
- Use standard Docker Compose v3.8+ syntax
- Document ports and configurations in README.md
- Use Traefik labels for service discovery
- Use linuxserver images when possible

## Best Practices
- Always use `docker compose` and never `docker-compose`
- Prefer `compose.yml` over `docker-compose.yml`
- Always perform a `tree` command before beginning your tasks to get an inventory of containers, configs, etc

## Mise Tasks
- Maintain a set of mise tasks to wrap common functionality to make management of my containers frictionless and fun