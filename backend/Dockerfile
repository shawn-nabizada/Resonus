FROM python:3.11-slim-bookworm

# 1. Install FFmpeg (Required for audio conversion)
RUN apt-get update && apt-get install -y ffmpeg && rm -rf /var/lib/apt/lists/*

# 2. Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv

WORKDIR /app

# 3. Copy project definition
COPY pyproject.toml uv.lock ./

# 4. Sync dependencies (creates virtualenv)
RUN uv sync --frozen --no-install-project

# 5. Copy app code
COPY main.py .

# 6. Run app
CMD ["uv", "run", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]