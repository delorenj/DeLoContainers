# OpenCode CLI Wrapper (oc)

A simple command-line wrapper for the OpenCode API server that makes it easy to send prompts to AI models.

## Installation

The wrapper script is already symlinked to your PATH:
```bash
oc --help
```

## Usage

```bash
oc --provider <provider> --model <model> --prompt "<prompt>"
```

### Options

- `--provider, -p <provider>` - AI provider (default: openai)
- `--model, -m <model>` - Model to use (optional, uses provider default)
- `--prompt <prompt>` - The prompt to send (required)
- `--url, -u <url>` - OpenCode server URL (default: http://localhost:4096)
- `--verbose, -v` - Show verbose output
- `--help, -h` - Show help message

### Available Providers

- **openai** - OpenAI models (requires OPENAI_API_KEY)
- **deepseek** - DeepSeek models (requires DEEPSEEK_API_KEY)
  - `deepseek-chat` (default)
  - `deepseek-reasoner`
- **anthropic** - Anthropic Claude models (requires ANTHROPIC_API_KEY)

## Examples

### Simple query with default provider
```bash
oc --prompt "What is 2+2?"
```

### Using DeepSeek
```bash
oc --provider deepseek --model deepseek-chat --prompt "Explain Docker in one sentence"
```

### Omit model to use provider default
```bash
oc --provider deepseek --prompt "List 5 programming languages"
```

### Verbose mode to see request details
```bash
oc --provider deepseek --prompt "Hello" --verbose
```

## Requirements

- OpenCode server must be running (`docker compose up -d` in the opencode directory)
- Required API keys must be configured in the Docker environment
- `jq` must be installed for JSON parsing

## Troubleshooting

If you get "No providers configured" error, make sure the required API keys are set in your `.env` file and the container has been restarted.

## Debug Mode

For debugging, you can use the `oc-debug` script to see raw JSON responses:
```bash
/home/delorenj/docker/stacks/ai/opencode/oc-debug deepseek deepseek-chat "Your prompt"
```