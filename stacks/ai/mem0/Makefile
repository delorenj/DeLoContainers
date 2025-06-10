build:
	docker build -t mem0-api-server .

run_local:
	docker run -p 8000:8000 -v $(shell pwd):/app mem0-api-server --env-file .env

# OpenMemory commands
openmemory-setup:
	cp .env.example .env
	@echo "Please edit .env file and set your OPENAI_API_KEY"

openmemory-start:
	./start-openmemory.sh

openmemory-stop:
	docker compose -f openmemory-compose.yml down

openmemory-restart:
	docker compose -f openmemory-compose.yml down
	./start-openmemory.sh

openmemory-logs:
	docker compose -f openmemory-compose.yml logs -f

.PHONY: build run_local openmemory-setup openmemory-start openmemory-stop openmemory-restart openmemory-logs
