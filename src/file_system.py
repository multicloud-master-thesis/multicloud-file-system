import errno
import os

import fuse


class MultiCloudFS(fuse.Fuse):
    def __init__(self, root_path, client, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.root_path = root_path
        self.client = client

    def getattr(self, path):
        if os.path.exists(self.root_path + path):
            return os.lstat(self.root_path + path)

        if self.client.exists(path):
            return self.client.getattr(path)

        return -errno.ENOENT

    def readdir(self, path, offset):
        entries = []
        if os.path.exists(self.root_path + path):
            entries += os.listdir(self.root_path + path)
        if self.client.exists(path):
            entries += self.client.readdir(path, offset)

        entries = list(set(entries))
        for e in entries:
            yield fuse.Direntry(e)

    def read(self, path, size, offset):
        if os.path.exists(self.root_path + path):
            f = open(self.root_path + path, "r")
            f.seek(offset)
            return f.read(size).encode()

        if self.client.exists(path):
            return self.client.read(path, size, offset)

        return -errno.ENOENT
