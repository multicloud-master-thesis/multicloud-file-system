# Start from the Python 3.11 image
FROM python:3.11

# Install system packages
RUN apt-get update && apt-get install -y \
    fuse3 \
    libfuse3-dev \
    libfuse-dev \
    fuse-overlayfs

RUN mkdir /mnt/multicloud-fs
RUN mkdir /tmp/rootpath

# Install Poetry
RUN pip install poetry

# Set the working directory
WORKDIR /app

# Copy project files into the Docker image
COPY . /app

# Set execute permission for the main script
RUN chmod +x /app/src/entrypoint.pyx

# Install project dependencies
RUN poetry install