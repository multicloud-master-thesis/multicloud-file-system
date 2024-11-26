import os
from concurrent import futures

import grpc

from multicloud_fs_pb2 import (
    ExistsRequest,
    ExistsResponse,
    GetAttrRequest,
    GetAttrResponse,
    ReadDirRequest,
    ReadDirResponse,
    ReadRequest,
    ReadResponse,
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


def serve(root_path: str, port: int):
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    add_OperationsServicer_to_server(GrpcServer(root_path), server)
    server.add_insecure_port(f"[::]:{port}")
    server.start()
    server.wait_for_termination()
