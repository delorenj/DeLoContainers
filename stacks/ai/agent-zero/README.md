# Agent Zero

Agent Zero is a personal, organic agentic framework that grows and learns with you.

- **GitHub**: [https://github.com/frdel/agent-zero](https://github.com/frdel/agent-zero)
- **Documentation**: [https://github.com/frdel/agent-zero/blob/main/docs/README.md](https://github.com/frdel/agent-zero/blob/main/docs/README.md)
- **Access**: [http://agent-zero.delo.sh](http://agent-zero.delo.sh) (once configured and running)

## Purpose

Agent Zero is designed to be a dynamic, general-purpose personal assistant. It can gather information, execute commands and code, and cooperate with other agent instances. It features persistent memory to learn from past interactions.

## Configuration

- The service is configured via `compose.yml` in this directory.
- Environment variables (e.g., API keys for LLMs) should be managed via the root `.env` file and passed into the container.
- Persistent data for logs, memory, and prompts are stored in Docker volumes.

## Notes

- Ensure that necessary API keys (e.g., OpenAI) are provided as environment variables for full functionality.
- The default Docker image `frdel/agent-zero-run` is used. For specific versions or the Hacking Edition, update the image tag in `compose.yml`.
- The Hacking Edition can be used by changing the image to `frdel/agent-zero-run:hacking`.
