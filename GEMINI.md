# GEMINI.md

## Project Overview

This repository, DeLoContainers, is a collection of Docker containers organized into stacks for various purposes. The project is designed to be a personal cloud, providing a variety of services from AI to media management. The stacks are managed by Docker Compose, and the project includes a `justfile` for easy automation of common tasks.

The core of the project is the `stacks` directory, which contains the different service stacks. Each stack has its own `compose.yml` file and can be enabled or disabled via the `stack-config.yml` file. The project also includes a `core` directory for essential services like a reverse proxy (Traefik) and a Docker management UI (Portainer).

## Key Files

*   `README.md`: The main entry point for understanding the project. It provides a high-level overview of the directory structure, stacks, and basic commands.
*   `justfile`: Contains a set of commands for automating common tasks, such as building a service map, checking the health of services, and restarting services.
*   `stack-config.yml`: The main configuration file for the Docker stacks. It allows you to enable or disable stacks, set their priority, and provide a brief description.
*   `docs/service-directory.md`: A detailed guide to all the services in the project. It provides a description of each service, its purpose, and its location.
*   `docs/stack-monitoring.md`: Documentation for the automated stack monitoring system.

## Building and Running

The project uses a `justfile` to automate common tasks. Here are some of the most important commands:

*   `just build-service-map`: Generates a service directory in markdown format, which is useful for understanding the project structure.
*   `just health`: Provides a simple health status report for each `compose.yml` file in the `stacks` directory.
*   `just list-services`: Lists all services defined in `compose.yml` files.
*   `just restart <compose_path>`: Restarts a specific Docker Compose service.

To get started with the project, you should first copy `.env.example` to `.env` and configure your environment variables. Then, you can use the `just` commands to manage the stacks.

## Development Conventions

The project follows a clear and consistent structure. Each stack is contained in its own directory within the `stacks` directory. Each stack has its own `compose.yml` file and can be configured via the `stack-config.yml` file.

To add a new service, you should create a new directory in the `stacks` directory and add a `compose.yml` file. Then, you should add an entry for the new service in the `stack-config.yml` file.

The project also includes a `docs` directory for documentation. If you add a new service, you should also add a description of the service to the `docs/service-directory.md` file.
