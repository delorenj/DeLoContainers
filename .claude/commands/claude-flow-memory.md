---
name: claude-flow-memory
description: Interact with Claude-Flow memory system
---

# Claude-Flow Memory System

The memory system provides persistent storage for cross-session and cross-agent collaboration.

## Store Information
```bash
npx claude-flow memory store "key" "value" --namespace project
```

## Query Memory
```bash
npx claude-flow memory query "search term" --limit 10
```

## Memory Statistics
```bash
npx claude-flow memory stats
```

## Export/Import
```bash
npx claude-flow memory export backup.json
npx claude-flow memory import backup.json
```

## Namespaces
- `default` - General storage
- `agents` - Agent-specific data
- `tasks` - Task information
- `sessions` - Session history
- `swarm` - Swarm coordination data
- `project` - Project-specific context

## Best Practices
- Use descriptive keys
- Organize with namespaces
- Regular backups with export
- Clean old data periodically
