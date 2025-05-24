from grpc_client import GrpcClient
from redis_client import RedisClient


class GrpcClientManager:
    def __init__(self, redis_url, url):
        self.redis_client = RedisClient(redis_url)
        self.clients = {}
        self.initialize_clients()
        self.url = url
        self.register_self(self.url)

    def initialize_files(self, files):
        for file in files:
            self.set(file)

    def remove_manager(self, files):
        self.redis_client.remove_from_hosts(self.url)
        for file in files:
            self.redis_client.remove(file)

    def initialize_clients(self):
        hosts = self.redis_client.get_hosts()
        for host in hosts:
            self.add_client(host)

    def register_self(self, url):
        self.redis_client.add_to_hosts(url)

    def sync_clients(self):
        hosts = self.redis_client.get_hosts()
        for host in hosts:
            if host not in self.clients and host != self.url.encode():
                self.add_client(host)

    def add_client(self, url):
        self.clients[url] = GrpcClient(url.decode())

    def getattr(self, path):
        client_url = self.redis_client.get(path)
        if not client_url:
            return None
        if client_url not in self.clients:
            self.add_client(client_url)

        return self.clients[client_url].getattr(path)

    def readdir(self, path, offset):
        self.sync_clients()
        entries = []
        for client in self.clients.values():
            if client.exists(path):
                entries += client.readdir(path, offset)
        return entries

    def read(self, path, size, offset):
        client_url = self.redis_client.get(path)
        if not client_url:
            return None
        if client_url not in self.clients:
            self.add_client(client_url)

        return self.clients[client_url].read(path, size, offset)

    def write(self, path, buf, offset):
        client_url = self.redis_client.get(path)
        if not client_url:
            return None
        if client_url not in self.clients:
            self.add_client(client_url)

        return self.clients[client_url].write(path, buf, offset)

    def truncate(self, path, size):
        client_url = self.redis_client.get(path)
        if not client_url:
            return None
        if client_url not in self.clients:
            self.add_client(client_url)

        return self.clients[client_url].truncate(path, size)

    def chown(self, path, uid, gid):
        client_url = self.redis_client.get(path)
        if not client_url:
            return None
        if client_url not in self.clients:
            self.add_client(client_url)

        return self.clients[client_url].chown(path, uid, gid)

    def chmod(self, path, mode):
        client_url = self.redis_client.get(path)
        if not client_url:
            return None
        if client_url not in self.clients:
            self.add_client(client_url)

        return self.clients[client_url].chmod(path, mode)

    def unlink(self, path):
        client_url = self.redis_client.get(path)
        if not client_url:
            return None
        if client_url not in self.clients:
            self.add_client(client_url)

        result = self.clients[client_url].unlink(path)
        if result:
            self.remove(path)
        return result

    def rmdir(self, path):
        client_url = self.redis_client.get(path)
        if not client_url:
            return None
        if client_url not in self.clients:
            self.add_client(client_url)

        result = self.clients[client_url].rmdir(path)
        if result:
            self.remove(path)
        return result

    def rename(self, old_path, new_path):
        client_url = self.redis_client.get(old_path)
        if not client_url:
            return None
        if client_url not in self.clients:
            self.add_client(client_url)

        result = self.clients[client_url].rename(old_path, new_path)
        if result:
            self.remove(old_path)
            self.set(new_path, client_url)
        return result

    def access(self, path, mode):
        client_url = self.redis_client.get(path)
        if not client_url:
            return None
        if client_url not in self.clients:
            self.add_client(client_url)

        return self.clients[client_url].access(path, mode)

    def utimens(self, path, times=None):
        client_url = self.redis_client.get(path)
        if not client_url:
            return None
        if client_url not in self.clients:
            self.add_client(client_url)

        return self.clients[client_url].utimens(path, times)

    def mkdir(self, path, parent_path, mode):
        client_url = self.redis_client.get(parent_path)
        if not client_url:
            return None
        if client_url not in self.clients:
            self.add_client(client_url)

        result = self.clients[client_url].mkdir(path, mode)
        if result:
            self.set(path, client_url)
        return result

    def create(self, path, parent_path, flags, mode):
        client_url = self.redis_client.get(parent_path)
        if not client_url:
            return None
        if client_url not in self.clients:
            self.add_client(client_url)

        result = self.clients[client_url].create(path, flags, mode)
        if result:
            self.set(path, client_url)
        return result

    def set(self, path, address=None):
        url = address if address else self.url
        self.redis_client.set(path, url)

    def remove(self, path):
        self.redis_client.remove(path)
