import errno
import logging
import os

import fuse

from grpc_client_manager import GrpcClientManager


class MultiCloudFS(fuse.Fuse):

    def __init__(self, root_path: str, client: GrpcClientManager, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.root_path = root_path
        self.client = client
        self.logger = logging.getLogger(__name__)

    def _full_path(self, path):
        """Helper method to get the full local path"""
        return self.root_path + path

    def get_files(self):
        """Get all files and directories from the local filesystem."""

        def list_files(directory):
            for dirpath, dirnames, filenames in os.walk(directory):
                for filename in filenames:
                    yield os.path.join(dirpath, filename)
                for dirname in dirnames:
                    yield os.path.join(dirpath, dirname)

        files = list(list_files(self.root_path))
        return [file.replace(self.root_path, "") for file in files]

    def getattr(self, path: str):
        """Get attributes for a file."""
        self.logger.debug(f"getattr: {path}")

        try:
            if os.path.exists(self._full_path(path)):
                return os.lstat(self._full_path(path))
        except Exception as e:
            self.logger.error(f"Error in getattr for {path}: {e}")
            return -errno.EIO

        response = self.client.getattr(path)
        return response if response else -errno.ENOENT

    def readdir(self, path: str, offset: int):
        """Read directory entries."""
        self.logger.debug(f"readdir: {path}, offset: {offset}")

        entries = []

        try:
            if os.path.exists(self._full_path(path)):
                entries += os.listdir(self._full_path(path))
        except Exception as e:
            self.logger.error(f"Error reading local directory {path}: {e}")

        remote_entries = self.client.readdir(path, offset)
        if remote_entries:
            entries += remote_entries

        for entry in set(entries):
            yield fuse.Direntry(entry)

    def read(self, path: str, size: int, offset: int):
        """Read data from a file."""
        self.logger.debug(f"read: {path}, size: {size}, offset: {offset}")

        try:
            if os.path.exists(self._full_path(path)):
                with open(self._full_path(path), "rb") as f:
                    f.seek(offset)
                    data = f.read(size)
                    return data
            else:
                response = self.client.read(path, size, offset)
                if response is None:
                    return -errno.ENOENT
                return response
        except IOError as e:
            self.logger.error(f"IO error reading {path}: {e}")
            return -errno.EIO
        except Exception as e:
            self.logger.error(f"Error reading {path}: {e}")
            return -errno.EIO

    def write(self, path, buf, offset):
        """Write data to a file."""
        self.logger.debug(f"write: {path}, offset: {offset}, size: {len(buf)}")

        try:
            if os.path.exists(self._full_path(path)):
                with open(self._full_path(path), "r+b") as f:
                    f.seek(offset)
                    bytes_written = f.write(buf)
                    f.flush()
                    os.fsync(f.fileno())
                    return bytes_written
            else:
                response = self.client.write(path, buf, offset)
                if response is None:
                    return -errno.ENOENT
                return response
        except IOError as e:
            self.logger.error(f"IO error writing to {path}: {e}")
            return -errno.EIO
        except Exception as e:
            self.logger.error(f"Error writing to {path}: {e}")
            return -errno.EIO

    def mkdir(self, path, mode):
        """Create a directory."""
        self.logger.debug(f"mkdir: {path}, mode: {mode}")

        parent_path = os.path.dirname(path)

        if os.path.exists(self._full_path(parent_path)):
            try:
                os.mkdir(self._full_path(path), mode)
                self.client.set(path)
                return 0
            except FileExistsError:
                return -errno.EEXIST
            except Exception as e:
                self.logger.error(f"Error creating directory {path}: {e}")
                return -errno.EIO

        response = self.client.mkdir(path, parent_path, mode)
        return 0 if response else -errno.EEXIST

    def create(self, path, flags, *mode):
        """Create a file."""
        self.logger.debug(f"create: {path}, flags: {flags}, mode: {mode}")

        mode_value = mode[0] if mode else 0o644
        parent_path = os.path.dirname(path)

        if os.path.exists(self._full_path(parent_path)):
            try:
                fd = os.open(self._full_path(path), flags, mode_value)
                os.close(fd)
                self.client.set(path)
                return 0
            except PermissionError:
                return -errno.EACCES
            except Exception as e:
                self.logger.error(f"Error creating file {path}: {e}")
                return -errno.EIO

        response = self.client.create(path, parent_path, flags, mode_value)
        return 0 if response else -errno.EACCES

    def statfs(self):
        """Get filesystem statistics."""
        self.logger.debug("statfs")

        try:
            return os.statvfs(self.root_path)
        except Exception as e:
            self.logger.error(f"Error in statfs: {e}")
            return {}

    def utime(self, path, times):
        """Set access and modification times of a file."""
        self.logger.debug(f"utime: {path}, times: {times}")

        try:
            os.utime(self._full_path(path), times)
            return 0
        except FileNotFoundError:
            return -errno.ENOENT
        except Exception as e:
            self.logger.error(f"Error setting utime for {path}: {e}")
            return -errno.EIO

    def truncate(self, path, size):
        """Truncate or extend a file to a specified size."""
        self.logger.debug(f"truncate: {path}, size: {size}")

        if os.path.exists(self._full_path(path)):
            try:
                with open(self._full_path(path), "r+b") as f:
                    f.truncate(size)
                return 0
            except IOError as e:
                error_code = getattr(errno, e.strerror, errno.EIO)
                return -error_code
            except Exception as e:
                self.logger.error(f"Error truncating {path}: {e}")
                return -errno.EIO

        response = self.client.truncate(path, size)
        if response is True:
            return 0
        return -errno.ENOENT if response is None else -errno.EIO

    def chown(self, path, uid, gid):
        """Change ownership of a file."""
        self.logger.debug(f"chown: {path}, uid: {uid}, gid: {gid}")

        if os.path.exists(self._full_path(path)):
            try:
                os.chown(self._full_path(path), uid, gid)
                return 0
            except PermissionError:
                return -errno.EACCES
            except Exception as e:
                self.logger.error(f"Error changing ownership of {path}: {e}")
                return -errno.EIO

        response = self.client.chown(path, uid, gid)
        if response is True:
            return 0
        return -errno.EIO if response is None else -errno.EACCES

    def open(self, path, flags):
        """Open a file."""
        self.logger.debug(f"open: {path}, flags: {flags}")

        if os.path.exists(self._full_path(path)):
            try:
                fd = os.open(self._full_path(path), flags)
                os.close(fd)
                return 0
            except PermissionError:
                return -errno.EACCES
            except Exception as e:
                self.logger.error(f"Error opening {path}: {e}")
                return -errno.EIO

        response = self.client.getattr(path)
        if response and response != -errno.ENOENT:
            return 0

        return -errno.ENOENT

    def release(self, path, fh=None):
        """Release an open file."""
        self.logger.debug(f"release: {path}, fh: {fh}")
        return 0

    def fsync(self, path, datasync, fh=None):
        """Synchronize file contents."""
        self.logger.debug(f"fsync: {path}, datasync: {datasync}, fh: {fh}")

        if os.path.exists(self._full_path(path)):
            try:
                if datasync != 0:
                    os.fdatasync(fh)
                else:
                    os.fsync(fh)
                return 0
            except Exception as e:
                self.logger.error(f"Error syncing {path}: {e}")
                return -errno.EIO
        return 0

    def flush(self, path, fh=None):
        """Flush cached data."""
        self.logger.debug(f"flush: {path}, fh: {fh}")

        if os.path.exists(self._full_path(path)):
            try:
                with open(self._full_path(path), "r+b") as f:
                    f.flush()
                    os.fsync(f.fileno())
                return 0
            except Exception as e:
                self.logger.error(f"Error flushing {path}: {e}")
                return -errno.EIO
        return 0

    def chmod(self, path, mode):
        """Change permissions of a file."""
        self.logger.debug(f"chmod: {path}, mode: {mode}")

        if os.path.exists(self._full_path(path)):
            try:
                os.chmod(self._full_path(path), mode)
                return 0
            except PermissionError:
                return -errno.EACCES
            except Exception as e:
                self.logger.error(f"Error changing permissions of {path}: {e}")
                return -errno.EIO

        response = self.client.chmod(path, mode)
        if response is True:
            return 0
        return -errno.ENOENT if response is None else -errno.EIO

    def unlink(self, path):
        """Remove a file."""
        self.logger.debug(f"unlink: {path}")

        if os.path.exists(self._full_path(path)):
            try:
                os.unlink(self._full_path(path))
                self.client.remove(path)
                return 0
            except OSError as e:
                return -e.errno
            except Exception as e:
                self.logger.error(f"Error removing file {path}: {e}")
                return -errno.EIO

        response = self.client.unlink(path)
        if response is True:
            return 0
        return -errno.ENOENT if response is None else -errno.EIO

    def rmdir(self, path):
        """Remove a directory."""
        self.logger.debug(f"rmdir: {path}")

        if os.path.exists(self._full_path(path)):
            try:
                os.rmdir(self._full_path(path))
                self.client.remove(path)
                return 0
            except OSError as e:
                return -e.errno
            except Exception as e:
                self.logger.error(f"Error removing directory {path}: {e}")
                return -errno.EIO

        response = self.client.rmdir(path)
        if response is True:
            return 0
        return -errno.ENOENT if response is None else -errno.EIO

    def rename(self, old_path, new_path):
        """Rename a file or directory."""
        self.logger.debug(f"rename: {old_path} -> {new_path}")

        if os.path.exists(self._full_path(old_path)):
            try:
                os.rename(self._full_path(old_path), self._full_path(new_path))
                self.client.remove(old_path)
                self.client.set(new_path)
                return 0
            except OSError as e:
                return -e.errno
            except Exception as e:
                self.logger.error(f"Error renaming {old_path} to {new_path}: {e}")
                return -errno.EIO

        response = self.client.rename(old_path, new_path)
        if response is True:
            return 0
        return -errno.ENOENT if response is None else -errno.EIO

    def fgetattr(self, path, fh=None):
        """Get file attributes by handle."""
        self.logger.debug(f"fgetattr: {path}, fh: {fh}")
        return self.getattr(path)

    def access(self, path, mode):
        """Check file access permissions."""
        self.logger.debug(f"access: {path}, mode: {mode}")

        if os.path.exists(self._full_path(path)):
            try:
                if os.access(self._full_path(path), mode):
                    return 0
                return -errno.EACCES
            except Exception as e:
                self.logger.error(f"Error checking access for {path}: {e}")
                return -errno.EIO

        response = self.client.access(path, mode)
        if response is True:
            return 0
        return -errno.ENOENT if response is None else -errno.EACCES

    def utimens(self, path, ts_acc, ts_mod):
        """Set access and modification times with nanosecond precision."""
        self.logger.debug(f"utimens: {path}, ts_acc: {ts_acc}, ts_mod: {ts_mod}")

        times = None
        if ts_acc is not None and ts_mod is not None:
            times = (
                ts_acc.tv_sec + ts_acc.tv_nsec / 1e9,
                ts_mod.tv_sec + ts_mod.tv_nsec / 1e9,
            )

        if os.path.exists(self._full_path(path)):
            try:
                return os.utime(self._full_path(path), times)
            except Exception as e:
                self.logger.error(f"Error setting utimens for {path}: {e}")
                return -errno.EIO

        response = self.client.utimens(path, times)
        if response is True:
            return 0
        return -errno.ENOENT if response is None else -errno.EIO
