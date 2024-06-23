# Multicloud file system

## Description

File system (for now mostly a proof of concept) for distributed computing in multicloud environment.

## Requirements

- Linux or MacOS operating system (WSL on Windows should work)
- FUSE (Linux) or macFUSE (macOS) installed
- Python version specified in the `.python-version` file (you can use `pyenv` and run `pyenv install` to install the correct version)
- Poetry installed (run `pip install poetry`)

## Local development

Install dependencies:

```bash
poetry shell
poetry install
```

Set up the environment:

```bash
CLOUD_ADDRESS=localhost:{port of second fs};PORT={port for this fs};ROOT_PATH={path to the root directory}
```

Run the file system:

```bash
python src/main.py -d -f -s {mount_point}
```