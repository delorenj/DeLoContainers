# PostgreSQL Service

This PostgreSQL instance is configured for the IdealScenario project's web crawler component.

## Configuration

- **Version**: PostgreSQL 15 (Alpine-based)
- **Port**: 5432
- **Database**: todp
- **Default User**: postgres
- **Default Password**: postgres

## Volumes

- `./data`: Persistent storage for PostgreSQL data
- `./config`: Custom PostgreSQL configuration files

## Health Check

The service includes a health check that verifies database availability:
- Interval: 10s
- Timeout: 5s
- Retries: 5

## Usage with Crawler

This PostgreSQL instance is configured to match the crawler's `.env.example` settings:
```
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/todp
```

## Updates & Changes

| Date       | Change                              |
|------------|-------------------------------------|
| YYYY-MM-DD | Initial setup with PostgreSQL 15    |
