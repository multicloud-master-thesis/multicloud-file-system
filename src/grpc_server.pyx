import os
from concurrent import futures

import grpc

from cache_manager import MAX_MEM_CACHE_FILE_SIZE, CacheManager
from multicloud_fs_pb2 import DataChunk  # added for streaming
from multicloud_fs_pb2 import (
    AccessRequest,
    AccessResponse,
    ChmodRequest,
    ChmodResponse,
    ChownRequest,
    ChownResponse,
    CreateRequest,
    CreateResponse,
    ExistsRequest,
    ExistsResponse,
    GetAttrRequest,
    GetAttrResponse,
    MkdirRequest,
    MkdirResponse,
    ReadDirRequest,
    ReadDirResponse,
    ReadRequest,
    ReadResponse,
    RenameRequest,
    RenameResponse,
    RmdirRequest,
    RmdirResponse,
    TruncateRequest,
    TruncateResponse,
    UnlinkRequest,
    UnlinkResponse,
    UtimensRequest,
    UtimensResponse,
    WriteRequest,
    WriteResponse,
)
from multicloud_fs_pb2_grpc import Operations, add_OperationsServicer_to_server
from redis_client import RedisClient


class GrpcServer(Operations):
    def __init__(
        self,
        root_path: str,
        cache: CacheManager | None = None,
        redis_client: RedisClient | None = None,
        client_url: str | None = None,
    ):
        self.root_path = root_path
        self.cache = cache
        self.redis = redis_client
        self.client_url = client_url

    def _register_cache_location(self, path: str):
        if not (self.redis and self.client_url):
            return
        try:
            locs = self.redis.get_locations(path)
            if self.client_url not in locs:
                self.redis.add_location(path, self.client_url)
        except Exception:
            pass

    def Exists(self, request: ExistsRequest, context, **kwargs) -> ExistsResponse:
        path = request.path
        if self.cache and self.cache.has(path):
            self._register_cache_location(path)
            return ExistsResponse(exists=True)
        exists = os.path.exists(self.root_path + path)
        return ExistsResponse(exists=exists)

    def GetAttr(self, request: GetAttrRequest, context, **kwargs) -> GetAttrResponse:
        path = request.path
        full = self.root_path + path
        try:
            st = os.lstat(full)
            return GetAttrResponse(
                st_mode=st.st_mode,
                st_ino=st.st_ino,
                st_dev=st.st_dev,
                st_nlink=st.st_nlink,
                st_uid=st.st_uid,
                st_gid=st.st_gid,
                st_size=st.st_size,
                st_atime=st.st_atime,
                st_mtime=st.st_mtime,
                st_ctime=st.st_ctime,
            )
        except OSError:
            # Try redis metadata if cached (file not on local disk but in cache)
            if self.cache and self.cache.has(path) and self.redis:
                try:
                    meta = self.redis.get_metadata(path) or {}

                    def _g(k, dv=0):
                        v = (
                            meta.get(k if isinstance(k, bytes) else k.encode())
                            if isinstance(meta, dict)
                            else None
                        )
                        if v is None:
                            return dv
                        try:
                            return int(v)
                        except Exception:
                            try:
                                return float(v)
                            except Exception:
                                return dv

                    return GetAttrResponse(
                        st_mode=_g("st_mode"),
                        st_ino=_g("st_ino"),
                        st_dev=_g("st_dev"),
                        st_nlink=_g("st_nlink"),
                        st_uid=_g("st_uid"),
                        st_gid=_g("st_gid"),
                        st_size=_g("st_size"),
                        st_atime=float(_g("st_atime")),
                        st_mtime=float(_g("st_mtime")),
                        st_ctime=float(_g("st_ctime")),
                    )
                except Exception:
                    pass
        return GetAttrResponse()  # default (zeros) – client interprets as miss

    def ReadDir(self, request: ReadDirRequest, context, **kwargs) -> ReadDirResponse:
        path = request.path
        entries = []
        try:
            entries = os.listdir(self.root_path + path)
        except Exception:
            pass
        return ReadDirResponse(entries=entries)

    def Read(self, request: ReadRequest, context, **kwargs) -> ReadResponse:
        path = request.path
        size = request.size
        offset = request.offset
        # Serve from cache first
        if self.cache:
            try:
                data = self.cache.get(path, offset, size)
                if data is not None:
                    self._register_cache_location(path)
                    return ReadResponse(data=data)
            except Exception:
                pass
        # Disk fallback
        with open(self.root_path + path, "rb") as f:
            f.seek(offset)
            data = f.read(size)
        return ReadResponse(data=data)

    def ReadFile(self, request: ReadRequest, context, **kwargs):  # streaming
        path = request.path
        offset = request.offset
        size = request.size
        full_path = self.root_path + path
        CHUNK_SIZE = 1024 * 1024  # 1MB per chunk

        # If cached (only small files) we can emit directly from cache slice
        if self.cache:
            try:
                # If size<=0 interpret as full file (get entire cached file)
                slice_size = (
                    size if size > 0 else MAX_MEM_CACHE_FILE_SIZE + 1
                )  # ensure full retrieval
                data = self.cache.get(path, offset, slice_size)
                if data is not None:
                    # If size was 0 we might have truncated; just stream what we got
                    self._register_cache_location(path)
                    # Break into chunks to avoid single huge message
                    view = memoryview(data)
                    sent = 0
                    total = len(data)
                    while sent < total:
                        chunk = view[sent : sent + CHUNK_SIZE].tobytes()
                        if not chunk:
                            break
                        yield DataChunk(content=chunk)
                        sent += len(chunk)
                    return
            except Exception:
                pass

        # Disk streaming fallback
        try:
            with open(full_path, "rb") as f:
                # Determine how many bytes to stream
                if offset:
                    f.seek(offset)
                remaining = size
                # If size <=0 or beyond EOF treat as until EOF
                if remaining <= 0:
                    remaining = None  # sentinel for full
                while True:
                    to_read = (
                        CHUNK_SIZE if remaining is None else min(CHUNK_SIZE, remaining)
                    )
                    if to_read == 0:
                        break
                    data = f.read(to_read)
                    if not data:
                        break
                    yield DataChunk(content=data)
                    if remaining is not None:
                        remaining -= len(data)
                        if remaining <= 0:
                            break
            # Register location after successful streaming start
            try:
                self._register_cache_location(path)
            except Exception:
                pass
        except FileNotFoundError:
            context.set_code(grpc.StatusCode.NOT_FOUND)
            context.set_details("File not found")
        except Exception as e:
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(f"I/O error: {e}")

    def Write(self, request: WriteRequest, context, **kwargs) -> WriteResponse:
        path = request.path
        data = request.data
        offset = request.offset
        with open(self.root_path + path, "r+b") as f:
            f.seek(offset)
            bytes_written = f.write(data)
        # Optionally update cache only for small files full overwrite
        if self.cache and offset == 0 and len(data) <= MAX_MEM_CACHE_FILE_SIZE:
            try:
                self.cache.put(path, data)
                self._register_cache_location(path)
            except Exception:
                pass
        return WriteResponse(bytes_written=bytes_written)

    def Truncate(self, request: TruncateRequest, context, **kwargs) -> TruncateResponse:
        path = request.path
        size = request.size
        with open(self.root_path + path, "r+b") as f:
            f.truncate(size)
        return TruncateResponse(success=True)

    def Chown(self, request: ChownRequest, context, **kwargs) -> ChownResponse:
        path = request.path
        uid = request.uid
        gid = request.gid
        try:
            os.chown(self.root_path + path, uid, gid)
            return ChownResponse(success=True)
        except PermissionError:
            return ChownResponse(success=False)

    def Chmod(self, request: ChmodRequest, context, **kwargs) -> ChmodResponse:
        path = request.path
        mode = request.mode
        try:
            os.chmod(self.root_path + path, mode)
            return ChmodResponse(success=True)
        except Exception:
            return ChmodResponse(success=False)

    def Unlink(self, request: UnlinkRequest, context, **kwargs) -> UnlinkResponse:
        path = request.path
        try:
            os.unlink(self.root_path + path)
            return UnlinkResponse(success=True)
        except Exception:
            return UnlinkResponse(success=False)

    def Rmdir(self, request: RmdirRequest, context, **kwargs) -> RmdirResponse:
        path = request.path
        try:
            os.rmdir(self.root_path + path)
            return RmdirResponse(success=True)
        except Exception:
            return RmdirResponse(success=False)

    def Rename(self, request: RenameRequest, context, **kwargs) -> RenameResponse:
        old_path = request.old_path
        new_path = request.new_path
        try:
            os.rename(self.root_path + old_path, self.root_path + new_path)
            return RenameResponse(success=True)
        except Exception:
            return RenameResponse(success=False)

    def Access(self, request: AccessRequest, context, **kwargs) -> AccessResponse:
        path = request.path
        mode = request.mode
        # Cache considered readable
        if self.cache and self.cache.has(path) and mode & os.R_OK:
            self._register_cache_location(path)
            return AccessResponse(success=True)
        try:
            result = os.access(self.root_path + path, mode)
            return AccessResponse(success=result)
        except Exception:
            return AccessResponse(success=False)

    def Utimens(self, request: UtimensRequest, context, **kwargs) -> UtimensResponse:
        path = request.path
        try:
            if request.has_times:
                atime = request.atime_sec + (request.atime_nsec / 1e9)
                mtime = request.mtime_sec + (request.mtime_nsec / 1e9)
                os.utime(self.root_path + path, (atime, mtime))
            else:
                os.utime(self.root_path + path, None)
            return UtimensResponse(success=True)
        except Exception:
            return UtimensResponse(success=False)

    def Mkdir(self, request: MkdirRequest, context, **kwargs) -> MkdirResponse:
        path = request.path
        mode = request.mode
        try:
            os.mkdir(self.root_path + path, mode)
            return MkdirResponse(success=True)
        except Exception:
            return MkdirResponse(success=False)

    def Create(self, request: CreateRequest, context, **kwargs) -> CreateResponse:
        path = request.path
        flags = request.flags
        mode = request.mode
        try:
            fd = os.open(self.root_path + path, flags, mode)
            os.close(fd)
            return CreateResponse(success=True)
        except Exception:
            return CreateResponse(success=False)


def serve(
    root_path: str,
    port: int,
    cache: CacheManager | None = None,
    redis_client: RedisClient | None = None,
    client_url: str | None = None,
):
    server_options = [
        ("grpc.keepalive_time_ms", 20000),
        ("grpc.keepalive_timeout_ms", 10000),
        ("grpc.keepalive_permit_without_calls", True),
        ("grpc.http2.min_time_between_pings_ms", 10000),
        ("grpc.max_connection_age_ms", 300000),
        ("grpc.max_connection_age_grace_ms", 30000),
        ("grpc.http2.max_pings_without_data", 0),
    ]
    server = grpc.server(
        futures.ThreadPoolExecutor(max_workers=30), options=server_options
    )
    add_OperationsServicer_to_server(
        GrpcServer(
            root_path, cache=cache, redis_client=redis_client, client_url=client_url
        ),
        server,
    )
    server.add_insecure_port(f"[::]:{port}")
    server.start()
    server.wait_for_termination()
