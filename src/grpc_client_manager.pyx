import random

from grpc_client import GrpcClient
from redis_client import RedisClient


class GrpcClientManager:
    def __init__(self, redis_client: RedisClient, url: str):
        self.redis_client = redis_client
        self.url = url
        self.clients = {}  # addr -> GrpcClient
        self.register_self(url)
        self._load_initial_hosts()

    # ---- host management ----
    def register_self(self, url: str):
        self.redis_client.add_to_hosts(url)

    def _load_initial_hosts(self):
        for h in self.redis_client.get_hosts():
            addr = h.decode() if isinstance(h, (bytes, bytearray)) else str(h)
            if addr != self.url:
                self._ensure_client(addr)

    def sync_clients(self):
        for h in self.redis_client.get_hosts():
            addr = h.decode() if isinstance(h, (bytes, bytearray)) else str(h)
            if addr != self.url and addr not in self.clients:
                self._ensure_client(addr)

    def _ensure_client(self, address: str) -> GrpcClient:
        if address not in self.clients:
            self.clients[address] = GrpcClient(address)
        return self.clients[address]

    # ---- locations helper ----
    def _random_remote(self, path: str):
        locs = self.redis_client.get_locations(path)
        if not locs:
            return None
        remotes = [l for l in locs if l != self.url]
        if not remotes:
            return None
        addr = random.choice(remotes)
        self._ensure_client(addr)
        return addr

    # ---- initialization / shutdown ----
    def initialize_files(self, files):
        for f in files:
            try:
                self.redis_client.add_location(f, self.url)
            except Exception:
                pass

    def remove_manager(self, files):
        self.redis_client.remove_from_hosts(self.url)
        for f in files:
            try:
                self.redis_client.remove_location(f, self.url)
            except Exception:
                pass

    # ---- remote operations (None/False => fallback/local) ----
    def getattr(self, path):
        addr = self._random_remote(path)
        if not addr:
            return None
        return self.clients[addr].getattr(path)

    def readdir(self, path, offset):
        self.sync_clients()
        out = []
        for addr, cli in self.clients.items():
            try:
                if cli.exists(path):
                    out += cli.readdir(path, offset)
            except Exception:
                continue
        return out

    def read(self, path, size, offset):
        addr = self._random_remote(path)
        if not addr:
            return None
        return self.clients[addr].read(path, size, offset)

    def read_stream(self, path, size, offset):
        addr = self._random_remote(path)
        if not addr:
            return None
        return self.clients[addr].read_file_stream(path, size, offset)

    def write(self, path, buf, offset):
        parent = path.rsplit("/", 1)[0] or "/"
        addr = self._random_remote(parent)
        if not addr:
            return None
        return self.clients[addr].write(path, buf, offset)

    def truncate(self, path, size):
        addr = self._random_remote(path)
        if not addr:
            return None
        return self.clients[addr].truncate(path, size)

    def chown(self, path, uid, gid):
        addr = self._random_remote(path)
        if not addr:
            return None
        return self.clients[addr].chown(path, uid, gid)

    def chmod(self, path, mode):
        addr = self._random_remote(path)
        if not addr:
            return None
        return self.clients[addr].chmod(path, mode)

    def unlink(self, path):
        addr = self._random_remote(path)
        if not addr:
            return False
        ok = self.clients[addr].unlink(path)
        if ok:
            try:
                self.redis_client.remove_location(path, addr)
            except Exception:
                pass
        return ok

    def rmdir(self, path):
        addr = self._random_remote(path)
        if not addr:
            return False
        ok = self.clients[addr].rmdir(path)
        if ok:
            try:
                self.redis_client.remove_location(path, addr)
            except Exception:
                pass
        return ok

    def rename(self, old_path, new_path):
        addr = self._random_remote(old_path)
        if not addr:
            return False
        ok = self.clients[addr].rename(old_path, new_path)
        if ok:
            try:
                self.redis_client.remove_location(old_path, addr)
                self.redis_client.add_location(new_path, addr)
            except Exception:
                pass
        return ok

    def access(self, path, mode):
        addr = self._random_remote(path)
        if not addr:
            return False
        return self.clients[addr].access(path, mode)

    def utimens(self, path, times=None):
        addr = self._random_remote(path)
        if not addr:
            return False
        return self.clients[addr].utimens(path, times)

    def mkdir(self, path, parent_path, mode):
        addr = self._random_remote(parent_path)
        if not addr:
            return False
        ok = self.clients[addr].mkdir(path, mode)
        if ok:
            try:
                self.redis_client.add_location(path, addr)
            except Exception:
                pass
        return ok

    def create(self, path, parent_path, flags, mode):
        addr = self._random_remote(parent_path)
        if not addr:
            return False
        ok = self.clients[addr].create(path, flags, mode)
        if ok:
            try:
                self.redis_client.add_location(path, addr)
            except Exception:
                pass
        return ok

    # compatibility for metadata log hooks
    def set(self, path, address=None):
        try:
            self.redis_client.add_location(path, address if address else self.url)
        except Exception:
            pass

    def remove(self, path):
        try:
            self.redis_client.remove_location(path, self.url)
        except Exception:
            pass
