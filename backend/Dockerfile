# Use a lightweight Python Linux image
FROM python:3.11-slim-bookworm

# 1. Install FFmpeg AND Node.js
RUN apt-get update && \
    apt-get install -y ffmpeg nodejs && \
    rm -rf /var/lib/apt/lists/*

# 2. Install 'uv' package manager
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv

WORKDIR /app

# 3. Copy project dependency files
COPY pyproject.toml uv.lock ./

# 4. Install dependencies
RUN uv sync --frozen --no-install-project

# 5. Copy app code
COPY static ./static
COPY main.py .

# 6. Expose port 8000
EXPOSE 8000

# 7. Start the server
CMD ["uv", "run", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]