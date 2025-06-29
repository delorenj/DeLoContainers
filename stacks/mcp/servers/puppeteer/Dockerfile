FROM python:3.13-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    wget \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Clone the puppeteer repository
RUN git clone https://github.com/delorenj/mcp-server-puppeteer-py.git .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 8002

CMD ["python", "puppeteer.py"]
