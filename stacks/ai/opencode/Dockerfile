FROM oven/bun:1.2.14-alpine

# Install required dependencies
RUN apk add --no-cache \
    curl \
    git \
    bash \
    nodejs \
    npm \
    tar \
    gzip

# Set working directory
WORKDIR /app

# Copy opencode source code
COPY libs/opencode/ /app/

# Install dependencies
RUN bun install

# Build the project if needed
RUN bun run typecheck || true

# Create a simple health check endpoint wrapper
RUN echo '#!/bin/sh' > /usr/local/bin/health-check && \
    echo 'curl -f http://localhost:${OPENCODE_PORT:-4096}/openapi >/dev/null 2>&1' >> /usr/local/bin/health-check && \
    chmod +x /usr/local/bin/health-check

# Create startup script
COPY stacks/ai/opencode/start-opencode.sh /start-opencode.sh
RUN chmod +x /start-opencode.sh

# Expose the port
EXPOSE 4096

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD /usr/local/bin/health-check || exit 1

# Default command
CMD ["/start-opencode.sh"]