import errno
import os
import stat
import subprocess

import fuse

fuse.fuse_python_api = (0, 2)


def _execute_shell_command(port, bash_command):
    return subprocess.getoutput(
        f"sshpass -p 'password' ssh -p {port} fsuser@localhost {bash_command}"
    )


def access_cloud_1(command):
    return _execute_shell_command(2222, command)


def access_cloud_2(command):
    return _execute_shell_command(2223, command)


def parse_path(path):
    return "/tmp" + path


class MultiCloudStat(fuse.Stat):
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


class MultiCloudFS(fuse.Fuse):
    def getattr(self, path):
        st = MultiCloudStat()
        if path == "/":
            st.st_mode = stat.S_IFDIR | 0o755
            st.st_nlink = 2
        else:
            path = parse_path(path)
            result_1 = access_cloud_1(
                f"test -e {path} && echo exists || echo not_exists"
            )
            result_2 = access_cloud_2(
                f"test -e {path} && echo exists || echo not_exists"
            )
            if "exists" == result_1:
                st.st_mode = stat.S_IFREG | 0o444
                st.st_nlink = 1
                st.st_size = int(access_cloud_1(f"stat -c %s {path}"))
            elif "exists" == result_2:
                st.st_mode = stat.S_IFREG | 0o444
                st.st_nlink = 1
                st.st_size = int(access_cloud_2(f"stat -c %s {path}"))
            else:
                return -errno.ENOENT
        return st

    def readdir(self, path, offset):
        path = parse_path(path)
        files_1 = access_cloud_1(f"ls {path}").split("\n")
        files_2 = access_cloud_2(f"ls {path}").split("\n")
        files = set(files_1 + files_2)
        for r in [".", ".."] + list(files):
            yield fuse.Direntry(r)

    def open(self, path, flags):
        path = parse_path(path)
        result_1 = access_cloud_1(f"test -e {path} && echo exists || echo not_exists")
        result_2 = access_cloud_2(f"test -e {path} && echo exists || echo not_exists")
        if "not_exists" == result_1 and "not_exists" == result_2:
            return -errno.ENOENT
        accmode = os.O_RDONLY | os.O_WRONLY | os.O_RDWR
        if (flags & accmode) != os.O_RDONLY:
            return -errno.EACCES

    def read(self, path, size, offset):
        path = parse_path(path)
        result_1 = access_cloud_1(f"test -e {path} && echo exists || echo not_exists")
        result_2 = access_cloud_2(f"test -e {path} && echo exists || echo not_exists")
        if "exists" == result_1:
            buf = access_cloud_1(f"dd if={path} bs=1 skip={offset} count={size}")
        elif "exists" == result_2:
            buf = access_cloud_2(f"dd if={path} bs=1 skip={offset} count={size}")
        else:
            return -errno.ENOENT
        return ('\n'.join(buf.split('\n')[:-3]) + '\n').encode()

    def write(self, path, buf, offset):
        path = parse_path(path)
        result_1 = access_cloud_1(f"test -e {path} && echo exists || echo not_exists")
        result_2 = access_cloud_2(f"test -e {path} && echo exists || echo not_exists")
        if "exists" == result_1:
            access_cloud_1(f"echo '{buf.decode()}' | dd of={path} bs=1 seek={offset} conv=notrunc")
        elif "exists" == result_2:
            access_cloud_2(f"echo '{buf.decode()}' | dd of={path} bs=1 seek={offset} conv=notrunc")
        else:
            return -errno.ENOENT
        return len(buf)


def main():
    server = MultiCloudFS(version="%prog " + fuse.__version__, dash_s_do="setsingle")

    server.parse(errex=1)
    server.main()


if __name__ == "__main__":
    main()
