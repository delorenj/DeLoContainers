---
name: claude-flow-swarm
description: Coordinate multi-agent swarms for complex tasks
---

# Claude-Flow Swarm Coordination

Swarm mode enables timeout-free multi-agent coordination for complex tasks.

## Basic Usage
```bash
npx claude-flow swarm "your complex task" --strategy <type> [options]
```

## Strategies
- `development` - Code implementation with QA
- `research` - Information gathering
- `analysis` - Data processing
- `testing` - Quality assurance
- `optimization` - Performance tuning
- `maintenance` - System updates

## Common Options
- `--background` - For tasks > 30 minutes
- `--monitor` - Real-time monitoring
- `--parallel` - Enable parallelization
- `--max-agents <n>` - Agent limit
- `--distributed` - Distributed coordination
- `--review` - Enable review process
- `--testing` - Include testing phase
- `--encryption` - Enable encryption
- `--verbose` - Detailed output

## Examples

### Development Swarm
```bash
npx claude-flow swarm "Build e-commerce API" --strategy development --monitor --review
```

### Long-Running Research
```bash
npx claude-flow swarm "Market analysis" --strategy research --background --distributed
```

### Performance Optimization
```bash
npx claude-flow swarm "Optimize codebase" --strategy optimization --testing --parallel
```

## Monitoring
```bash
# Real-time monitoring
npx claude-flow monitor

# Check status
npx claude-flow status
```
