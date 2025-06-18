# FFmpeg MCP Server

A FastAPI-based MCP server that provides FFmpeg functionality as tools for AI assistants.

## Features

- Extract audio from video files
- Configurable audio quality and format
- Exposed as MCP tools for AI assistants

## Setup

### Prerequisites

- Docker
- Docker Compose

### Installation

1. Clone this repository
2. Build and start the service:

```bash
docker-compose up -d
```

## Usage

### MCP Configuration

Add this to your MCP configuration:

```json
{
  "mcpServers": {
    "ffmpeg-mcp-server": {
      "url": "http://localhost:8765/mcp"
    }
  }
}
```

### Available Tools

#### extract-audio

Extracts audio from a video file.

Parameters:
- `infile`: Path to the input video file (relative to mounted volume)
- `outfile`: Path for the output audio file (relative to mounted volume)
- `quality`: Audio quality (1-5, where 1 is best quality, 5 is lowest)
- `format`: Output audio format (mp3, aac, etc.)

Example:
```
extract-audio with parameters:
{
  "infile": "videos/input.mkv",
  "outfile": "audio/output.mp3",
  "quality": 2,
  "format": "mp3"
}
```

## API Documentation

When the server is running, you can access the API documentation at:

- Swagger UI: http://localhost:8765/docs
- ReDoc: http://localhost:8765/redoc

## License

MIT
