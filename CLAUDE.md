# DeLoContainers

DeLoContainers is a collection of Docker containers that I use for my personal projects. It is designed to be modular and easy to use, allowing me to quickly and easily deploy and manage a variety of services.

## Stack Structure Guidelines

- Stacks are organized by service rough category (e.g., media, ai, utils.)
- Containers that add to the service container ecosystem should be placed in an appropriate stack (e.g., ./stacks/ai/ for AI-related services)
- Containers that support the DeLoContainers project and infrastructure should be placed in the ./core/ directory (e.g., Traefik, Portainer, etc.)
- Favor sharing resources between containers to reduce redundancy and improve efficiency (e.g., opt for a new db in the postgres stack rather than creating a new one postgres container for each service)
- Default to exposing all services via traefik docker labels with the following naming convention: `service-name.delo.sh`
- Each service should have an accurate yet humorous and snarky fun-to-read README.md with documentation
- There is a single shared .env file in the root of the project that contains all environment variables for the containers.
- When a new secret is required that isn't already in the .env file, you can most likely find it in ~/.config/zshyzsh/secrets.zsh (or already exported in your shell)
- Utilize `mise` tasks to wrap common functionality and make management of containers frictionless and fun
- Use scripts SPARINGLY.
- All docker compose files should be named `compose.yml`
- NEVER start the compose file with a `version:` key, as it is not required in v3.8+ syntax
- Every service should be a part of the `proxy` network to ensure they can communicate with each other and be accessed via Traefik

## Code Style

- YAML indentation: 2 spaces
- Use standard Docker Compose v3.8+ syntax
- Document ports and configurations in README.md
- Use Traefik labels for service discovery
- Use linuxserver images when possible
  This project uses the SPARC (Specification, Pseudocode, Architecture, Refinement, Completion) methodology for systematic Test-Driven Development with AI assistance through Claude-Flow orchestration.

## SPARC Development Commands

This project uses the SPARC (Specification, Pseudocode, Architecture, Refinement, Completion) methodology for systematic Test-Driven Development with AI assistance through Claude-Flow orchestration.

### Core SPARC Commands

- `npx claude-flow sparc modes`: List all available SPARC development modes
- `npx claude-flow sparc run <mode> "<task>"`: Execute specific SPARC mode for a task
- `npx claude-flow sparc tdd "<feature>"`: Run complete TDD workflow using SPARC methodology
- `npx claude-flow sparc info <mode>`: Get detailed information about a specific mode

### Standard Build Commands

- `npm run build`: Build the project
- `npm run test`: Run the test suite
- `npm run lint`: Run linter and format checks
- `npm run typecheck`: Run TypeScript type checking

## DeLoContainer Workflow

1. Github Research

- Search for existing Docker containers that meet the requirements of the project.
- Check for existing Dockerfiles, docker-compose files, and documentation.
- Look for conversations and issues related to the container.
- Take into consideration possible alternatives to the container proposed by the user.
- Consider using a different container if it is more suitable for the project.

2. Stack Integration

- If using an existing container, clone the repository into ~/code/ and follow the instructions in the README.md file.
- If repo files need to be present, either copy them to the ~/docker/stacks/<stack_name>/<container_name>/ directory or create a new stack for the container.
- If the stack category is getting sufficiently large, consider splitting it into multiple stacks.
- Customize the `compose.yml` file to fit the needs of the project.
- Link the .env to the project root's .env.
- Configure the container with necessary environment variables and settings.

## Important Notes
