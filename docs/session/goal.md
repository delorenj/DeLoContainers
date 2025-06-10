# Goal

Add AnyLLM as a new ./stacks/ai/ container in the stack.

## Requirements

1. The container should be named `anyllm`.
2. Follow the install guide and recommendations from the [AnyLLM documentation](./docs/session/anyllm-docs.md)
3. Traefik should route <https://ai.delo.sh> to the AnyLLM container.
4. Any .env configuration should be complete using the secrets available in `/home/delorenj/.config/zshyzsh/secrets.zsh`
