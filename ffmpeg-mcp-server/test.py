import requests
import json
import sys

def test_extract_audio(infile, outfile):
    """Test the extract-audio endpoint"""
    url = "http://localhost:8765/extract-audio/"
    
    payload = {
        "infile": infile,
        "outfile": outfile,
        "quality": 2,
        "format": "mp3"
    }
    
    headers = {
        "Content-Type": "application/json"
    }
    
    print(f"Sending request to extract audio from {infile} to {outfile}...")
    response = requests.post(url, json=payload, headers=headers)
    
    print(f"Status code: {response.status_code}")
    print(json.dumps(response.json(), indent=2))

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python test.py <infile> <outfile>")
        print("Example: python test.py '2025-06-17 12-07-37.mkv' 'extracted_audio.mp3'")
        sys.exit(1)
    
    test_extract_audio(sys.argv[1], sys.argv[2])
