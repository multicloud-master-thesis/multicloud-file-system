import errno
import os

import fuse

from src.grpc_client import GrpcClient


class MultiCloudFS(fuse.Fuse):
    def __init__(self, root_path: str, client: GrpcClient, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.root_path = root_path
        self.client = client

    def getattr(self, path: str):
        if os.path.exists(self.root_path + path):
            return os.lstat(self.root_path + path)

        if self.client.exists(path):
            return self.client.getattr(path)

        return -errno.ENOENT

    def readdir(self, path: str, offset: int):
        entries = []
        if os.path.exists(self.root_path + path):
            entries += os.listdir(self.root_path + path)
        if self.client.exists(path):
            entries += self.client.readdir(path, offset)

        entries = list(set(entries))
        for e in entries:
            yield fuse.Direntry(e)

    def read(self, path: str, size: int, offset: int):
        if os.path.exists(self.root_path + path):
            f = open(self.root_path + path, "r")
            f.seek(offset)
            return f.read(size).encode()

        if self.client.exists(path):
            return self.client.read(path, size, offset)

        return -errno.ENOENT

    def mkdir(self, path, mode):
        return os.mkdir(self.root_path + path, mode)

    def create(self, path, flags, *mode):
        return os.open(self.root_path + path, flags, *mode)

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
