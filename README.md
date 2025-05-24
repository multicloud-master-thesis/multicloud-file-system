# Multicloud file system

## Description

File system for distributed computing using local nodes storage.

## Requirements

- Linux or MacOS operating system (WSL on Windows should work)
- FUSE (Linux) or macFUSE (macOS) installed
- Python version specified in the `.python-version` file (you can use `pyenv` and run `pyenv install` to install the
  correct version)
- Poetry installed (run `pip install poetry`)
- Docker installed

## Local development

### Local python

You will need to have `redis` installed and running.

Install dependencies:

```bash
  poetry shell
  poetry install
```

Run the file system:

```bash
  poetry run python src/main.py -f {mount_point} -r {root_dir} -p {port} -u {redis_url} -i localhost
```

### Compiling to cpython executable

Install dependencies:

```bash
  poetry shell
  poetry install
```

Compile cython code:

```bash
  poetry run python setup.py build_ext --inplace
```

Compile to cpython executable:

```bash
  pyinstaller multicloudfs.spec
```

## Architecture

The file system is built on top of FUSE (Filesystem in Userspace) and uses Redis as a key-value store for metadata.
Clients can connect to the file system and read/write files. The file system is divided into two parts: the metadata part and the data part. The metadata part is stored in Redis and
contains information about the files and directories. The data part is stored on the local machine in the root directory
specified by the user. The file system is distributed and can be run on multiple machines

Upon initialization gRPC server is started and listens for incoming connections. The server is responsible for handling
getattr, read and readdir requests from the clients. Next, gRPC client manager is started and connects to redis. It
retrieves information about all the clients addresses and starts gRPC clients for each of them. After that, it registers
all the files that stored on the local machine in the redis and registers itself in the list of clients. Next, the FUSE
file system is started.