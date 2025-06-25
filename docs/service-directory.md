---
tags:
  - project
  - AI
  - DevOps
category: Project
description: The DeLoContainer project organizes services into directories managed via Docker Compose, including core services, AI workflows, media processing, DevOps, monitoring, and persistence solutions.
title: DeLoContainer Service Directory Overview
updated: 2025-06-21 13:06:45
created: 2025-06-03
---
> [!zk 20250621130544142-0] DeLoContainer Service Directory Overview
> Main concepts and ideas: The DeLoContainer project organizes services into directories managed via Docker Compose. Core services include Portainer for Docker management, Traefik for HTTP reverse proxying, and Traefik Frontend for web app routing. Other services include FFmpeg MCP Server for media conversion, AI services like Firecrawl and Flowise, DevOps services like GoCD, media services like Exportarr, monitoring, persistence solutions like CouchDB and Qdrant, and utility services like AdGuard and Syncthing. Connections to other concepts: These services connect to Docker, microservices, AI workflows, media processing, data persistence, and automation. Possible applications: Deploying and managing microservices, automating workflows, processing media, analyzing data, and ensuring system monitoring and security.

# DeLoContainer Service Directory

The DeLoContainer project is organized into several directories, each containing services that are managed using Docker Compose. This guide provides an overview of each service and its purpose.

## Core Services

### Portainer
- **Path:** `core/portainer/compose.yml`
- **Description:** Portainer is a lightweight management UI that allows you to easily manage your Docker environments. It provides a simple and easy-to-use interface for managing containers, images, networks, and volumes.

### Traefik
- **Path:** `core/traefik/compose.yml`
- **Description:** Traefik is a modern HTTP reverse proxy and load balancer that makes deploying microservices easy. It automatically discovers services and provides dynamic routing, SSL termination, and more.

### Traefik Frontend
- **Path:** `core/traefik-frontend/compose.yml`
- **Description:** This service is an extension of Traefik, focusing on frontend configurations and routing rules for web applications.

## FFmpeg MCP Server

- **Path:** `ffmpeg-mcp-server/docker-compose.yml`
- **Description:** This service provides a media conversion platform using FFmpeg, a powerful multimedia framework for handling video, audio, and other multimedia files and streams.

## Stacks

### AI

#### Firecrawl
- **Path:** `stacks/ai/firecrawl/compose.yml`
- **Description:** Firecrawl is an AI-powered web crawling service designed to extract and process data from websites efficiently.

#### Flowise
- **Path:** `stacks/ai/flowise/compose.yml`
- **Description:** Flowise is a service for building and deploying AI workflows, enabling automation and integration of AI models into business processes.

#### Graphiti
- **Path:** `stacks/ai/graphiti/compose.yml`
- **Description:** Graphiti is a graph-based data processing service that allows for complex data analysis and visualization.

#### Langflow
- **Path:** `stacks/ai/langflow/docker-compose.yml`
- **Description:** Langflow is a natural language processing service that provides tools for language understanding and generation.

#### Letta
- **Path:** `stacks/ai/letta/compose.yml`
- **Description:** Letta is an AI service focused on text analysis and sentiment detection, providing insights into textual data.

#### Litellm
- **Path:** `stacks/ai/litellm/compose.yml`
- **Description:** Litellm is a lightweight language model service for generating and understanding human-like text.

#### Mem0
- **Path:** `stacks/ai/mem0/compose.yml`
- **Description:** Mem0 is a memory-optimized AI service designed for efficient data processing and storage.

#### N8n
- **Path:** `stacks/ai/n8n/compose.yml`
- **Description:** N8n is a workflow automation tool that allows you to connect various services and automate tasks.

### DevOps

#### GoCD
- **Path:** `stacks/devops/gocd/compose.yml`
- **Description:** GoCD is a continuous delivery server that helps automate the build, test, and release processes of software.

### Media

#### Exportarr
- **Path:** `stacks/media/exportarr/compose.yml`
- **Description:** Exportarr is a media export service that facilitates the transfer and conversion of media files.

#### Media Stack
- **Path:** `stacks/media/compose.yml`
- **Description:** This is a general media stack configuration for managing and processing media content.

### Monitoring

- **Path:** `stacks/monitoring/compose.yml`
- **Description:** This service provides monitoring capabilities for the entire infrastructure, ensuring system health and performance.

### Persistence

#### CouchDB
- **Path:** `stacks/persistence/couchdb/compose.yml`
- **Description:** CouchDB is a NoSQL database service that provides a scalable and flexible data storage solution.

#### Qdrant
- **Path:** `stacks/persistence/qdrant/compose.yml`
- **Description:** Qdrant is a vector similarity search engine that allows for efficient searching and retrieval of high-dimensional data.

#### Persistence Stack
- **Path:** `stacks/persistence/compose.yml`
- **Description:** This is a general persistence stack configuration for managing data storage solutions.

### Utils

#### AdGuard
- **Path:** `stacks/utils/adguard/compose.yml`
- **Description:** AdGuard is a network-wide ad blocker that provides privacy protection and ad filtering.

#### Audiojangler
- **Path:** `stacks/utils/audiojangler/compose.yml`
- **Description:** Audiojangler is a service for managing and processing audio files, offering features like conversion and editing.

#### Marker
- **Path:** `stacks/utils/marker/compose.yml`
- **Description:** Marker is a utility service for marking and annotating data, useful for data analysis and processing.

#### Rustdesk
- **Path:** `stacks/utils/rustdesk/compose.yml`
- **Description:** Rustdesk is a remote desktop service that allows for secure and efficient remote access to systems.

#### Scripts
- **Path:** `stacks/utils/scripts/compose.yml`
- **Description:** This service provides a collection of utility scripts for automating various tasks and processes.

#### Syncthing
- **Path:** `stacks/utils/syncthing/compose.yml`
- **Description:** Syncthing is a continuous file synchronization program that synchronizes files between two or more computers in real-time.

---

This guide provides a high-level overview of the services within the DeLoContainer project. Each service is configured using Docker Compose, allowing for easy deployment and management.
