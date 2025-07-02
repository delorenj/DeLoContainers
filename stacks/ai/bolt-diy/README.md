# Bolt.DIY Stack

Bolt.DIY is an AI-powered web development assistant that helps you build full-stack applications using natural language prompts.

## Services

- **bolt-diy**: Main application service
  - **URL**: https://bolt.delo.sh
  - **Port**: 5173
  - **Description**: AI-powered web development assistant

## Features

- Natural language to code generation
- Full-stack application development
- Multiple AI model support (OpenAI, Anthropic, Groq, etc.)
- Real-time code editing and preview
- GitHub integration
- Docker containerized deployment

## Environment Variables

The service uses environment variables from your secrets configuration:

- `GROQ_API_KEY`: Groq API key for fast inference
- `HF_TOKEN`: HuggingFace API key
- `OPENROUTER_API_KEY`: OpenRouter API key (used as OpenAI key)
- `ANTHROPIC_API_KEY`: Anthropic Claude API key
- `GEMINI_API_KEY`: Google Generative AI API key
- `XAI_API_KEY`: xAI API key
- `TOGETHER_API_KEY`: Together AI API key
- `DEEPSEEK_API_KEY`: DeepSeek API key
- `PERPLEXITY_API_KEY`: Perplexity API key
- `GITHUB_PERSONAL_ACCESS_TOKEN`: GitHub access token for repository operations

## Usage

1. Start the stack:
   ```bash
   cd /home/delorenj/docker/stacks/ai/bolt-diy
   docker compose up -d
   ```

2. Access the application at https://bolt.delo.sh

3. Start building applications using natural language prompts!

## Configuration

- **Context Window**: Set to 32768 tokens for large context support
- **Ollama Integration**: Connected to your Ollama instance at https://ollama.delo.sh
- **GitHub Integration**: Automatic authentication using your personal access token
- **Logging**: Debug level logging enabled for development

## Building from Source

The container builds from your local bolt.diy repository at:
`/home/delorenj/code/agentic-coders/bolt.diy`

To rebuild after code changes:
```bash
docker compose build --no-cache
docker compose up -d
```

## Troubleshooting

- Check logs: `docker compose logs -f bolt-diy`
- Verify environment variables are set correctly
- Ensure all API keys are valid and have sufficient credits
- Check network connectivity to external AI services
