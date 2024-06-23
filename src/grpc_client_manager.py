from redis_client import RedisClient
from src.grpc_client import GrpcClient


class GrpcClientManager:
    def __init__(self, redis_url, url):
        self.redis_client = RedisClient(redis_url)
        self.clients = {}
        self.initialize_clients()
        self.url = url
        self.register_self(self.url)

    def initialize_files(self, files):
        for file in files:
            self.create(file)

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

    def create(self, path):
        self.redis_client.set(path, self.url)

    def remove(self, path):
        self.redis_client.remove(path)
