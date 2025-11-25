
# Resonus

Resonus is a small music app project that includes a backend API and an iOS SwiftUI frontend. The backend serves audio and metadata; the frontend is an iOS app (Swift / SwiftUI) that plays, edits, and manages a local library.

## Features

- **Music Library:** Import, list, and manage songs in a library.
- **Playback:** Play, pause, seek, and navigate tracks with a full player UI.
- **Metadata Editing:** Edit song details (title, artist, album, etc.).
- **Streaming API:** Backend serves audio files and exposes REST endpoints for library and playback control.
- **Docker-ready Backend:** Run the backend quickly using `docker-compose`.
- **iOS SwiftUI Frontend:** Native frontend located in `frontend/` using SwiftUI and an Xcode project.

## Tech stack

- Backend: Python, FastAPI, Docker support.
- Frontend: iOS app in Swift + SwiftUI.

## How to run

The backend is deployed on Render (free tier). Note: Render will spin the service down after a period of inactivity (approximately 15 minutes). When the service is spun down, the next incoming request will cause Render to start the instance again — expect a cold-start delay on the first request after idle. Point the frontend to the deployed base URL (for example `https://your-app.onrender.com`) and replace that placeholder with the actual Render URL for this project.

### Run the iOS frontend (Xcode)

1. Open the Xcode project located at `frontend/frontend.xcodeproj`.
2. Select a simulator or a connected device, then build & run from Xcode.

Notes
- For active backend development you may still run the backend locally (see files under `backend/`), but for normal usage the deployed Render service should be sufficient.
- If the deployed URL changes, update the frontend configuration to point to the new base URL.
