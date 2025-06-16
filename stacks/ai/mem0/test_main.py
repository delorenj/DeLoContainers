import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch, MagicMock

# Adjust the import path according to the actual location of main.py relative to the test file
# Assuming main.py is in the same directory or accessible via Python path
from stacks.ai.mem0.main import app, MEMORY_INSTANCE as app_memory_instance

# It's good practice to re-assign the global MEMORY_INSTANCE for tests if it's imported directly
# However, FastAPI TestClient usually works with the app instance as loaded.
# For robust mocking, we'll patch 'stacks.ai.mem0.main.MEMORY_INSTANCE'

@pytest.fixture
def client():
    return TestClient(app)

@pytest.fixture
def mock_memory_instance():
    with patch('stacks.ai.mem0.main.MEMORY_INSTANCE', new_callable=MagicMock) as mock_instance:
        # Ensure .add, .get_all, .search methods are also MagicMock and return a suitable response
        mock_instance.add.return_value = {"status": "success", "id": "new_mem_id"}
        mock_instance.get_all.return_value = [{"id": "mem1", "text": "memory1"}]
        mock_instance.search.return_value = [{"id": "mem2", "text": "searched_memory"}]
        yield mock_instance

def test_get_all_memories_with_classification_filters(client, mock_memory_instance):
    # Test with project_id
    response = client.get("/memories?user_id=test_user&project_id=proj1")
    assert response.status_code == 200
    mock_memory_instance.get_all.assert_called_with(
        user_id="test_user", filters={"metadata.project_id": "proj1"}
    )

    # Test with memory_lifespan
    response = client.get("/memories?user_id=test_user&memory_lifespan=short_term")
    assert response.status_code == 200
    mock_memory_instance.get_all.assert_called_with(
        user_id="test_user", filters={"metadata.memory_lifespan": "short_term"}
    )

    # Test with memory_category
    response = client.get("/memories?user_id=test_user&memory_category=skill_procedural")
    assert response.status_code == 200
    mock_memory_instance.get_all.assert_called_with(
        user_id="test_user", filters={"metadata.memory_category": "skill_procedural"}
    )

    # Test with a single domain_tag
    response = client.get("/memories?user_id=test_user&domain_tag=python")
    assert response.status_code == 200
    mock_memory_instance.get_all.assert_called_with(
        user_id="test_user", filters={"metadata.domain_tags": ["python"]}
    )

    # Test with multiple domain_tags
    response = client.get("/memories?user_id=test_user&domain_tag=python&domain_tag=fastapi")
    assert response.status_code == 200
    mock_memory_instance.get_all.assert_called_with(
        user_id="test_user", filters={"metadata.domain_tags": ["python", "fastapi"]}
    )

    # Test with a combination of filters
    response = client.get("/memories?user_id=test_user&project_id=proj2&memory_category=informational")
    assert response.status_code == 200
    mock_memory_instance.get_all.assert_called_with(
        user_id="test_user", filters={"metadata.project_id": "proj2", "metadata.memory_category": "informational"}
    )

    # Test with only a filter and no main identifier (user_id, agent_id, run_id)
    # This relies on the updated validation in get_all_memories
    response = client.get("/memories?project_id=proj_only")
    assert response.status_code == 200
    mock_memory_instance.get_all.assert_called_with(
        filters={"metadata.project_id": "proj_only"}
    )


def test_search_memories_with_classification_filters(client, mock_memory_instance):
    search_payload = {
        "query": "find skills",
        "user_id": "test_user",
        "filters": {
            "metadata.memory_category": "skill_procedural",
            "metadata.project_id": "proj_skill"
        }
    }
    response = client.post("/search", json=search_payload)
    assert response.status_code == 200
    mock_memory_instance.search.assert_called_with(
        query="find skills",
        user_id="test_user",
        filters={
            "metadata.memory_category": "skill_procedural",
            "metadata.project_id": "proj_skill"
        }
    )

def test_create_memory_with_classification_metadata(client, mock_memory_instance):
    memory_payload = {
        "messages": [{"role": "user", "content": "learn this new skill"}],
        "user_id": "test_user",
        "metadata": {
            "project_id": "proj_alpha",
            "memory_lifespan": "long_term",
            "memory_category": "skill_procedural",
            "domain_tags": ["coding", "python"],
            "custom_key": "custom_value"
        }
    }
    response = client.post("/memories", json=memory_payload)
    assert response.status_code == 200
    # FastAPI/Pydantic will pass through the full metadata dict
    mock_memory_instance.add.assert_called_with(
        messages=[{"role": "user", "content": "learn this new skill"}],
        user_id="test_user",
        metadata={
            "project_id": "proj_alpha",
            "memory_lifespan": "long_term",
            "memory_category": "skill_procedural",
            "domain_tags": ["coding", "python"],
            "custom_key": "custom_value"
        }
    )

# It might be useful to add a test for the .env loading and DEFAULT_CONFIG new keys,
# but that's harder to unit test without further refactoring main.py for testability
# of its global config setup. For now, focusing on API endpoint behavior.
