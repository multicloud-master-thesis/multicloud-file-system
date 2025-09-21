# cython: language_level=3
import errno
import logging
import os
import threading
import time
from typing import Any, Dict, Iterable

import fuse

from cache_manager import MAX_MEM_CACHE_FILE_SIZE, CacheManager
from grpc_client_manager import GrpcClientManager
from redis_client import RedisClient


class MultiCloudFS(fuse.Fuse):

    # ------------- init -------------
    def __init__(
        self,
        root_path: str,
        client: GrpcClientManager,
        redis_client: RedisClient,
        cache: CacheManager | None = None,
        *args,
        **kwargs
    ):
        super().__init__(*args, **kwargs)
        self.root_path = os.path.abspath(root_path.rstrip("/") or "/")
        self.client = client
        self.redis_client = redis_client
        self.logger = logging.getLogger(__name__)
        self.cache = cache if cache else CacheManager()
        self.cache.set_evict_callback(self._on_cache_evict)
        self._written_once: set[str] = set()
        self._stop = False
        self._log_lock = threading.Lock()
        self._op_log: list[tuple[str, tuple]] = []
        self._flusher_thread = threading.Thread(
            target=self._flush_log_periodically, daemon=True
        )
        self._flusher_thread.start()

    # ------------- helpers -------------
    def _flush_log_periodically(self):  # stub – can be extended to persist batched ops
        while not self._stop:
            time.sleep(5)
            with self._log_lock:
                self._op_log.clear()

    def _log_op(self, op: str, *args):  # lightweight in‑memory log (extensible)
        try:
            with self._log_lock:
                if len(self._op_log) < 1000:
                    self._op_log.append((op, args))
        except Exception:
            pass

    def destroy(self, path=None):  # FUSE lifecycle hook
        self._stop = True

    def _norm(self, path: str) -> str:
        if not path:
            return "/"
        if not path.startswith("/"):
            path = "/" + path
        while "//" in path:
            path = path.replace("//", "/")
        if len(path) > 1 and path.endswith("/"):
            path = path.rstrip("/")
        return path or "/"

    def _full_path(self, path: str) -> str:
        p = path[1:] if path.startswith("/") else path
        return os.path.join(self.root_path, p)

    def _parent(self, path: str) -> str:
        return self._norm(os.path.dirname(self._norm(path)))

    def _build_local_metadata(self, path: str, st) -> Dict[str, Any]:
        return {
            "st_mode": st.st_mode,
            "st_ino": st.st_ino,
            "st_dev": st.st_dev,
            "st_nlink": st.st_nlink,
            "st_uid": st.st_uid,
            "st_gid": st.st_gid,
            "st_size": st.st_size,
            "st_atime": st.st_atime,
            "st_mtime": st.st_mtime,
            "st_ctime": st.st_ctime,
            "is_dir": (st.st_mode & 0o170000) == 0o040000,
        }

    def _build_remote_metadata(self, remote) -> Dict[str, Any]:
        return {
            "st_mode": remote.st_mode,
            "st_ino": remote.st_ino,
            "st_dev": remote.st_dev,
            "st_nlink": remote.st_nlink,
            "st_uid": remote.st_uid,
            "st_gid": remote.st_gid,
            "st_size": remote.st_size,
            "st_atime": remote.st_atime,
            "st_mtime": remote.st_mtime,
            "st_ctime": remote.st_ctime,
            "is_dir": (remote.st_mode & 0o170000) == 0o040000,
        }

    def _register_cache_location(self, path: str):
        try:
            locs = self.redis_client.get_locations(path)
            if self.client.url not in locs:
                self.redis_client.add_location(path, self.client.url)
        except Exception:
            pass

    def _on_cache_evict(self, path: str):
        # On eviction always remove this node from locations regardless of disk state per requirement
        try:
            self.redis_client.remove_location(path, self.client.url)
        except Exception:
            pass

    # ------------- initial scan (optional use) -------------
    def get_files(self) -> list[str]:
        files: list[str] = []
        for dirpath, dirnames, filenames in os.walk(self.root_path):
            rel_dir = self._norm(dirpath.replace(self.root_path, ""))
            try:
                st = os.lstat(dirpath)
                self.redis_client.set_metadata(
                    rel_dir, self._build_local_metadata(rel_dir, st)
                )
            except Exception:
                pass
            for n in dirnames + filenames:
                try:
                    self.redis_client.add_to_dir(rel_dir, n)
                except Exception:
                    pass
            for f in filenames:
                fp = os.path.join(dirpath, f)
                rel_file = self._norm(fp.replace(self.root_path, ""))
                try:
                    stf = os.lstat(fp)
                    self.redis_client.set_metadata(
                        rel_file, self._build_local_metadata(rel_file, stf)
                    )
                    self.redis_client.add_location(rel_file, self.client.url)
                    files.append(rel_file)
                except Exception:
                    pass
        return files

    # ------------- core ops -------------
    def getattr(self, path: str):
        path = self._norm(path)
        full = self._full_path(path)
        # Local first
        try:
            if os.path.exists(full):
                st = os.lstat(full)
                self.redis_client.set_metadata(
                    path, self._build_local_metadata(path, st)
                )
                return st
        except Exception:
            return -errno.EIO
        # Remote
        try:
            attr = self.client.getattr(path)
            if attr:
                self.redis_client.set_metadata(path, self._build_remote_metadata(attr))
                return attr
        except Exception:
            pass
        return -errno.ENOENT

    def readdir(self, path: str, offset: int) -> Iterable[fuse.Direntry]:
        path = self._norm(path)
        yield fuse.Direntry(".")
        yield fuse.Direntry("..")
        try:
            entries = self.redis_client.get_dir(path) or []
        except Exception:
            entries = []
        for raw in sorted(entries):
            try:
                name = raw.decode() if isinstance(raw, (bytes, bytearray)) else str(raw)
                if name and name not in (".", ".."):
                    yield fuse.Direntry(name)
            except Exception:
                continue

    def read(self, path: str, size: int, offset: int):
        # Cache
        path = self._norm(path)
        full = self._full_path(path)
        try:
            c = self.cache.get(path, offset, size)
            if c is not None:
                # Do not advertise location based on partial cache slices
                return c
        except Exception:
            pass
        # Local
        try:
            if os.path.exists(full):
                with open(full, "rb") as f:
                    if offset:
                        f.seek(offset)
                    data = f.read(size)
                # Always persist what we read into cache (disk-backed; mem limited inside)
                try:
                    if data:
                        self.cache.put(path, data, offset)
                        # Safe to register location because file exists locally on disk
                        self._register_cache_location(path)
                except Exception:
                    pass
                return data
        except Exception:
            pass
        # Remote
        try:
            # Prefer streaming for large reads
            stream = self.client.read_stream(path, size, offset)
            if stream is not None:
                parts = []
                total = 0
                cur_off = offset
                for chunk in stream:
                    if not chunk:
                        break
                    # Respect requested size if provided
                    part = chunk if size <= 0 else chunk[: max(0, size - total)]
                    if not part:
                        break
                    parts.append(part)
                    try:
                        self.cache.put(path, part, cur_off)
                        # Do not register location yet; may be partial
                    except Exception:
                        pass
                    cur_off += len(part)
                    total += len(part)
                    if size > 0 and total >= size:
                        break
                if parts:
                    return b"".join(parts)
            # Fallback to unary read
            part = self.client.read(path, size, offset)
            if part is not None:
                try:
                    if part:
                        self.cache.put(path, part, offset)
                        # Do not register location on partial cache
                except Exception:
                    pass
                return part
        except Exception:
            pass
        return -errno.ENOENT

    def write(self, path: str, buf: bytes, offset: int):
        path = self._norm(path)
        full = self._full_path(path)
        try:
            os.makedirs(os.path.dirname(full), exist_ok=True)
            exists = os.path.exists(full)
            mode = "r+b" if exists else "wb"
            with open(full, mode) as f:
                if offset > 0:
                    f.seek(offset)
                n = f.write(buf)
                f.flush()
                os.fsync(f.fileno())
            st = os.lstat(full)
            self.redis_client.set_metadata(path, self._build_local_metadata(path, st))
            try:
                self.redis_client.add_to_dir(self._parent(path), os.path.basename(path))
            except Exception:
                pass
            try:
                self.redis_client.add_location(path, self.client.url)
            except Exception:
                pass
            # Update cache with the exact written range; CacheManager handles memory/disk limits
            try:
                if buf:
                    self.cache.put(path, buf, offset)
                    # Register cache location because data is persisted locally
                    self._register_cache_location(path)
            except Exception:
                pass
            self._written_once.add(path)
            try:
                self.client.write(path, buf, offset)
            except Exception:
                pass
            return n
        except PermissionError:
            return -errno.EACCES
        except Exception:
            return -errno.EIO

    def truncate(self, path: str, size: int):
        path = self._norm(path)
        full = self._full_path(path)
        try:
            if os.path.exists(full):
                with open(full, "r+b") as f:
                    f.truncate(size)
                st = os.lstat(full)
                self.redis_client.set_metadata(
                    path, self._build_local_metadata(path, st)
                )
                return 0
        except Exception:
            return -errno.EIO
        # Remote fallback
        try:
            if self.client.truncate(path, size):
                attr = self.client.getattr(path)
                if attr:
                    self.redis_client.set_metadata(
                        path, self._build_remote_metadata(attr)
                    )
                    return 0
        except Exception:
            pass
        return -errno.ENOENT

    def unlink(self, path: str):
        path = self._norm(path)
        full = self._full_path(path)
        try:
            self.cache.remove(path)
        except Exception:
            pass
        self._written_once.discard(path)
        if os.path.exists(full):
            try:
                os.unlink(full)
            except OSError as e:
                return -e.errno
            except Exception:
                return -errno.EIO
            try:
                self.redis_client.remove_location(path, self.client.url)
            except Exception:
                pass
        else:
            # remote deletion
            try:
                if not self.client.unlink(path):
                    return -errno.ENOENT
            except Exception:
                return -errno.EIO
        remaining = []
        try:
            remaining = self.redis_client.get_locations(path)
        except Exception:
            pass
        if not remaining:
            try:
                parent = self._parent(path)
                self.redis_client.remove_metadata(path)
                self.redis_client.remove_from_dir(parent, os.path.basename(path))
            except Exception:
                pass
        return 0

    def rmdir(self, path: str):
        path = self._norm(path)
        full = self._full_path(path)
        if os.path.exists(full):
            try:
                os.rmdir(full)
            except OSError as e:
                return -e.errno
            except Exception:
                return -errno.EIO
            try:
                self.redis_client.remove_metadata(path)
                self.redis_client.remove_from_dir(
                    self._parent(path), os.path.basename(path)
                )
                self.redis_client.remove_dir(path)
                self.redis_client.remove_location(path, self.client.url)
            except Exception:
                pass
            return 0
        # remote
        try:
            if self.client.rmdir(path):
                return 0
        except Exception:
            return -errno.EIO
        return -errno.ENOENT

    def mkdir(self, path: str, mode: int):
        path = self._norm(path)
        full = self._full_path(path)
        parent = self._parent(path)
        try:
            if not os.path.exists(full):
                os.makedirs(full, exist_ok=True)
                os.chmod(full, mode)
            st = os.lstat(full)
            self.redis_client.set_metadata(path, self._build_local_metadata(path, st))
            try:
                self.redis_client.add_to_dir(parent, os.path.basename(path))
            except Exception:
                pass
            try:
                self.redis_client.add_location(path, self.client.url)
            except Exception:
                pass
            return 0
        except Exception:
            # remote attempt
            try:
                if self.client.mkdir(path, parent, mode):
                    return 0
            except Exception:
                pass
            return -errno.EIO

    def create(self, path: str, flags: int, mode: int):  # FUSE create (file)
        path = self._norm(path)
        full = self._full_path(path)
        parent = self._parent(path)
        try:
            os.makedirs(os.path.dirname(full), exist_ok=True)
            fd = os.open(full, flags, mode)
            os.close(fd)
            st = os.lstat(full)
            self.redis_client.set_metadata(path, self._build_local_metadata(path, st))
            try:
                self.redis_client.add_to_dir(parent, os.path.basename(path))
            except Exception:
                pass
            try:
                self.redis_client.add_location(path, self.client.url)
            except Exception:
                pass
            return 0
        except FileExistsError:
            return -errno.EEXIST
        except PermissionError:
            return -errno.EACCES
        except Exception:
            # remote
            try:
                if self.client.create(path, parent, flags, mode):
                    return 0
            except Exception:
                pass
            return -errno.EIO

    def rename(self, old_path: str, new_path: str):
        old_path = self._norm(old_path)
        new_path = self._norm(new_path)
        full_old = self._full_path(old_path)
        full_new = self._full_path(new_path)
        self.cache.rename(old_path, new_path)
        try:
            if os.path.exists(full_old):
                os.makedirs(os.path.dirname(full_new), exist_ok=True)
                os.rename(full_old, full_new)
                meta = self.redis_client.get_metadata(old_path)
                if meta:
                    decoded = {
                        (k.decode() if isinstance(k, (bytes, bytearray)) else k): (
                            v.decode() if isinstance(v, (bytes, bytearray)) else v
                        )
                        for k, v in meta.items()
                    }
                    self.redis_client.set_metadata(new_path, decoded)
                    self.redis_client.remove_metadata(old_path)
                try:
                    self.redis_client.remove_location(old_path, self.client.url)
                    self.redis_client.add_location(new_path, self.client.url)
                except Exception:
                    pass
                p_old = self._parent(old_path)
                p_new = self._parent(new_path)
                try:
                    if p_old != p_new:
                        self.redis_client.remove_from_dir(
                            p_old, os.path.basename(old_path)
                        )
                        self.redis_client.add_to_dir(p_new, os.path.basename(new_path))
                    else:
                        self.redis_client.add_to_dir(p_old, os.path.basename(new_path))
                        self.redis_client.remove_from_dir(
                            p_old, os.path.basename(old_path)
                        )
                except Exception:
                    pass
                if old_path in self._written_once:
                    self._written_once.discard(old_path)
                    self._written_once.add(new_path)
                return 0
        except Exception:
            return -errno.EIO
        # remote rename
        try:
            if self.client.rename(old_path, new_path):
                return 0
        except Exception:
            return -errno.EIO
        return -errno.ENOENT

    # ------------- attribute modifications -------------
    def utime(self, path: str, times):
        path = self._norm(path)
        full = self._full_path(path)
        try:
            os.utime(full, times)
            st = os.lstat(full)
            self.redis_client.set_metadata(path, self._build_local_metadata(path, st))
            return 0
        except FileNotFoundError:
            return -errno.ENOENT
        except Exception:
            # remote
            try:
                if self.client.utimens(path, times):
                    return 0
            except Exception:
                pass
            return -errno.EIO

    def utimens(self, path, ts_acc, ts_mod):  # FUSE style interface
        times = None
        if ts_acc is not None and ts_mod is not None:
            times = (
                ts_acc.tv_sec + ts_acc.tv_nsec / 1e9,
                ts_mod.tv_sec + ts_mod.tv_nsec / 1e9,
            )
        return self.utime(path, times)

    def chown(self, path: str, uid: int, gid: int):
        path = self._norm(path)
        full = self._full_path(path)
        try:
            if os.path.exists(full):
                os.chown(full, uid, gid)
                st = os.lstat(full)
                self.redis_client.set_metadata(
                    path, self._build_local_metadata(path, st)
                )
                return 0
        except PermissionError:
            return -errno.EACCES
        except Exception:
            return -errno.EIO
        # remote
        try:
            if self.client.chown(path, uid, gid):
                return 0
        except Exception:
            return -errno.EIO
        return -errno.ENOENT

    def chmod(self, path: str, mode: int):
        path = self._norm(path)
        full = self._full_path(path)
        try:
            if os.path.exists(full):
                os.chmod(full, mode)
                st = os.lstat(full)
                self.redis_client.set_metadata(
                    path, self._build_local_metadata(path, st)
                )
                return 0
        except PermissionError:
            return -errno.EACCES
        except Exception:
            return -errno.EIO
        # remote
        try:
            if self.client.chmod(path, mode):
                return 0
        except Exception:
            return -errno.EIO
        return -errno.ENOENT

    # ------------- misc / FUSE hooks -------------
    def open(self, path: str, flags: int):
        path = self._norm(path)
        full = self._full_path(path)
        try:
            if os.path.exists(full):
                fd = os.open(full, flags)
                os.close(fd)
                return 0
        except PermissionError:
            return -errno.EACCES
        except Exception:
            return -errno.EIO
        # remote existence check
        try:
            if self.client.getattr(path):
                return 0
        except Exception:
            pass
        return -errno.ENOENT

    def release(self, path, fh=None):
        return 0

    def fsync(self, path, datasync, fh=None):
        path = self._norm(path)
        full = self._full_path(path)
        if not os.path.exists(full) or fh is None:
            return 0
        try:
            if datasync:
                os.fdatasync(fh)
            else:
                os.fsync(fh)
            return 0
        except Exception:
            return -errno.EIO

    def flush(self, path, fh=None):
        path = self._norm(path)
        full = self._full_path(path)
        if not os.path.exists(full):
            return 0
        try:
            with open(full, "r+b") as f:
                f.flush()
                os.fsync(f.fileno())
            return 0
        except Exception:
            return -errno.EIO

    def access(self, path, mode):
        path = self._norm(path)
        full = self._full_path(path)
        try:
            if os.path.exists(full):
                return 0 if os.access(full, mode) else -errno.EACCES
        except Exception:
            return -errno.EIO
        try:
            if self.client.access(path, mode):
                return 0
        except Exception:
            pass
        return -errno.ENOENT

    def statfs(self):
        try:
            return os.statvfs(self.root_path)
        except Exception:
            return {}

    def fgetattr(self, path, fh=None):  # compatibility wrapper
        return self.getattr(path)
