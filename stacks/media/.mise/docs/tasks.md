# Project Tasks

This document lists all available mise tasks for this project.

## Build Tasks

### `build:build`

**Usage:** `mise run build:build`

### `build:down`

**Usage:** `mise run build:down`

### `build:external`

**Usage:** `mise run build:external`

### `build:prod`

**Usage:** `mise run build:prod`

### `build:pull`

**Usage:** `mise run build:pull`

### `build:up`

**Usage:** `mise run build:up`

### `build:web`

**Usage:** `mise run build:web`

## Deploy Tasks

### `deploy:logs`

Show logs for all media services using docker-compose logs -f

**Usage:** `mise run deploy:logs`

### `deploy:stop`

Stop all media services using docker-compose down

**Usage:** `mise run deploy:stop`

### `deploy:update`

Update all media service images using docker-compose pull

**Usage:** `mise run deploy:update`

## Dev Tasks

### `dev:dev`

**Usage:** `mise run dev:dev`

### `dev:restart`

Restart all media services by stopping and starting them

**Usage:** `mise run dev:restart`

### `dev:start`

Start all media services (Prowlarr, qBittorrent, Gluetun) using docker-compose up -d

**Usage:** `mise run dev:start`

