# cython: language_level=3
import os
import random

import redis


class RedisClient:
    def __init__(self, url: str):
        self.redis = redis.Redis.from_url(url)

    # ------------- path normalization -------------
    def _norm(self, path):  # return Python str object
        if not path:
            return "/"
        if not path.startswith("/"):
            path = "/" + path
        while "//" in path:
            path = path.replace("//", "/")
        if len(path) > 1 and path.endswith("/"):
            path = path.rstrip("/")
        return path or "/"

    def _inode_key(self, path):
        return "inode:" + self._norm(path)

    def _dir_key(self, path):
        return "dir:" + self._norm(path)

    # ------------- cluster hosts (unchanged semantics) -------------
    def get_hosts(self):
        return self.redis.smembers("hosts")

    def add_to_hosts(self, host):
        return self.redis.sadd("hosts", host)

    def remove_from_hosts(self, host):
        return self.redis.srem("hosts", host)

    # ------------- legacy simple key interface (kept for backward compat; avoid new usage) -------------
    def get(self, key):
        return self.redis.get(key)

    def set(self, key, value):
        return self.redis.set(key, value)

    def remove(self, key):
        return self.redis.delete(key)

    # ------------- inode metadata -------------
    def get_metadata(self, path):
        return self.redis.hgetall(self._inode_key(path))

    def set_metadata(self, path, metadata: dict):
        # Ensure stringified values
        p = self._norm(path)
        kv = {k: str(v) for k, v in metadata.items()}
        # Initialize locations field if absent
        if "locations" not in kv:
            existing = self.redis.hget(self._inode_key(p), "locations")
            if existing is None:
                kv["locations"] = ""
        return self.redis.hmset(self._inode_key(p), kv)

    def remove_metadata(self, path):
        return self.redis.delete(self._inode_key(path))

    # ------------- locations management -------------
    def get_locations(self, path: str):
        val = self.redis.hget(self._inode_key(path), "locations")
        if not val:
            return []
        s = val.decode() if isinstance(val, (bytes, bytearray)) else str(val)
        return [x for x in s.split(";") if x]

    def add_location(self, path: str, address: str):
        key = self._inode_key(path)
        pipe = self.redis.pipeline()
        while True:
            try:
                pipe.watch(key)
                current = pipe.hget(key, "locations")
                if current:
                    txt = (
                        current.decode()
                        if isinstance(current, (bytes, bytearray))
                        else str(current)
                    )
                    parts = [x for x in txt.split(";") if x]
                    if address in parts:
                        pipe.unwatch()
                        return True
                    parts.append(address)
                    new_val = ";".join(parts)
                else:
                    new_val = address
                pipe.multi()
                pipe.hset(key, "locations", new_val)
                pipe.execute()
                return True
            except redis.WatchError:
                continue
            finally:
                try:
                    pipe.reset()
                except Exception:
                    pass

    def remove_location(self, path: str, address: str):
        key = self._inode_key(path)
        pipe = self.redis.pipeline()
        while True:
            try:
                pipe.watch(key)
                current = pipe.hget(key, "locations")
                if not current:
                    pipe.unwatch()
                    return False
                txt = (
                    current.decode()
                    if isinstance(current, (bytes, bytearray))
                    else str(current)
                )
                parts = [x for x in txt.split(";") if x]
                if address not in parts:
                    pipe.unwatch()
                    return False
                parts = [x for x in parts if x != address]
                new_val = ";".join(parts)
                pipe.multi()
                pipe.hset(key, "locations", new_val)
                pipe.execute()
                return True
            except redis.WatchError:
                continue
            finally:
                try:
                    pipe.reset()
                except Exception:
                    pass

    # ------------- directory set ops -------------
    def add_to_dir(self, dir_path, item):
        return self.redis.sadd(self._dir_key(dir_path), item)

    def remove_from_dir(self, dir_path, item):
        return self.redis.srem(self._dir_key(dir_path), item)

    def get_dir(self, dir_path):
        return self.redis.smembers(self._dir_key(dir_path))

    def remove_dir(self, dir_path):
        return self.redis.delete(self._dir_key(dir_path))

    # ------------- helper for random location selection -------------
    def random_location(self, path: str):
        locs = self.get_locations(path)
        if not locs:
            return None
        return random.choice(locs)
