# Grok-L Coherence Platform
# Multi-stage build for optimized deployment

FROM python:3.11-slim as builder

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    make \
    cmake \
    libssl-dev \
    libffi-dev \
    libsndfile1 \
    ffmpeg \
    libopencv-dev \
    python3-opencv \
    && rm -rf /var/lib/apt/lists/*

# Create working directory
WORKDIR /build

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Production stage
FROM python:3.11-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libsndfile1 \
    ffmpeg \
    libopencv-dev \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Create app user for security
RUN useradd -m -u 1000 grokl && \
    mkdir -p /app /data /logs && \
    chown -R grokl:grokl /app /data /logs

# Copy Python packages from builder
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Set working directory
WORKDIR /app

# Copy application code
COPY --chown=grokl:grokl ./core /app/core
COPY --chown=grokl:grokl ./api /app/api

# Switch to non-root user
USER grokl

# Environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    GROKL_ENV=production \
    LOG_LEVEL=info

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8000/api/v1/health')"

# Expose API port
EXPOSE 8000

# Start the application
CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]
