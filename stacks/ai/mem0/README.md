# Mem0 REST API Server

Mem0 provides a REST API server (written using FastAPI). Users can perform all operations through REST endpoints. The API also includes OpenAPI documentation, accessible at `/docs` when the server is running.

## Features

- **Create memories:** Create memories based on messages for a user, agent, or run. Memories can be enriched with `metadata` including fields like `project_id`, `memory_lifespan` (e.g., "short_term", "long_term"), `memory_category` (e.g., "informational", "skill_procedural"), and `domain_tags` (e.g., `["python", "fastapi"]`) for classification.
- **Retrieve memories:** Get all memories for a given user, agent, or run. Memories can be filtered by `project_id`, `memory_lifespan`, `memory_category`, and `domain_tags` using query parameters.
- **Search memories:** Search stored memories based on a query. The search can be refined using the `filters` parameter in the request body, allowing filtering on metadata fields like `metadata.project_id`, `metadata.memory_category`, etc. (e.g., `{"metadata.project_id": "proj123"}`).
- **Update memories:** Update an existing memory.
- **Delete memories:** Delete a specific memory or all memories for a user, agent, or run.
- **Reset memories:** Reset all memories for a user, agent, or run.
- **OpenAPI Documentation:** Accessible via `/docs` endpoint.

## Configuration

The Mem0 API server can be configured using environment variables. Some notable configuration options include:

- `MEM0_DEFAULT_SHORT_TERM_TTL_SECONDS`: Specifies the default time-to-live (in seconds) for memories classified with a "short_term" lifespan. Defaults to `3600` (1 hour).
- `MEM0_USE_GRAPH_FOR_CATEGORIES`: A comma-separated list of `memory_category` values for which interactions with a graph store might be prioritized or specialized (e.g., "skill_procedural"). Defaults to an empty string.

These settings allow for more fine-grained control over memory management and behavior.

## Running the server

Follow the instructions in the [docs](https://docs.mem0.ai/open-source/features/rest-api) to run the server.
