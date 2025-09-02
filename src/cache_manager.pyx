import hashlib
import os
from collections import OrderedDict
from threading import RLock
from typing import Optional

MAX_MEM_CACHE_SIZE = 64 * 1024 * 1024  # 64 MB total in-memory cache
MAX_DISK_CACHE_SIZE = 1024 * 1024 * 1024  # 1 GB total on-disk cache
MAX_MEM_CACHE_FILE_SIZE = 4 * 1024 * 1024  # Only files <=4MB stored in memory
DISK_CACHE_DIR = os.environ.get("MULTICLOUD_FS_DISK_CACHE", "/tmp/multicloudfs_cache")


def _safe_makedirs(path: str):
    try:
        os.makedirs(path, exist_ok=True)
    except Exception:
        pass


class CacheManager:
    def __init__(
        self,
        max_mem_size: int = MAX_MEM_CACHE_SIZE,
        max_disk_size: int = MAX_DISK_CACHE_SIZE,
        max_mem_file: int = MAX_MEM_CACHE_FILE_SIZE,
        disk_dir: str = DISK_CACHE_DIR,
    ):
        self.max_mem_size = max_mem_size
        self.max_disk_size = max_disk_size
        self.max_mem_file = max_mem_file
        self.disk_dir = disk_dir
        _safe_makedirs(self.disk_dir)

        self._mem: "OrderedDict[str, bytes]" = OrderedDict()  # key -> bytes
        self._disk_index: "OrderedDict[str, str]" = OrderedDict()  # key -> filepath
        self._mem_size = 0
        self._disk_size = 0
        self._lock = RLock()
        self._on_evict = None  # callback: (path:str) -> None

    def set_evict_callback(self, cb):
        self._on_evict = cb

    # ------------- helpers -------------
    def _norm(self, path: str) -> str:
        return path[1:] if path.startswith("/") else path

    def _disk_path(self, key: str) -> str:
        h = hashlib.sha256(key.encode()).hexdigest()
        # Use first 2 bytes as shard dirs to avoid huge flat dir
        shard = h[:2]
        shard_dir = os.path.join(self.disk_dir, shard)
        _safe_makedirs(shard_dir)
        return os.path.join(shard_dir, h)

    def _evict_mem(self):
        while self._mem_size > self.max_mem_size and self._mem:
            k, data = self._mem.popitem(last=False)
            self._mem_size -= len(data)
            if self._on_evict:
                try:
                    self._on_evict("/" + k)
                except Exception:
                    pass

    def _evict_disk(self):
        while self._disk_size > self.max_disk_size and self._disk_index:
            k, fpath = self._disk_index.popitem(last=False)
            try:
                size = os.path.getsize(fpath)
            except OSError:
                size = 0
            try:
                os.remove(fpath)
            except OSError:
                pass
            self._disk_size -= size
            if self._on_evict:
                try:
                    self._on_evict("/" + k)
                except Exception:
                    pass

    # ------------- public API -------------
    def get(self, path: str, offset: int, size: int) -> Optional[bytes]:
        key = self._norm(path)
        with self._lock:
            # Memory
            if key in self._mem:
                data = self._mem.pop(key)
                self._mem[key] = data  # move to MRU
                return data[offset : offset + size]
            # Disk
            if key in self._disk_index:
                fpath = self._disk_index.pop(key)
                self._disk_index[key] = fpath  # move to MRU
                try:
                    with open(fpath, "rb") as f:
                        if offset:
                            f.seek(offset)
                        return f.read(size)
                except OSError:
                    # Treat as cache miss; remove index entry
                    try:
                        del self._disk_index[key]
                    except KeyError:
                        pass
        return None

    def has(self, path: str) -> bool:
        key = self._norm(path)
        with self._lock:
            return key in self._mem or key in self._disk_index

    def put(self, path: str, data: bytes):
        key = self._norm(path)
        size = len(data)
        with self._lock:
            # Always write to disk first
            fpath = self._disk_path(key)
            try:
                # Atomic-ish replace
                tmp = fpath + ".tmp"
                with open(tmp, "wb") as f:
                    f.write(data)
                os.replace(tmp, fpath)
                # Update disk index & size
                if key not in self._disk_index:
                    self._disk_index[key] = fpath
                else:
                    # Move to MRU
                    self._disk_index.pop(key)
                    self._disk_index[key] = fpath
                self._recalc_disk_size()
                self._evict_disk()
            except OSError:
                pass  # Ignore disk errors for caching

            # Optionally store in memory
            if size <= self.max_mem_file:
                prev = self._mem.pop(key, None)
                if prev is not None:
                    self._mem_size -= len(prev)
                self._mem[key] = data
                self._mem_size += size
                self._evict_mem()

    def remove(self, path: str):
        key = self._norm(path)
        with self._lock:
            data = self._mem.pop(key, None)
            if data is not None:
                self._mem_size -= len(data)
                if self._on_evict:
                    try:
                        self._on_evict("/" + key)
                    except Exception:
                        pass
            fpath = self._disk_index.pop(key, None)
            if fpath:
                try:
                    size = os.path.getsize(fpath)
                except OSError:
                    size = 0
                try:
                    os.remove(fpath)
                except OSError:
                    pass
                self._disk_size -= size
                if self._on_evict:
                    try:
                        self._on_evict("/" + key)
                    except Exception:
                        pass

    def remove_prefix(self, prefix: str):
        norm_prefix = self._norm(prefix)
        with self._lock:
            mem_keys = [
                k
                for k in self._mem
                if k == norm_prefix or k.startswith(norm_prefix + "/")
            ]
            for k in mem_keys:
                data = self._mem.pop(k)
                self._mem_size -= len(data)
                if self._on_evict:
                    try:
                        self._on_evict("/" + k)
                    except Exception:
                        pass
            disk_keys = [
                k
                for k in self._disk_index
                if k == norm_prefix or k.startswith(norm_prefix + "/")
            ]
            for k in disk_keys:
                fpath = self._disk_index.pop(k)
                try:
                    size = os.path.getsize(fpath)
                except OSError:
                    size = 0
                try:
                    os.remove(fpath)
                except OSError:
                    pass
                self._disk_size -= size
                if self._on_evict:
                    try:
                        self._on_evict("/" + k)
                    except Exception:
                        pass

    def rename(self, old_path: str, new_path: str):
        old_key = self._norm(old_path)
        new_key = self._norm(new_path)
        with self._lock:
            # Exact file rename; for directories we just rebuild keys
            if old_key in self._mem:
                data = self._mem.pop(old_key)
                self._mem[new_key] = data
            if old_key in self._disk_index:
                fpath = self._disk_index.pop(old_key)
                # Keep same file, just update index (key maps to same content)
                self._disk_index[new_key] = fpath

            # Directory rename: adjust any descendant keys
            # This is O(n) in number of cached entries; acceptable for modest cache sizes
            old_prefix = old_key + "/"
            if any(
                k.startswith(old_prefix)
                for k in list(self._mem.keys()) + list(self._disk_index.keys())
            ):
                # Collect renames first to avoid modifying while iterating
                mem_renames = []
                for k in list(self._mem.keys()):
                    if k.startswith(old_prefix):
                        mem_renames.append(k)
                for k in mem_renames:
                    data = self._mem.pop(k)
                    new_k = new_key + k[len(old_key) :]
                    self._mem[new_k] = data
                disk_renames = []
                for k in list(self._disk_index.keys()):
                    if k.startswith(old_prefix):
                        disk_renames.append(k)
                for k in disk_renames:
                    fpath = self._disk_index.pop(k)
                    new_k = new_key + k[len(old_key) :]
                    self._disk_index[new_k] = fpath

    def _recalc_disk_size(self):
        total = 0
        for fpath in self._disk_index.values():
            try:
                total += os.path.getsize(fpath)
            except OSError:
                pass
        self._disk_size = total

    # Debug / metrics helpers
    def stats(self):
        with self._lock:
            return {
                "mem_entries": len(self._mem),
                "mem_size": self._mem_size,
                "disk_entries": len(self._disk_index),
                "disk_size": self._disk_size,
                "max_mem_size": self.max_mem_size,
                "max_disk_size": self.max_disk_size,
            }
