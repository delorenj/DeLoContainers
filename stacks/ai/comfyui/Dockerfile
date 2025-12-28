FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

# Install Python and dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-dev \
    python3-pip \
    git \
    wget \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Install uv
RUN pip3 install uv

# Create app directory
WORKDIR /app

# Copy ComfyUI source
COPY . /app/

# Install dependencies
RUN uv pip install --system torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu128
RUN uv pip install --system -r requirements.txt

# Create directories for persistent data
RUN mkdir -p /app/models /app/output /app/input /app/custom_nodes

# Expose port
EXPOSE 8188

# Run ComfyUI
CMD ["python3", "main.py", "--listen", "0.0.0.0", "--port", "8188"]
