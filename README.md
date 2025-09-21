# Multicloud File System (FS) and CSI Driver

A distributed, POSIX-like filesystem for compute clusters, backed by local disks on each node, coordinated via Redis,
exposed to applications either directly (FUSE mount) or through a Kubernetes CSI driver.

---

## Contents

- Overview and features
- Architecture
    - Filesystem (FUSE + gRPC + Redis + cache)
    - CSI driver (Controller + Node + Sidecars)
- Requirements
- Local development and running the FS
- Building Docker images
- Running on Kubernetes
    - Helm chart (recommended)
    - Quickstart with kind
    - Apply raw manifests
    - Validate with test pods
- Running with Hyperflow WMS
- Configuration reference
- Project layout
- Contributing and development notes

---

## Overview and features

- POSIX-like filesystem implemented with FUSE (fuse-python) in Python/Cython.
- Distributed reads/writes across nodes via gRPC; metadata coordination through Redis.
- Per-node caching with in-memory and on-disk tiers for fast reads and reduced network traffic.
- Kubernetes CSI driver to provision and mount the FS into pods as PersistentVolumes.
- Simple, explicit data placement model: file replicas are kept on nodes that accessed or wrote the data; location info
  tracked in Redis.

---

## Architecture

### Filesystem (FUSE + gRPC + Redis + cache)

Core components (see `src/`):

- FUSE server (`file_system.pyx`, class `MultiCloudFS`): services filesystem operations.
- Node-local gRPC server (`grpc_server.pyx`): exposes low-level file ops on the node’s local root directory to other
  nodes.
- gRPC client manager (`grpc_client_manager.pyx`): tracks cluster peers from Redis and proxies remote calls.
- Redis metadata client (`redis_client.pyx`): stores metadata and directory entries; tracks per-file node locations.
- Cache manager (`cache_manager.pyx`): two-tier cache (RAM + disk), with eviction callbacks to keep Redis locations in
  sync.
- Entrypoint (`entrypoint.pyx`): starts the gRPC server, initializes clients, registers files/host in Redis, then runs
  the FUSE main loop.

Startup flow (simplified):

1) Start node-local gRPC server listening on `{host_ip}:{port}`.
2) Register this node in Redis set `hosts` and connect to known hosts.
3) Scan the node’s `root_path` to publish metadata and locations in Redis.
4) Start FUSE mounted at `mount_path`.

Operation flow highlights:

- getattr/readdir: prefer local disk; fallback to remote node(s) via gRPC if needed; keep Redis metadata fresh.
- read: check cache -> local disk -> remote read via gRPC; cache small files (<= 4 MiB) in memory, otherwise on disk
  cache.
- write/truncate/create/mkdir/unlink/rmdir/rename: perform locally; propagate metadata updates to Redis;
  opportunistically attempt remote propagation when applicable.
- Redis keys (logical view):
    - `hosts` (set): all participating node URLs.
    - `inode:/path` (hash): file stat-like metadata plus `locations` (semicolon-delimited list of node URLs with a
      copy/cached copy).
    - `dir:/path` (set): directory entries.

Caching (defaults from `cache_manager.pyx`):

- In-memory cache: up to 64 MiB total; only files up to 4 MiB stored in RAM.
- On-disk cache: up to 1 GiB at `${MULTICLOUD_FS_DISK_CACHE:-/tmp/multicloudfs_cache}`.
- On eviction, this node removes itself from Redis `locations` for the evicted path.

gRPC API (see `proto/multicloud_fs.proto`):

- Supports Exists, GetAttr, ReadDir, Read (single response), ReadFile (streaming), Write, Truncate, Chown, Chmod,
  Unlink, Rmdir, Rename, Access, Utimens, Mkdir, Create.

CLI (entrypoint):

- Required: `-r/--root_path`, `-p/--port`, `-f/--mount_path`, `-u/--redis_url`.
- Optional: `-i/--host_ip` (default `localhost`), `-d/--debug`, `-s/--single`.

### CSI driver (Controller + Node + Sidecars)

Components (see `csi/pkg/driver`):

- Identity service: reports driver name `csi.multicloud.fs` and version.
- Controller service: implements Create/Delete/Publish/Unpublish and tracks volumes in Redis (key space under `csi:*`).
  Deploys with sidecars: csi-provisioner and csi-attacher. Controller pod also runs a Redis instance by default.
- Node service: stages/publishes volumes. It launches a node-level `multicloud_fs` mount inside the plugin container (
  unless `SKIP_NODE_MOUNT=true`) and bind-mounts that into pods on `NodePublishVolume`.
- Multicloud client (`csi/pkg/multicloud/client.py`):
    - Starts `multicloud_fs` with:
      `-f /shared/multicloud_fs -r /var/lib/multicloud/root -p 5000 -u <redis> -i <node-ip>`.
    - Publishes volumes by `mount --bind /shared/multicloud_fs <target_path>`.

K8s deployment (see `csi/deploy` and Helm chart in `charts/multicloud-csi`):

- Controller: Deployment with Redis + CSI sidecars + controller plugin.
- Node: DaemonSet with node-driver-registrar and the plugin. Requires privileged mode and mountPropagation for kubelet
  directories and `/var/lib/multicloud` host path.
- CSIDriver object: `csi.multicloud.fs`.
- StorageClass: `multicloud-csi-sc`.

---

## Requirements

- OS: Linux or macOS
    - macOS: install macFUSE
    - Linux: FUSE3 runtime; for dev builds also libfuse headers
- Python: 3.11 (see `.python-version`)
- Package manager: Poetry
- Redis: reachable by every node (local dev can use Dockerized Redis)
- Docker: to build and run container images
- Kubernetes (for CSI): modern cluster; for local testing: kind
- Helm 3 (optional, for chart install)

---

## Local development and running the FS

You need a running Redis instance and a mount point directory. If your platform doesn’t match the prebuilt extension
modules in `src/` (e.g., different OS/arch/Python), you must compile the Cython extensions before running.

1) Install deps

```bash
poetry install
```

2) Compile Cython extensions (required unless matching prebuilt *.so are present)

```bash
poetry run python setup.py build_ext --inplace
```

3) Start Redis (example via Docker)

```bash
docker run --name redis -p 6379:6379 -d redis:7.4.2
```

4) Run the filesystem

```bash
# Example values; adjust paths/ports to your environment
poetry run python src/main.py \
  -f /path/to/mountpoint \
  -r /path/to/local/root \
  -p 5000 \
  -u redis://localhost:6379 \
  -i 127.0.0.1
```

5) Optional: Build a self-contained executable (PyInstaller)

```bash
poetry run pyinstaller multicloud_fs.spec
# Then run it:
./dist/multicloud_fs -f /path/to/mountpoint -r /path/to/local/root -p 5000 -u redis://localhost:6379 -i 127.0.0.1
```

6) Terminate the filesystem when done, it should unmount automatically. **Remember to exit the mounted directory**, the
   automatic umount will fail if you don't, and you will need to unmount manually:

- Linux: `fusermount -u /path/to/mountpoint` (or `umount`)
- macOS: `umount /path/to/mountpoint`

Notes

- Ensure the mount point exists and you have permissions to mount FUSE filesystems.
- For multi-node tests on one machine, run multiple instances with distinct `-r`, `-f`, `-p`, and `-i`, all pointing to
  the same Redis. Make sure that for each instance the environment variable for the cache directory
  (MULTICLOUD_FS_DISK_CACHE) is set to a different path.

---

## Building Docker images

Container images

- FS image (provider for CSI image stage and usable standalone):

```bash
# From repo root
docker build -t multicloud-fs:0.1.0 .
```

- CSI driver image (includes the FS binary from the provider stage):

```bash
# From repo root, building the CSI image from csi/
cd csi
docker build -t multicloud-csi-driver:0.1.0 .
```

---

## Running on Kubernetes

### Helm chart (recommended)

A minimal Helm chart is provided in `charts/multicloud-csi`.

```bash
helm install multicloud-csi charts/multicloud-csi \
  --create-namespace \
  --namespace multicloud-system \
  --set images.csiPlugin.repository=multicloud-csi-driver \
  --set images.csiPlugin.tag=0.1.0
```

Values you may want to override (see `charts/multicloud-csi/values.yaml`):

- `namespace`: default `multicloud-system`
- `images.csiPlugin.*`, `images.nodeDriverRegistrar.*`, `images.redis.*`, `images.controllerCsiProvisioner.*`,
  `images.controllerCsiAttacher.*`
- `storageClass.name`: default `multicloud-csi-sc`

### Quickstart with kind

A helper script is provided:

```bash
# This will (re)create a kind cluster named "multicloud",
# load the CSI image, and apply the manifests + test pods
cd csi
bash run.sh
```

What it does

- Creates kind cluster from `kind-config.yaml` (one control-plane, two workers).
- Loads `multicloud-csi-driver:0.1.0` into the kind nodes.
- Applies: namespace, CSIDriver, RBAC, controller, node, StorageClass, and test pods.

### Apply raw manifests

If you prefer manual steps:

```bash
# Build and load images (for kind example)
# docker build -t multicloud-csi-driver:0.1.0 csi/
# kind load docker-image multicloud-csi-driver:0.1.0 --name multicloud

kubectl apply -f csi/deploy/namespace.yaml
kubectl apply -f csi/deploy/csi-driver.yaml
kubectl apply -f csi/deploy/rbac.yaml
kubectl apply -f csi/deploy/controller.yaml
kubectl apply -f csi/deploy/node.yaml
kubectl apply -f csi/deploy/storageclass.yaml
```

### Validate with test pods

Two test pods/pvcs are provided, each pinned to a different worker (see `csi/deploy/testpod.yaml`).

```bash
kubectl apply -f csi/deploy/testpod.yaml
# After pods are Running, exec into a pod and try I/O
kubectl exec -n default -it test-pod -- sh -lc 'echo hello > /data/hello.txt && ls -l /data && cat /data/hello.txt'
```

Behind the scenes

- The Node plugin starts a node-level FS mount (`/shared/multicloud_fs`) inside the plugin container.
- On NodePublishVolume, it bind-mounts that path into the pod’s target path.
- Data and metadata get distributed via the FS’s gRPC/Redis mechanisms.

Cleanup

```bash
kubectl delete -f csi/deploy/testpod.yaml
kubectl delete ns multicloud-system
```

---

## Running with Hyperflow WMS

This filesystem was developed primary for use with [Hyperflow WMS](https://github.com/hyperflow-wms/hyperflow) (it can
probably be used with any other WMS if configured
appropriately) and its [k8s deployment](https://github.com/hyperflow-wms/hyperflow-k8s-deployment).

To run the FS with Hyperflow WMS, you need to:

1) Disable the nfs-server-provisioner in the `hyperflow-ops` chart, for example by adding the following:

```yaml
# charts/hyperflow-ops/values.yaml
nfs-server-provisioner:
  enabled: false
```

```yaml
# charts/hyperflow-ops/Chart.yaml
- name: nfs-server-provisioner
  repository: https://kubernetes-sigs.github.io/nfs-ganesha-server-and-external-provisioner
  version: 1.6.*
  condition: nfs-server-provisioner.enabled
```

2) Install the hyperflow-ops (from the hyperflow repository) and multicloud-fs chart (from this repository). To make it
   easier just add it as a dependency to the hyperflow-ops chart.

3) Disable nfs-volume in the `hyperflow-run` chart, for example by adding the following:

```yaml
# charts/hyperflow-run/values.yaml
nfs-volume:
  enabled: false
```

```yaml
# charts/hyperflow-run/Chart.yaml
- name: nfs-volume
  repository: file://../nfs-volume
  version: 0.*
  condition: nfs-volume.enabled
```

4) Install the hyperflow-run (from the hyperflow repository).

5) (Optional) For monitoring, install official prometheus and grafana helm charts and import the dashboard from
   `dashboards/hyperdlow-grafana-dashboard.json`.`

---

## Configuration reference

Filesystem binary (`multicloud_fs` / `src/main.py`):

- `-f, --mount_path`: mountpoint in the host/container
- `-r, --root_path`: local backing root directory
- `-p, --port`: gRPC server port
- `-u, --redis_url`: Redis URL, e.g. `redis://host:6379`
- `-i, --host_ip`: host/IP this node advertises to peers (default `localhost`)
- `-d, --debug`: FUSE debug
- `-s, --single`: run FUSE in single-threaded mode
- Env: `MULTICLOUD_FS_DISK_CACHE` (on-disk cache directory)

CSI driver (`csi/cmd/driver.py`):

- `--endpoint`: gRPC endpoint, e.g. `unix:///csi/csi.sock`
- `--nodeid`: Kubernetes node name
- `--redis-url`: Redis URL the FS nodes use
- `--node-url`: the URL this node advertises to peers (IP:port; port is chosen internally as 5000 for node-level FS)
- `--root-dir`: base dir for volumes (default `/var/lib/multicloud/volumes`)
- `--mount-point`: base dir for mounts (default `/var/lib/multicloud/mounts`)
- Env: `SKIP_NODE_MOUNT=true` to disable node-level FS inside the container (used in controller pod)

Helm/Manifests:

- Namespace: `multicloud-system`
- CSIDriver: `csi.multicloud.fs`
- StorageClass: `multicloud-csi-sc`
- Host paths used: `/var/lib/multicloud` for persistent node-local storage; kubelet plugin/registration dirs are mounted
  with proper mountPropagation.

---

## Project layout

- `src/`: FS implementation in Cython/Python
- `proto/`: FS gRPC protobuf
- `csi/`: CSI driver implementation, Dockerfile, deploy manifests and helper scripts
    - `pkg/driver`: Identity/Controller/Node services
    - `pkg/multicloud`: node-level FS launcher and binder
    - `deploy/`: raw Kubernetes manifests
    - `cmd/driver.py`: CLI entry for the driver
- `charts/multicloud-csi/`: Helm chart for the driver
- `Dockerfile`: root image building `multicloud_fs` binary
- `multicloud_fs.spec`: PyInstaller spec
- `dashboard/`: Grafana dashboard

---

## Contributing and development notes

- Code style: Black + isort configured for Python and Cython files (`.py`, `.pyx`).
- Rebuilding Cython modules: `poetry run python setup.py build_ext --inplace`.
- Building the FS binary: `poetry run pyinstaller multicloud_fs.spec`.
- Proto changes: update `proto/multicloud_fs.proto`, compile the proto files, change the type of generated files to
  .pyx, and rebuild Cython modules.
