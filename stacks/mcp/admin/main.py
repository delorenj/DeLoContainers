from fastapi import FastAPI, Request, HTTPException, Depends
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
import os
import json
from typing import List, Dict, Optional
import aiofiles
import asyncio

app = FastAPI(title="MCP Admin Dashboard")
templates = Jinja2Templates(directory="templates")

# Configuration
ADMIN_API_KEY = os.getenv("ADMIN_API_KEY", "default-key")
CONFIG_FILE = "/data/mcp_servers.json"

class MCPServer(BaseModel):
    name: str
    url: str
    description: str
    status: str = "unknown"
    enabled: bool = True

class MCPServerCreate(BaseModel):
    name: str
    url: str
    description: str

async def load_servers() -> List[MCPServer]:
    """Load MCP servers from configuration file"""
    try:
        if os.path.exists(CONFIG_FILE):
            async with aiofiles.open(CONFIG_FILE, 'r') as f:
                content = await f.read()
                data = json.loads(content)
                return [MCPServer(**server) for server in data]
    except Exception as e:
        print(f"Error loading servers: {e}")
    
    # Return default servers if file doesn't exist
    return [
        MCPServer(
            name="ffmpeg",
            url="http://mcp-ffmpeg-integrated:8000",
            description="FFmpeg operations for audio/video processing",
            status="active"
        ),
        MCPServer(
            name="trello",
            url="http://mcp-trello:8007",
            description="Trello board management and card operations",
            status="active"
        ),
        MCPServer(
            name="github",
            url="http://mcp-github:8012",
            description="GitHub repository management and operations",
            status="active"
        ),
        MCPServer(
            name="datetime",
            url="http://mcp-datetime:8011",
            description="Date and time utilities and formatting",
            status="active"
        ),
        MCPServer(
            name="context7",
            url="http://mcp-context7:8006",
            description="Context-aware documentation and code analysis",
            status="active"
        ),
        MCPServer(
            name="circleci",
            url="http://mcp-circleci:8008",
            description="CircleCI build management and monitoring",
            status="active"
        )
    ]

async def save_servers(servers: List[MCPServer]):
    """Save MCP servers to configuration file"""
    try:
        os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)
        data = [server.dict() for server in servers]
        async with aiofiles.open(CONFIG_FILE, 'w') as f:
            await f.write(json.dumps(data, indent=2))
    except Exception as e:
        print(f"Error saving servers: {e}")
        raise HTTPException(status_code=500, detail="Failed to save configuration")

def verify_api_key(api_key: str = None):
    """Verify API key for admin access"""
    if api_key != ADMIN_API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API key")
    return True

@app.get("/", response_class=HTMLResponse)
async def dashboard(request: Request):
    """Main dashboard page"""
    servers = await load_servers()
    return templates.TemplateResponse("dashboard.html", {
        "request": request,
        "servers": servers,
        "title": "MCP Admin Dashboard"
    })

@app.get("/api/servers")
async def get_servers():
    """Get all MCP servers"""
    return await load_servers()

@app.post("/api/servers")
async def create_server(server: MCPServerCreate, _: bool = Depends(verify_api_key)):
    """Create a new MCP server"""
    servers = await load_servers()
    
    # Check if server name already exists
    if any(s.name == server.name for s in servers):
        raise HTTPException(status_code=400, detail="Server name already exists")
    
    new_server = MCPServer(**server.dict())
    servers.append(new_server)
    await save_servers(servers)
    
    return new_server

@app.put("/api/servers/{server_name}")
async def update_server(server_name: str, server: MCPServerCreate, _: bool = Depends(verify_api_key)):
    """Update an existing MCP server"""
    servers = await load_servers()
    
    for i, s in enumerate(servers):
        if s.name == server_name:
            servers[i] = MCPServer(**server.dict(), status=s.status, enabled=s.enabled)
            await save_servers(servers)
            return servers[i]
    
    raise HTTPException(status_code=404, detail="Server not found")

@app.delete("/api/servers/{server_name}")
async def delete_server(server_name: str, _: bool = Depends(verify_api_key)):
    """Delete an MCP server"""
    servers = await load_servers()
    
    servers = [s for s in servers if s.name != server_name]
    await save_servers(servers)
    
    return {"message": "Server deleted successfully"}

@app.post("/api/servers/{server_name}/toggle")
async def toggle_server(server_name: str, _: bool = Depends(verify_api_key)):
    """Toggle server enabled/disabled status"""
    servers = await load_servers()
    
    for s in servers:
        if s.name == server_name:
            s.enabled = not s.enabled
            await save_servers(servers)
            return s
    
    raise HTTPException(status_code=404, detail="Server not found")

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "mcp-admin"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
