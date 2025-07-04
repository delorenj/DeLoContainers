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
        # Parse Qdrant host and port from QDRANT_HOST environment variable
        qdrant_host_env = os.getenv("QDRANT_HOST", "http://qdrant:6333")
        if qdrant_host_env.startswith("http://"):
            # Extract host and port from URL format
            qdrant_url_parts = qdrant_host_env.replace("http://", "").split(":")
            qdrant_host = qdrant_url_parts[0]
            qdrant_port = int(qdrant_url_parts[1]) if len(qdrant_url_parts) > 1 else 6333
        elif qdrant_host_env.startswith("https://"):
            # For HTTPS URLs, use the full URL as host and default port
            qdrant_host = qdrant_host_env
            qdrant_port = 443
        else:
            # Assume it's just a hostname
            qdrant_host = qdrant_host_env
            qdrant_port = int(os.getenv("QDRANT_PORT", "6333"))

        config = {
            "vector_store": {
                "provider": "qdrant",
                "config": {
                    "collection_name": "openmemory",
                    "host": qdrant_host,
                    "port": qdrant_port,
                    "api_key": os.getenv("QDRANT_API_KEY"),
                    "embedding_model_dims": 768,
                },
            },
            "llm": {
                "provider": "ollama",
                "config": {
                    "model": "deepseek-r1:70b",
                    "ollama_base_url": "https://ollama.delo.sh",
                    "temperature": 0.1,
                    "max_tokens": 2000,
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
