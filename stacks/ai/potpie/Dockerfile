FROM python:3.10-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Environment variables
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1

# Note: Actual API keys will be passed from docker-compose
# These are just placeholders
ENV OPENROUTER_API_KEY=""
ENV OPENAI_API_KEY=""
ENV ANTHROPIC_API_KEY=""
ENV LLM_PROVIDER=""
ENV LLM_API_KEY=""
ENV LOW_REASONING_MODEL=""
ENV HIGH_REASONING_MODEL=""

# Command to run the application
CMD ["gunicorn", "--worker-class", "uvicorn.workers.UvicornWorker", "--workers", "1", "--timeout", "1800", "--bind", "0.0.0.0:8001", "--log-level", "debug", "app.main:app"]
