from fastapi import FastAPI, HTTPException, Request, Depends, Header
from fastapi.responses import JSONResponse
import httpx
import os
import json
from typing import Optional, Dict, Any
import asyncio

app = FastAPI(title="MCP Proxy Server")

# Configuration
API_KEY = os.getenv("API_KEY", "default-key")
ADMIN_URL = os.getenv("ADMIN_URL", "http://mcp-admin-dashboard:8000")

async def verify_api_key(x_api_key: Optional[str] = Header(None)):
    """Verify API key for proxy access"""
    if x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid or missing API key")
    return True

async def get_servers() -> Dict[str, str]:
    """Get server configuration from admin service"""
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(f"{ADMIN_URL}/api/servers")
            if response.status_code == 200:
                servers = response.json()
                return {
                    server["name"]: server["url"] 
                    for server in servers 
                    if server.get("enabled", True)
                }
    except Exception as e:
        print(f"Error fetching servers: {e}")
    
    # Fallback configuration
    return {
        "ffmpeg": "http://mcp-ffmpeg-integrated:8000",
        "trello": "http://mcp-trello:8007",
        "github": "http://mcp-github:8012",
        "datetime": "http://mcp-datetime:8011",
        "context7": "http://mcp-context7:8006",
        "circleci": "http://mcp-circleci:8008"
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "mcp-proxy"}

@app.get("/servers")
async def list_servers(_: bool = Depends(verify_api_key)):
    """List available MCP servers"""
    servers = await get_servers()
    return {"servers": list(servers.keys())}

@app.api_route("/{server_name}/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def proxy_request(
    server_name: str,
    path: str,
    request: Request,
    _: bool = Depends(verify_api_key)
):
    """Proxy requests to MCP servers"""
    servers = await get_servers()
    
    if server_name not in servers:
        raise HTTPException(
            status_code=404, 
            detail=f"Server '{server_name}' not found. Available servers: {list(servers.keys())}"
        )
    
    server_url = servers[server_name]
    target_url = f"{server_url}/{path}"
    
    # Get request body
    body = await request.body()
    
    # Prepare headers (exclude host and content-length)
    headers = {
        key: value for key, value in request.headers.items()
        if key.lower() not in ["host", "content-length", "x-api-key"]
    }
    
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.request(
                method=request.method,
                url=target_url,
                headers=headers,
                content=body,
                params=request.query_params
            )
            
            # Return the response
            return JSONResponse(
                content=response.json() if response.headers.get("content-type", "").startswith("application/json") else response.text,
                status_code=response.status_code,
                headers={
                    key: value for key, value in response.headers.items()
                    if key.lower() not in ["content-length", "transfer-encoding"]
                }
            )
            
    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail="Server timeout")
    except httpx.ConnectError:
        raise HTTPException(status_code=503, detail=f"Cannot connect to server '{server_name}'")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Proxy error: {str(e)}")

@app.get("/{server_name}")
async def server_info(server_name: str, _: bool = Depends(verify_api_key)):
    """Get information about a specific MCP server"""
    servers = await get_servers()
    
    if server_name not in servers:
        raise HTTPException(
            status_code=404, 
            detail=f"Server '{server_name}' not found. Available servers: {list(servers.keys())}"
        )
    
    server_url = servers[server_name]
    
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            # Try to get server info/health
            for endpoint in ["/", "/health", "/info"]:
                try:
                    response = await client.get(f"{server_url}{endpoint}")
                    if response.status_code == 200:
                        return {
                            "server": server_name,
                            "url": server_url,
                            "status": "online",
                            "info": response.json() if response.headers.get("content-type", "").startswith("application/json") else response.text
                        }
                except:
                    continue
            
            return {
                "server": server_name,
                "url": server_url,
                "status": "online",
                "info": "Server is reachable but no info endpoint available"
            }
            
    except Exception as e:
        return {
            "server": server_name,
            "url": server_url,
            "status": "offline",
            "error": str(e)
        }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
