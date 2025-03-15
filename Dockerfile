# Build stage
FROM debian:bookworm AS builder

# Install Python 3.11 and build dependencies
RUN apt-get update && apt-get install -y \
    python3.11 \
    python3.11-dev \
    python3-pip \
    python3-venv \
    python3-poetry \
    fuse3 \
    libfuse3-dev \
    libfuse-dev \
    build-essential \
    pkg-config

# Set working directory
WORKDIR /app

# Copy project files
COPY . /app

# Install dependencies and build executable
RUN poetry install --no-root
RUN poetry run python setup.py build_ext --inplace
RUN poetry run pyinstaller multicloud_fs.spec

# Runtime stage - use same Debian version
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    fuse3 \
    libfuse3-3 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p /mnt/multicloud-fs /tmp/rootpath

# Copy the executable from builder stage
COPY --from=builder /app/dist/multicloud_fs /usr/local/bin/

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/multicloud_fs"]