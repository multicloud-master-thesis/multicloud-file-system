import hashlib
import os
from collections import OrderedDict
from threading import RLock
from typing import Optional

MAX_MEM_CACHE_SIZE = 64 * 1024 * 1024  # 64 MB total in-memory cache
MAX_DISK_CACHE_SIZE = 1024 * 1024 * 1024  # 1 GB total on-disk cache
MAX_MEM_CACHE_FILE_SIZE = 4 * 1024 * 1024  # Only files <=4MB stored in memory
DISK_CACHE_DIR = os.environ.get("MULTICLOUD_FS_DISK_CACHE", "/var/cache/multicloudfs")


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
        # Track cached byte ranges per key to avoid serving holes
        self._extents: dict[str, list[tuple[int, int]]] = {}

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

    def _add_extent(self, key: str, start: int, end: int):
        if start >= end:
            return
        arr = self._extents.get(key)
        if not arr:
            self._extents[key] = [(start, end)]
            return
        # insert and merge intervals
        new = []
        placed = False
        for s, e in arr:
            if e < start:
                new.append((s, e))
            elif end < s:
                if not placed:
                    new.append((start, end))
                    placed = True
                new.append((s, e))
            else:
                # overlap; merge
                start = min(start, s)
                end = max(end, e)
        if not placed:
            new.append((start, end))
        # merge adjacent
        new.sort()
        merged = []
        for s, e in new:
            if not merged or s > merged[-1][1]:
                merged.append((s, e))
            else:
                merged[-1] = (merged[-1][0], max(merged[-1][1], e))
        self._extents[key] = merged

    def _covered_len(self, key: str, offset: int, size: int) -> int:
        if size <= 0:
            return 0
        arr = self._extents.get(key)
        if not arr:
            return 0
        end_req = offset + size
        # find interval covering offset
        for s, e in arr:
            if s <= offset < e:
                return min(e, end_req) - offset
            if offset < s and s < end_req:
                # gap before next extent
                return 0
        return 0

    # ------------- public API -------------
    def get(self, path: str, offset: int, size: int) -> Optional[bytes]:
        key = self._norm(path)
        with self._lock:
            # Only serve from cache when the requested slice is fully covered by cached extents
            if size <= 0:
                return None
            avail = self._covered_len(key, offset, size)
            if avail < size:
                return None
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
                    try:
                        del self._disk_index[key]
                    except KeyError:
                        pass
        return None

    def has(self, path: str) -> bool:
        key = self._norm(path)
        with self._lock:
            return key in self._mem or key in self._disk_index

    def put(self, path: str, data: bytes, offset: int = 0):
        key = self._norm(path)
        size = len(data)
        with self._lock:
            # Always write to disk first (sparse write; do not pad holes)
            fpath = self._disk_path(key)
            try:
                with open(fpath, "r+b" if os.path.exists(fpath) else "wb") as f:
                    if offset > 0:
                        f.seek(offset)
                    f.write(data)
                if key not in self._disk_index:
                    self._disk_index[key] = fpath
                else:
                    self._disk_index.pop(key)
                    self._disk_index[key] = fpath
                self._recalc_disk_size()
                self._evict_disk()
            except OSError:
                pass

            # Optionally store in memory
            if size <= self.max_mem_file:
                if offset > 0 and key in self._mem:
                    existing_data = self._mem.pop(key)
                    self._mem_size -= len(existing_data)
                    new_size = max(len(existing_data), offset + size)
                    new_data = bytearray(new_size)
                    new_data[: len(existing_data)] = existing_data
                    new_data[offset : offset + size] = data
                    data = bytes(new_data)
                prev = self._mem.pop(key, None)
                if prev is not None:
                    self._mem_size -= len(prev)
                self._mem[key] = data
                self._mem_size += len(data)
                self._evict_mem()

            # Record extent for both disk and memory
            self._add_extent(key, offset, offset + size)

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
            # clear extents
            if key in self._extents:
                del self._extents[key]

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
            # Remove extents with prefix
            to_del = [k for k in self._extents if k == norm_prefix or k.startswith(norm_prefix + "/")]
            for k in to_del:
                del self._extents[k]

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

            # Move extents
            if old_key in self._extents:
                self._extents[new_key] = self._extents.pop(old_key)
            old_prefix = old_key + "/"
            if any(k.startswith(old_prefix) for k in list(self._extents.keys())):
                renames = [k for k in list(self._extents.keys()) if k.startswith(old_prefix)]
                for k in renames:
                    ext = self._extents.pop(k)
                    nk = new_key + k[len(old_key) :]
                    self._extents[nk] = ext

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
