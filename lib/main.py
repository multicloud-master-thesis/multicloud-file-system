import os, stat, errno
import cython
import fuse

fuse.fuse_python_api = (0, 2)


class MultiCloudFS(fuse.Fuse):
    def read(self, path, size, offset):
        return 'Hello World!'

    def readdir(self, path, offset, *fh):
        return ['.', '..', 'hello']


def main():
    usage = """
       MultiCloudFS: A filesystem for multicloud environment.
   """ + fuse.Fuse.fusage

    server = MultiCloudFS(version="%prog " + fuse.__version__,
                          usage=usage, dash_s_do='setsingle')
    server.parse(errex=1)
    server.main()


if __name__ == '__main__':
    main()
