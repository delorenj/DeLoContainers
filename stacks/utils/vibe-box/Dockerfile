# Nerd Dictation Container
FROM python:3.11-slim as builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install nerd-dictation
RUN pip install vosk && \
    git clone https://github.com/ideasman42/nerd-dictation.git /app/nerd-dictation

# Runtime image
FROM python:3.11-slim

# Install runtime dependencies
RUN pip install vosk
RUN apt-get update && apt-get install -y \
    pulseaudio \
    x11-apps \
    libasound2 \
    && rm -rf /var/lib/apt/lists/*

# Copy nerd-dictation from builder
COPY --from=builder /app/nerd-dictation /app/nerd-dictation
WORKDIR /app/nerd-dictation

# Create symlink for easy access
RUN ln -s /app/nerd-dictation/nerd-dictation /usr/local/bin/nerd-dictation

# Configure environment
ENV PULSE_SERVER=unix:/tmp/pulseaudio.socket
ENV DISPLAY=:0

# Create directory for configs
RUN mkdir -p /config

# Entrypoint
ENTRYPOINT ["nerd-dictation"]
