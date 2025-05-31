FROM multicloud-fs:0.1.0 AS provider

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    python3 \
    python3-setuptools \
    python3-redis \
    python3-grpcio \
    python3-protobuf \
    python3-grpc-tools \
    redis-tools \
    fuse3 \
    libfuse3-3 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY . /app/

RUN wget -O /app/csi.proto https://raw.githubusercontent.com/container-storage-interface/spec/master/csi.proto && \
    python3 -m grpc.tools.protoc \
    --proto_path=/app \
    --python_out=/app \
    --grpc_python_out=/app \
    /app/csi.proto

RUN chmod +x /app/cmd/driver.py

COPY --from=provider /usr/local/bin/multicloud_fs /usr/local/bin/

ENTRYPOINT ["python3", "/app/cmd/driver.py"]