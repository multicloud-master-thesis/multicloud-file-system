# Start from the Python 3.11 image
FROM python:3.11

# Install system packages
RUN apt-get update && apt-get install -y \
    libfuse2 \
    fuse \
    libfuse-dev

RUN mkdir /tmp/example
RUN mkdir /tmp/rootpath

# Install Poetry
RUN pip install poetry

# Set the working directory
WORKDIR /app

# Copy project files into the Docker image
COPY . /app

# Install project dependencies
RUN poetry install

# Run the project
ENTRYPOINT $(which python) /app/src/main.py -f "/tmp/example"