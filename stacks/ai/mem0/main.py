import os
from fastapi import FastAPI, HTTPException, Query, Path
from fastapi.responses import JSONResponse, RedirectResponse
from pydantic import BaseModel, Field
from typing import Optional, List, Any, Dict
from mem0 import Memory
from dotenv import load_dotenv

import logging

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")

# Load environment variables
load_dotenv()


POSTGRES_HOST = os.environ.get("POSTGRES_HOST", "postgres")
POSTGRES_PORT = os.environ.get("POSTGRES_PORT", "5432")
POSTGRES_DB = os.environ.get("MEM0_POSTGRES_DB", "mem0")
POSTGRES_USER = os.environ.get("POSTGRES_USER", "postgres")
POSTGRES_PASSWORD = os.environ.get("POSTGRES_PASSWORD", "postgres")
POSTGRES_COLLECTION_NAME = os.environ.get("MEM0_POSTGRES_COLLECTION_NAME", "memories")

NEO4J_URI = os.environ.get("NEO4J_URI", "bolt://neo4j:7687")
NEO4J_USERNAME = os.environ.get("NEO4J_USER", "neo4j")
NEO4J_PASSWORD = os.environ.get("NEO4J_PASSWORD", "mem0graph")

MEMGRAPH_URI = os.environ.get("MEMGRAPH_URI", "bolt://localhost:7687")
MEMGRAPH_USERNAME = os.environ.get("MEMGRAPH_USERNAME", "memgraph")
MEMGRAPH_PASSWORD = os.environ.get("MEMGRAPH_PASSWORD", "mem0graph")

OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY")
HISTORY_DB_PATH = os.environ.get("HISTORY_DB_PATH", "/app/history/history.db")

# New environment variable loaders for memory management
MEM0_DEFAULT_SHORT_TERM_TTL_SECONDS = int(os.environ.get("MEM0_DEFAULT_SHORT_TERM_TTL_SECONDS", "3600"))
_use_graph_for_categories_str = os.environ.get("MEM0_USE_GRAPH_FOR_CATEGORIES", "")
MEM0_USE_GRAPH_FOR_CATEGORIES = [
    item.strip() for item in _use_graph_for_categories_str.split(',') if item.strip()
]

DEFAULT_CONFIG = {
    "version": "v1.1",
    "vector_store": {
        "provider": "pgvector",
        "config": {
            "host": POSTGRES_HOST,
            "port": int(POSTGRES_PORT),
            "dbname": MEM0_POSTGRES_DB,
            "user": POSTGRES_USER,
            "password": POSTGRES_PASSWORD,
            "collection_name": MEM0_POSTGRES_COLLECTION_NAME,
        }
    },
    "graph_store": {
        "provider": "neo4j",
        "config": {
            "url": NEO4J_URI,
            "username": NEO4J_USER,
            "password": NEO4J_PASSWORD
        }
    },
    "llm": {
        "provider": "openai",
        "config": {
            "api_key": OPENAI_API_KEY,
            "temperature": 0.2,
            "model": "gpt-4o"
        }
    },
    "embedder": {
        "provider": "openai",
        "config": {
            "api_key": OPENAI_API_KEY,
            "model": "text-embedding-3-small"
        }
    },
    "history_db_path": HISTORY_DB_PATH,
    "memory_management": {
        "default_short_term_ttl_seconds": MEM0_DEFAULT_SHORT_TERM_TTL_SECONDS,
        "use_graph_for_categories": MEM0_USE_GRAPH_FOR_CATEGORIES,
    },
}


MEMORY_INSTANCE = Memory.from_config(DEFAULT_CONFIG)

app = FastAPI(
    title="Mem0 REST APIs",
    description="A REST API for managing and searching memories for your AI Agents and Apps.",
    version="1.0.0",
)


class Message(BaseModel):
    role: str = Field(..., description="Role of the message (user or assistant).")
    content: str = Field(..., description="Message content.")


class MemoryCreate(BaseModel):
    messages: List[Message] = Field(..., description="List of messages to store.")
    user_id: Optional[str] = None
    agent_id: Optional[str] = None
    run_id: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = Field(
        None,
        description=(
            "Optional metadata for the memory. Examples of classification keys: "
            "'project_id' (str), 'memory_lifespan' (e.g., 'short_term', 'long_term'), "
            "'memory_category' (e.g., 'informational', 'skill_procedural'), "
            "'domain_tags' (e.g., ['python', 'fastapi']), "
            "and 'expires_at' (timestamp for short-term memories)."
        )
    )


class SearchRequest(BaseModel):
    query: str = Field(..., description="Search query.")
    user_id: Optional[str] = None
    run_id: Optional[str] = None
    agent_id: Optional[str] = None
    filters: Optional[Dict[str, Any]] = Field(
        None,
        description=(
            "Filters to apply to the search. Can be used to filter on metadata fields "
            "like 'metadata.project_id', 'metadata.memory_category', etc. "
            "Example: {'metadata.project_id': 'proj123', 'metadata.memory_category': 'skill_procedural'}"
        )
    )


@app.post("/configure", summary="Configure Mem0")
def set_config(config: Dict[str, Any]):
    """Set memory configuration."""
    global MEMORY_INSTANCE
    MEMORY_INSTANCE = Memory.from_config(config)
    return {"message": "Configuration set successfully"}


@app.post("/memories", summary="Create memories")
def add_memory(memory_create: MemoryCreate):
    """Store new memories."""
    if not any([memory_create.user_id, memory_create.agent_id, memory_create.run_id]):
        raise HTTPException(
            status_code=400, detail="At least one identifier (user_id, agent_id, run_id) is required."
        )

    params = {k: v for k, v in memory_create.model_dump().items() if v is not None and k != "messages"}
    try:
        response = MEMORY_INSTANCE.add(messages=[m.model_dump() for m in memory_create.messages], **params)
        return JSONResponse(content=response)
    except Exception as e:
        logging.exception("Error in add_memory:")  # This will log the full traceback
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/memories", summary="Get memories")
def get_all_memories(
    user_id: Optional[str] = None,
    run_id: Optional[str] = None,
    agent_id: Optional[str] = None,
    project_id: Optional[str] = Query(None, description="Filter memories by project ID."),
    memory_lifespan: Optional[str] = Query(None, description="Filter memories by lifespan (e.g., 'short_term', 'long_term')."),
    memory_category: Optional[str] = Query(None, description="Filter memories by category (e.g., 'informational', 'skill_procedural')."),
    domain_tag: Optional[List[str]] = Query(None, description="Filter memories by domain tags (match any specified tag).")
):
    """Retrieve stored memories."""
    if not any([user_id, run_id, agent_id, project_id, memory_lifespan, memory_category, domain_tag]):
        # Adjusted condition to allow calls if only new filters are present, though mem0py might require user/agent/run_id
        # However, the original check for at least one of user_id, run_id, agent_id should probably remain
        # For now, let's assume mem0.get_all can handle filters without user/agent/run_id if that's the case,
        # or that the user is expected to provide one of them anyway.
        # Reinstating original check and extending it:
        pass # Let's keep the original check for user_id, run_id, agent_id for now.

    if not any([user_id, run_id, agent_id]) and not any([project_id, memory_lifespan, memory_category, domain_tag]):
         raise HTTPException(status_code=400, detail="At least one identifier (user_id, agent_id, run_id) or filter (project_id, memory_lifespan, memory_category, domain_tag) is required.")


    try:
        params = {k: v for k, v in {"user_id": user_id, "run_id": run_id, "agent_id": agent_id}.items() if v is not None}

        filters_dict = {}
        if project_id:
            filters_dict["metadata.project_id"] = project_id
        if memory_lifespan:
            filters_dict["metadata.memory_lifespan"] = memory_lifespan
        if memory_category:
            filters_dict["metadata.memory_category"] = memory_category
        if domain_tag: # Assuming mem0 library handles list of tags for "metadata.domain_tags"
            filters_dict["metadata.domain_tags"] = domain_tag

        if filters_dict:
            return MEMORY_INSTANCE.get_all(filters=filters_dict, **params)
        else:
            return MEMORY_INSTANCE.get_all(**params)

    except Exception as e:
        logging.exception("Error in get_all_memories:")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/memories/{memory_id}", summary="Get a memory")
def get_memory(memory_id: str):
    """Retrieve a specific memory by ID."""
    try:
        return MEMORY_INSTANCE.get(memory_id)
    except Exception as e:
        logging.exception("Error in get_memory:")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/search", summary="Search memories")
def search_memories(search_req: SearchRequest):
    """Search for memories based on a query."""
    try:
        params = {k: v for k, v in search_req.model_dump().items() if v is not None and k != "query"}
        return MEMORY_INSTANCE.search(query=search_req.query, **params)
    except Exception as e:
        logging.exception("Error in search_memories:")
        raise HTTPException(status_code=500, detail=str(e))


@app.put("/memories/{memory_id}", summary="Update a memory")
def update_memory(memory_id: str, updated_memory: Dict[str, Any]):
    """Update an existing memory."""
    try:
        return MEMORY_INSTANCE.update(memory_id=memory_id, data=updated_memory)
    except Exception as e:
        logging.exception("Error in update_memory:")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/memories/{memory_id}/history", summary="Get memory history")
def memory_history(memory_id: str):
    """Retrieve memory history."""
    try:
        return MEMORY_INSTANCE.history(memory_id=memory_id)
    except Exception as e:
        logging.exception("Error in memory_history:")
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/memories/{memory_id}", summary="Delete a memory")
def delete_memory(memory_id: str):
    """Delete a specific memory by ID."""
    try:
        MEMORY_INSTANCE.delete(memory_id=memory_id)
        return {"message": "Memory deleted successfully"}
    except Exception as e:
        logging.exception("Error in delete_memory:")
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/memories", summary="Delete all memories")
def delete_all_memories(
    user_id: Optional[str] = None,
    run_id: Optional[str] = None,
    agent_id: Optional[str] = None,
):
    """Delete all memories for a given identifier."""
    if not any([user_id, run_id, agent_id]):
        raise HTTPException(status_code=400, detail="At least one identifier is required.")
    try:
        params = {k: v for k, v in {"user_id": user_id, "run_id": run_id, "agent_id": agent_id}.items() if v is not None}
        MEMORY_INSTANCE.delete_all(**params)
        return {"message": "All relevant memories deleted"}
    except Exception as e:
        logging.exception("Error in delete_all_memories:")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/reset", summary="Reset all memories")
def reset_memory():
    """Completely reset stored memories."""
    try:
        MEMORY_INSTANCE.reset()
        return {"message": "All memories reset"}
    except Exception as e:
        logging.exception("Error in reset_memory:")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/", summary="Redirect to the OpenAPI documentation", include_in_schema=False)
def home():
    """Redirect to the OpenAPI documentation."""
    return RedirectResponse(url='/docs')
