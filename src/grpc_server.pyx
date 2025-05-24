import os
from concurrent import futures

import grpc

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


class GrpcServer(Operations):
    def __init__(self, root_path: str):
        self.root_path = root_path

    def Exists(self, request: ExistsRequest, context, **kwargs) -> ExistsResponse:
        path = request.path
        exists = os.path.exists(self.root_path + path)
        return ExistsResponse(exists=exists)

    def GetAttr(self, request: GetAttrRequest, context, **kwargs) -> GetAttrResponse:
        path = request.path
        st = os.lstat(self.root_path + path)
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

    def ReadDir(self, request: ReadDirRequest, context, **kwargs) -> ReadDirResponse:
        path = request.path
        entries = os.listdir(self.root_path + path)
        return ReadDirResponse(entries=entries)

    def Read(self, request: ReadRequest, context, **kwargs) -> ReadResponse:
        path = request.path
        size = request.size
        offset = request.offset
        with open(self.root_path + path, "rb") as f:
            f.seek(offset)
            data = f.read(size)
        return ReadResponse(data=data)

    def Write(self, request: WriteRequest, context, **kwargs) -> WriteResponse:
        path = request.path
        data = request.data
        offset = request.offset
        with open(self.root_path + path, "r+b") as f:
            f.seek(offset)
            bytes_written = f.write(data)
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
        except PermissionError:
            return ChmodResponse(success=False)
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


def serve(root_path: str, port: int):
    server_options = [
        ("grpc.keepalive_time_ms", 10000),
        ("grpc.keepalive_timeout_ms", 5000),
        ("grpc.keepalive_permit_without_calls", True),
        ("grpc.http2.max_pings_without_calls", 0),
        ("grpc.max_connection_age_ms", 60000),
        ("grpc.max_connection_age_grace_ms", 10000),
    ]
    server = grpc.server(
        futures.ThreadPoolExecutor(max_workers=10), options=server_options
    )
    add_OperationsServicer_to_server(GrpcServer(root_path), server)
    server.add_insecure_port(f"[::]:{port}")
    server.start()
    server.wait_for_termination()
