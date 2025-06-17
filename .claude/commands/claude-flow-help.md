---
name: claude-flow-help
description: Show Claude-Flow commands and usage
---

# Claude-Flow Commands

## Core Commands

### System Management
- `npx claude-flow start` - Start orchestration system
- `npx claude-flow status` - Check system status
- `npx claude-flow monitor` - Real-time monitoring
- `npx claude-flow stop` - Stop orchestration

### Agent Management
- `npx claude-flow agent spawn <type>` - Create new agent
- `npx claude-flow agent list` - List active agents
- `npx claude-flow agent info <id>` - Agent details
- `npx claude-flow agent terminate <id>` - Stop agent

### Task Management
- `npx claude-flow task create <type> "description"` - Create task
- `npx claude-flow task list` - List all tasks
- `npx claude-flow task status <id>` - Task status
- `npx claude-flow task cancel <id>` - Cancel task

### Memory Operations
- `npx claude-flow memory store "key" "value"` - Store data
- `npx claude-flow memory query "search"` - Search memory
- `npx claude-flow memory stats` - Memory statistics
- `npx claude-flow memory export <file>` - Export memory

### SPARC Development
- `npx claude-flow sparc modes` - List SPARC modes
- `npx claude-flow sparc run <mode> "task"` - Run mode
- `npx claude-flow sparc tdd "feature"` - TDD workflow
- `npx claude-flow sparc info <mode>` - Mode details

### Swarm Coordination
- `npx claude-flow swarm "task" --strategy <type>` - Start swarm
- `npx claude-flow swarm "task" --background` - Long-running swarm
- `npx claude-flow swarm "task" --monitor` - With monitoring

## Quick Examples

### Start a development swarm:
```bash
npx claude-flow swarm "Build REST API" --strategy development --monitor
```

### Run TDD workflow:
```bash
npx claude-flow sparc tdd "user authentication"
```

### Store project context:
```bash
npx claude-flow memory store "project_requirements" "e-commerce platform specs"
```
