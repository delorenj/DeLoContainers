import os
import sys

# Set stdin to /dev/null to avoid interactive prompts
sys.stdin = open("/dev/null", "r")

from mem0 import Memory


memory_client = None


def get_memory_client(custom_instructions: str = None):
    """
    Get or initialize the Mem0 client.

    Args:
        custom_instructions: Optional instructions for the memory project.

    Returns:
        Initialized Mem0 client instance.

    Raises:
        Exception: If required API keys are not set.
    """
    global memory_client

    if memory_client is not None:
        return memory_client

    try:
        # Get host and port from environment variables with fallbacks
        qdrant_host = os.getenv("QDRANT_HOST", "host.docker.internal")
        qdrant_port = int(os.getenv("QDRANT_PORT", "6333"))

        # Get LLM model from environment or use default
        llm_model = os.getenv("MEM0_OPENROUTER_MODEL", "deepseek/deepseek-chat")

        config = {
            "vector_store": {
                "provider": "qdrant",
                "config": {
                    "collection_name": "openmemory",
                    "host": qdrant_host,
                    "port": qdrant_port,
                    "embedding_model_dims": 768,
                },
            },
            "llm": {
                "provider": "openrouter",
                "config": {
                    "model": llm_model,
                    "api_key": os.getenv("OPENROUTER_API_KEY"),
                    "base_url": "https://openrouter.ai/api/v1",
                    "temperature": 0.7,
                    "max_tokens": 4096,
                },
            },
            "embedder": {
                "provider": "ollama",
                "config": {
                    "model": "nomic-embed-text:latest",
                    "ollama_base_url": "https://ollama.delo.sh",
                },
            },
        }

        memory_client = Memory.from_config(config_dict=config)
    except Exception as e:
        print(f"Error initializing memory client: {e}")
        raise Exception(f"Exception occurred while initializing memory client: {e}")

    # Update project with custom instructions if provided
    if custom_instructions:
        memory_client.update_project(custom_instructions=custom_instructions)

    return memory_client


def get_default_user_id():
    return os.getenv("defaultUsername", "default-user")
