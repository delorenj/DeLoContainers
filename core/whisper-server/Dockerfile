FROM debian:bookworm-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    cmake \
    git \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Copy pre-built whisper.cpp binaries and libraries
COPY --from=build /tmp/whisper.cpp/build/bin/whisper-server /usr/local/bin/whisper-server
COPY --from=build /tmp/whisper.cpp/build/lib/* /usr/local/lib/
COPY --from=build /tmp/whisper.cpp/build/ggml/src/*.so* /usr/local/lib/

# Set library path
ENV LD_LIBRARY_PATH=/usr/local/lib

# Create models directory
RUN mkdir -p /models

EXPOSE 58080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:58080/ || exit 1

ENTRYPOINT ["/usr/local/bin/whisper-server"]
CMD ["--host", "0.0.0.0", "--port", "58080", "-t", "8", "-nt", "-m", "/models/ggml-base.en.bin"]
