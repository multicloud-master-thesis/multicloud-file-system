#!/usr/bin/env python

#    Copyright (C) 2006  Andrew Straw  <strawman@astraw.com>
#
#    This program can be distributed under the terms of the GNU LGPL.
#    See the file COPYING.
#

import os, stat, errno
# pull in some spaghetti to make this stuff work without fuse-py being installed
try:
    import _find_fuse_parts
except ImportError:
    pass
import fuse
from fuse import Fuse


if not hasattr(fuse, '__version__'):
    raise RuntimeError("your fuse-py doesn't know of fuse.__version__, probably it's too old.")

fuse.fuse_python_api = (0, 2)

hello_path = '/hello'
hello_str = b'Hello World!\n'
another_str = b'Another String!\n'

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

    def map_path(self, path):
        # return os.path.join(os.getcwd(), 'p', path.lstrip('/'))

        return os.path.join("/mnt/c/Users/tekie/AGH/A_magisterka/")

    def map_path_2(self, path):
        # return os.path.join(os.getcwd(), 'p', path.lstrip('/'))

        return os.path.join("/mnt/c/Users/tekie/AGH/")

    def map_path_3(self, path):
        # return os.path.join(os.getcwd(), 'p', path.lstrip('/'))

        return os.path.join("/mnt/c/Users/tekie/AGH/a.txt")

    def map_path_4(self, path):
        return os.path.join(os.getcwd(), path.lstrip('/'))

        # return os.path.join("/mnt/c/Users/tekie/AGH/a.txt")

    def getattr(self, path):
        st = MyStat()
        if path == '/':
            st.st_mode = stat.S_IFDIR | 0o755
            st.st_nlink = 2
        else:
            # path == hello_path:
            st.st_mode = stat.S_IFREG | 0o444
            st.st_nlink = 1
            st.st_size = len(hello_str)
        # else:
        #     return -errno.ENOENT
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

        yield fuse.Direntry("extra_file")


    def open(self, path, flags):
        # if path != hello_path:
        #     return -errno.ENOENT
        accmode = os.O_RDONLY | os.O_WRONLY | os.O_RDWR
        if (flags & accmode) != os.O_RDONLY:
            return -errno.EACCES

    # def cd(self, path):
    #
    #     real_path = self.map_path(path)
    #
    #     try:
    #         os.chdir(real_path)
    #     except OSError as e:
    #         print(f"Error: {e}")

    # def read(self, path, size, offset):
    #

    def read(self, path, size, offset):
        if path != hello_path:
            full_path = self.map_path_3(path)
            # slen = len(another_str)
            # if offset < slen:
            #     if offset + size > slen:
            #         size = slen - offset
            #     buf = another_str[offset:offset + size]
            # else:
            #     buf = b''
            # return buf

            try:
                with open(full_path, 'rb') as f:
                    f.seek(offset)
                    return f.read(size)
            except OSError as e:
                print(f"Error: {e}")
                return -errno.ENOENT
        slen = len(hello_str)
        if offset < slen:
            if offset + size > slen:
                size = slen - offset
            buf = hello_str[offset:offset+size]
        else:
            buf = b''
        return buf

def main():
    usage="""
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