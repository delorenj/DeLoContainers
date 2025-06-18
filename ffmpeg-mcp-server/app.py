from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import subprocess
import os
from typing import Optional
from fastapi_mcp import FastApiMCP, MCPTool

app = FastAPI(title="FFmpeg MCP Server")

class AudioExtractionRequest(BaseModel):
    infile: str
    outfile: str
    quality: Optional[int] = 2  # Default quality setting (VBR quality 2 - high quality)
    format: Optional[str] = "mp3"  # Default output format

@app.post("/extract-audio/", operation_id="extract_audio")
@MCPTool(
    name="extract-audio",
    description="Extract audio from a video file using FFmpeg"
)
async def extract_audio(request: AudioExtractionRequest):
    """
    Extract audio from a video file using FFmpeg.
    
    Parameters:
    - infile: Path to the input video file (relative to mounted volume)
    - outfile: Path for the output audio file (relative to mounted volume)
    - quality: Audio quality (1-5, where 1 is best quality, 5 is lowest)
    - format: Output audio format (mp3, aac, etc.)
    
    Returns:
    - Details about the extraction process
    """
    # Validate input file exists
    if not os.path.exists(f"/config/{request.infile}"):
        raise HTTPException(status_code=404, detail=f"Input file not found: {request.infile}")
    
    # Prepare output directory if it doesn't exist
    outdir = os.path.dirname(f"/config/{request.outfile}")
    if outdir and not os.path.exists(outdir):
        os.makedirs(outdir)
    
    # Determine audio codec based on format
    codec_map = {
        "mp3": "libmp3lame",
        "aac": "aac",
        "opus": "libopus",
        "flac": "flac",
        "wav": "pcm_s16le"
    }
    
    codec = codec_map.get(request.format.lower(), "libmp3lame")
    
    # Build FFmpeg command
    cmd = [
        "docker", "run", "--rm",
        "-v", f"{os.path.expanduser('~')}:/config",
        "linuxserver/ffmpeg",
        "-i", f"/config/{request.infile}",
        "-vn",  # No video
        "-acodec", codec
    ]
    
    # Add quality parameter based on format
    if request.format.lower() == "mp3":
        cmd.extend(["-q:a", str(request.quality)])
    elif request.format.lower() == "aac":
        cmd.extend(["-b:a", f"{128 + (5-request.quality)*64}k"])  # Adjust bitrate based on quality
    else:
        # Default quality setting for other formats
        cmd.extend(["-q:a", str(request.quality)])
    
    # Add output file
    cmd.append(f"/config/{request.outfile}")
    
    try:
        # Run FFmpeg command
        process = subprocess.run(
            cmd,
            check=True,
            capture_output=True,
            text=True
        )
        
        # Check if output file was created
        if not os.path.exists(f"/config/{request.outfile}"):
            raise HTTPException(status_code=500, detail="Failed to create output file")
        
        return {
            "status": "success",
            "infile": request.infile,
            "outfile": request.outfile,
            "format": request.format,
            "quality": request.quality,
            "message": "Audio extraction completed successfully"
        }
    except subprocess.CalledProcessError as e:
        raise HTTPException(status_code=500, detail=f"FFmpeg error: {e.stderr}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error: {str(e)}")

# Create and mount the MCP server
mcp = FastApiMCP(
    app,
    name="FFmpeg MCP Server",
    description="MCP server for FFmpeg operations like audio extraction"
)
mcp.mount()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
