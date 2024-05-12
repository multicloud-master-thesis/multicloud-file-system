#!/usr/bin/env python

import os, stat, errno

try:
    import _find_fuse_parts
except ImportError:
    pass
import fuse
from fuse import Fuse

if not hasattr(fuse, '__version__'):
    raise RuntimeError("your fuse-py doesn't know of fuse.__version__, probably it's too old.")

fuse.fuse_python_api = (0, 2)


class MyStat(fuse.Stat):
    def __init__(self):
        self.st_mode = 0
        self.st_ino = 0
        self.st_dev = 0
        self.st_nlink = 0
        self.st_uid = 0
        self.st_gid = 0
        self.st_size = 0
        self.st_atime = 0
        self.st_mtime = 0
        self.st_ctime = 0


class HelloFS(Fuse):

    def path_to_dir_1(self, path):
        return os.path.join(os.getcwd(), 'dir1', path.lstrip('/'))

    def path_to_dir_2(self, path):
        return os.path.join(os.getcwd(), 'dir2', path.lstrip('/'))

    def getattr(self, path):
        st = MyStat()
        if path == '/':
            st.st_mode = stat.S_IFDIR | 0o755
            st.st_nlink = 2
        else:
            st.st_mode = stat.S_IFREG | 0o444
            st.st_nlink = 1
            st.st_size = len(hello_str)
        return st

    def readdir(self, path, offset):

        path_dir_1 = self.path_to_dir_1(path)
        print(f"Path dir 1: {path_dir_1}")
        try:
            files = os.listdir(path_dir_1)
        except OSError:
            return -errno.ENOENT

        for file in files:
            yield fuse.Direntry(file)

        path_dir_2 = self.path_to_dir_2(path)
        print(f"Path dir 2: {path_dir_2}")
        try:
            files = os.listdir(path_dir_2)
        except OSError:
            return -errno.ENOENT

        for file in files:
            yield fuse.Direntry(file)

        yield fuse.Direntry("extra_file")  # add extra file to directory

    def open(self, path, flags):
        accmode = os.O_RDONLY | os.O_WRONLY | os.O_RDWR
        if (flags & accmode) != os.O_RDONLY:
            return -errno.EACCES

    def read(self, path, size, offset):


        path_dir_1 = self.path_to_dir_1("")
        print(f"Path dir 1: {path_dir_1}")
        try:
            files = os.listdir(path_dir_1)
        except OSError:
            return -errno.ENOENT

        for file in files:
            print(f"File: {file}")
            if file == os.path.basename(path):
                try:
                    path_to_file = os.path.join(path_dir_1, file)
                    with open(path_to_file, 'rb') as f:
                        f.seek(offset)
                        return f.read(size)
                except OSError as e:
                    print(f"Error: {e}")
                    return -errno.ENOENT

        path_dir_2 = self.path_to_dir_2("")
        print(f"Path dir 2: {path_dir_2}")
        try:
            files = os.listdir(path_dir_2)
        except OSError:
            return -errno.ENOENT

        for file in files:
            print(f"File: {file}")
            if file == os.path.basename(path):
                try:
                    path_to_file = os.path.join(path_dir_2, file)
                    with open(path_to_file, 'rb') as f:
                        f.seek(offset)
                        return f.read(size)
                except OSError as e:
                    print(f"Error: {e}")
                    return -errno.ENOENT


def main():
    usage = """
Userspace hello example

""" + Fuse.fusage
    server = HelloFS(version="%prog " + fuse.__version__,
                     usage=usage,
                     dash_s_do='setsingle')

    server.parse(errex=1)
    server.fuse_args.add('nonempty')
    server.main()


if __name__ == '__main__':
    main()
