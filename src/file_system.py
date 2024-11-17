import errno
import os

import fuse

from grpc_client_manager import GrpcClientManager


class MultiCloudFS(fuse.Fuse):
    def __init__(self, root_path: str, client: GrpcClientManager, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.root_path = root_path
        self.client = client

    def get_files(self):
        def list_files(directory):
            for dirpath, dirnames, filenames in os.walk(directory):
                for filename in filenames:
                    yield os.path.join(dirpath, filename)
                for dirname in dirnames:
                    yield os.path.join(dirpath, dirname)

        files = list(list_files(self.root_path))
        files = list(map(lambda file: file.replace(self.root_path, ""), files))
        return files

    def getattr(self, path: str):
        if os.path.exists(self.root_path + path):
            return os.lstat(self.root_path + path)

        response = self.client.getattr(path)
        return response if response else -errno.ENOENT

    def readdir(self, path: str, offset: int):
        entries = []
        if os.path.exists(self.root_path + path):
            entries += os.listdir(self.root_path + path)
        entries += self.client.readdir(path, offset)

        entries = list(set(entries))
        for e in entries:
            yield fuse.Direntry(e)

    def read(self, path: str, size: int, offset: int):
        if os.path.exists(self.root_path + path):
            with open(self.root_path + path, "rb") as f:
                f.seek(offset)
                return f.read(size)

        response = self.client.read(path, size, offset)
        return response if response else -errno.ENOENT

    def mkdir(self, path, mode):
        os.mkdir(self.root_path + path, mode)
        self.client.create(path)

    def create(self, path, flags, *mode):
        fd = os.open(self.root_path + path, flags, *mode)
        self.client.create(path)
        return fd

    def write(self, path, buf, offset):
        f = open(self.root_path + path, "w")
        f.seek(offset)
        return f.write(buf.decode())

    def statfs(self):
        return os.statvfs(self.root_path)

    def utime(self, path, times):
        os.utime(self.root_path + path, times)

    def truncate(self, path, size):
        f = open(self.root_path + path, "r+")
        f.truncate(size)

    def chown(self, path, uid, gid):
        os.chown(self.root_path + path, uid, gid)
