# CRUSH.md

## Build, Lint, and Test Commands

### Build
To build the project, make sure Docker is installed. Use Docker Compose to build and run the services:
```bash
# Build and start the services
docker-compose -f compose.yml up --build
```

### Lint
Run code linting:
```bash
# Placeholder for the actual lint command. Adjust as needed.
npm run lint
```

### Test
Run unit tests:
```bash
# Placeholder for the actual test command. Adjust as needed.
npm test
```

To run a single test, use:
```bash
# Adjust this to how tests are structured in the project
npm test -- path/to/test/file.test.js
```

## Code Style Guidelines

### General
- **Naming Conventions**: Use camelCase for variable names and PascalCase for class names.
- **Formatting**: Follow standard JS formatting (Prettier is often used in JS projects).
- **Imports**: Organize imports in the following order: built-in modules, third-party modules, local modules.

### Error Handling
- Always handle errors in asynchronous operations using `try-catch` or `.catch()`.

### Dependencies
- Install only necessary dependencies and prefer lightweight alternatives when possible.

### Additional Instructions
- No Cursor or Copilot rules found in this repository.
