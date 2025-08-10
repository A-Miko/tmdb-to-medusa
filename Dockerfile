FROM python:3.10-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p /app/logs /app/.cache

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD python -c "import os, requests; \
  requests.get(f'https://api.themoviedb.org/3/configuration?api_key={os.environ.get(\"TMDB_API_KEY\")}').raise_for_status(); \
  requests.get(f'{os.environ.get(\"MEDUSA_URL\")}/api/v2/system/status', \
  headers={'X-API-KEY': os.environ.get(\"MEDUSA_API_KEY\")}).raise_for_status()" || exit 1

# Default command
CMD ["python", "tmdb_to_medusa.py"]
