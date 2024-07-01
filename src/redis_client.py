import redis


class RedisClient:
    def __init__(self, url: str):
        self.redis = redis.Redis.from_url(url)

    def get_hosts(self):
        return self.redis.smembers("hosts")

    def add_to_hosts(self, host):
        return self.redis.sadd("hosts", host)

    def remove_from_hosts(self, host):
        return self.redis.srem("hosts", host)

    def get(self, key):
        return self.redis.get(key)

    def set(self, key, value):
        return self.redis.set(key, value)

    def remove(self, key):
        return self.redis.delete(key)