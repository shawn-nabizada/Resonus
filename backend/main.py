import os
import uuid
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.responses import FileResponse
from pydantic import BaseModel
import yt_dlp

app = FastAPI()

DOWNLOAD_DIR = "downloads"
if not os.path.exists(DOWNLOAD_DIR):
    os.makedirs(DOWNLOAD_DIR)

class VideoRequest(BaseModel):
    url: str

def cleanup_file(path: str):
    """Deletes the file from the server to free up space."""
    try:
        if os.path.exists(path):
            os.remove(path)
            print(f"Deleted temporary file: {path}")
    except Exception as e:
        print(f"Error deleting file: {e}")

@app.get("/")
async def read_root():
    return FileResponse('static/index.html')

@app.post("/convert")
async def convert_video(request: VideoRequest):
    file_id = str(uuid.uuid4())
    
    # UPDATED OPTIONS FOR RENDER DEPLOYMENT
    ydl_opts = {
        'format': 'bestaudio/best',
        'outtmpl': f'{DOWNLOAD_DIR}/{file_id}.%(ext)s',
        'writethumbnail': True,
        'postprocessors': [
            {'key': 'FFmpegExtractAudio','preferredcodec': 'mp3','preferredquality': '192'},
            {'key': 'EmbedThumbnail'},
        ],
        'quiet': True,
        'noplaylist': True,
        
        # --- NEW SETTINGS TO BYPASS "SIGN IN" ERROR ---
        # 1. Force IPv4 (YouTube blocks many datacenter IPv6 addresses)
        'source_address': '0.0.0.0', 
        
        # 2. Pretend to be an Android client (less strict bot checks)
        'extractor_args': {
            'youtube': {
                'player_client': ['android', 'web'],
                'player_skip': ['js', 'configs', 'webpage'], 
            }
        },
        # ---------------------------------------------
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(request.url, download=True)
            return {
                "status": "success",
                "title": info.get('title', 'Unknown'),
                "artist": info.get('uploader', 'Unknown'),
                "download_url": f"/files/{file_id}.mp3"
            }
    except Exception as e:
        raise HTTPException(status_code=500, detail="Conversion failed")

@app.get("/files/{filename}")
async def get_file(filename: str, background_tasks: BackgroundTasks):
    file_path = os.path.join(DOWNLOAD_DIR, filename)
    
    if os.path.exists(file_path):
        # 1. Queue the cleanup task to run AFTER the response is sent
        background_tasks.add_task(cleanup_file, file_path)
        
        # 2. Send the file to the iPhone
        return FileResponse(file_path, media_type="audio/mpeg", filename=filename)
    
    raise HTTPException(status_code=404, detail="File not found")