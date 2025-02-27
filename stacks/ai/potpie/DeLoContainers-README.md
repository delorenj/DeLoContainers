# PotPie AI Framework

## Overview
PotPie is an AI-powered code understanding and agent framework deployed as part of the DeLoNET infrastructure's AI stack.

## Version Information
- **Deployment Date:** February 26, 2025
- **Version:** Latest from main branch
- **Environment:** Development

## Configuration Details

### Container Services
- **momentum:** Main PotPie application service
- **postgres:** PostgreSQL database for application data
- **redis:** Message broker and caching
- **neo4j:** Graph database for code relationships

### Network Configuration
- **Internal Network:** ai_network
- **Exposed Ports:** 
  - 8001 (Main API)
  - 5432 (PostgreSQL)
  - 7474, 7687 (Neo4j)
  - 6379 (Redis)

### Environment Variables
- Development mode enabled
- Default user: delorenj
- OpenRouter API integration for AI models
- Containerized database connections

## Usage Instructions

### API Endpoints
Primary interaction through RESTful API:
- `/api/v1/conversations/` - Manage conversations
- `/api/v1/parse` - Parse codebases
- `/api/v1/conversations/{conversation_id}/message/` - Send messages
- `/api/v1/project/{project_id}/message/` - Project-based messaging

### Database Access
- PostgreSQL: Connect via `docker-compose exec postgres psql -U postgres -d momentum`
- Neo4j: Access via browser at `http://localhost:7474` (credentials: neo4j/admin123)

## Maintenance Notes

### Updates
- Pull latest from GitHub repository
- Rebuild containers with `docker-compose build`
- Update environment variables as needed

### Backups
- PostgreSQL data persisted in named volume
- Neo4j data persisted in named volume

## Known Issues
- Development mode bypasses authentication
- Frontend configuration incomplete

## Future Enhancements
1. Configure full authentication system
2. Set up Firebase integration
3. Configure GitHub OAuth
4. Explore agent capabilities

## Related Documentation
- [Firebase Setup](./docs/FIREBASE_SETUP.md)
- [GitHub Authentication](./docs/GITHUB_AUTH.md)
- [Official PotPie Documentation](https://docs.potpie.ai)

*Last Updated: February 26, 2025*
