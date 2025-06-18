---
name: sparc
description: Execute SPARC methodology workflows with Claude-Flow
---

# SPARC Development Methodology

SPARC (Specification, Pseudocode, Architecture, Refinement, Completion) is a systematic approach to software development integrated with Claude-Flow.

## Available SPARC Modes

- `/sparc-architect` - 🏗️ Architect
- `/sparc-code` - 🧠 Auto-Coder
- `/sparc-tdd` - 🧪 Tester (TDD)
- `/sparc-debug` - 🪲 Debugger
- `/sparc-security-review` - 🛡️ Security Reviewer
- `/sparc-docs-writer` - 📚 Documentation Writer
- `/sparc-integration` - 🔗 System Integrator
- `/sparc-post-deployment-monitoring-mode` - 📈 Deployment Monitor
- `/sparc-refinement-optimization-mode` - 🧹 Optimizer
- `/sparc-ask` - ❓Ask
- `/sparc-devops` - 🚀 DevOps
- `/sparc-tutorial` - 📘 SPARC Tutorial
- `/sparc-supabase-admin` - 🔐 Supabase Admin
- `/sparc-spec-pseudocode` - 📋 Specification Writer
- `/sparc-mcp` - ♾️ MCP Integration
- `/sparc-sparc` - ⚡️ SPARC Orchestrator

## Quick Start

### Run a specific mode:
```bash
npx claude-flow sparc run <mode> "your task"
```

### Execute full TDD workflow:
```bash
npx claude-flow sparc tdd "implement feature"
```

### List all modes:
```bash
npx claude-flow sparc modes
```

## SPARC Workflow

1. **Specification**: Define requirements and constraints
2. **Pseudocode**: Create detailed logic flows
3. **Architecture**: Design system structure
4. **Refinement**: Implement with TDD
5. **Completion**: Integrate and validate

## Memory Integration

Use memory commands to persist context:
```bash
npx claude-flow memory store "spec_requirements" "auth system needs"
npx claude-flow memory query "spec"
```

## Swarm Mode

For complex tasks requiring multiple agents:
```bash
npx claude-flow swarm "complex project" --strategy development --monitor
```

See `/claude-flow-help` for more commands.
