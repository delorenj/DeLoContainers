FROM ghcr.io/delorenj/mcp-base:latest

# Install OpenCode dependencies
USER root
RUN apt-get update && apt-get install -y \
  apache2-utils \
  openssl \
  && rm -rf /var/lib/apt/lists/*

ENV SHELL=/bin/zsh
ENV PNPM_HOME=/root/.local/bin/pnpm
ENV PATH=/root/.local/bin:$PNPM_HOME:$PATH
RUN mise use pnpm@latest -g
RUN mise x -- pnpm setup zsh
RUN mise x -- pnpm i -g opencode-ai@latest

# Create API key generation script
COPY generate-apikey.sh /generate-apikey.sh
RUN chmod +x /generate-apikey.sh

# Create startup script
COPY start-opencode.sh /start-opencode.sh
RUN chmod +x /start-opencode.sh

# Expose the port
EXPOSE 4096

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:4096/health || exit 1

# Default command
CMD ["/start-opencode.sh"]
