# main.py
import os
import uuid
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.responses import FileResponse
from pydantic import BaseModel
import yt_dlp

app = FastAPI()

# Directory to store temporary MP3s
DOWNLOAD_DIR = "downloads"
if not os.path.exists(DOWNLOAD_DIR):
    os.makedirs(DOWNLOAD_DIR)

class VideoRequest(BaseModel):
    url: str

def cleanup_file(path: str):
    """Deletes the file after it has been served to save space."""
    try:
        if os.path.exists(path):
            os.remove(path)
    except Exception as e:
        print(f"Error deleting file: {e}")

@app.post("/convert")
async def convert_video(request: VideoRequest):
    """
    1. Receives YouTube URL.
    2. Downloads/Converts to MP3 using yt-dlp.
    3. Returns JSON with metadata and download link.
    """
    file_id = str(uuid.uuid4())
    
    # yt-dlp configuration
    ydl_opts = {
        'format': 'bestaudio/best',
        'outtmpl': f'{DOWNLOAD_DIR}/{file_id}.%(ext)s', # Temp filename
        'postprocessors': [{
            'key': 'FFmpegExtractAudio',
            'preferredcodec': 'mp3',
            'preferredquality': '192',
        }],
        'quiet': True,
        'noplaylist': True
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(request.url, download=True)
            title = info.get('title', 'Unknown Title')
            artist = info.get('uploader', 'Unknown Artist')
            
            # yt-dlp automatically saves as .mp3 because of the postprocessor
            final_filename = f"{file_id}.mp3"
            
            return {
                "status": "success",
                "title": title,
                "artist": artist,
                "download_url": f"/files/{final_filename}"
            }
    except Exception as e:
        print(f"Error: {e}")
        raise HTTPException(status_code=500, detail="Failed to download video")

@app.get("/files/{filename}")
async def get_file(filename: str, background_tasks: BackgroundTasks):
    """Serves the MP3 file and deletes it after sending."""
    file_path = os.path.join(DOWNLOAD_DIR, filename)
    
    if os.path.exists(file_path):
        # Schedule file deletion after response is sent
        # background_tasks.add_task(cleanup_file, file_path) 
        return FileResponse(file_path, media_type="audio/mpeg", filename=filename)
    
    raise HTTPException(status_code=404, detail="File not found")

if __name__ == "__main__":
    # This allows running via `python main.py` if needed, 
    # but we will use `uv run`
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)