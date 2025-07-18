import logging

import grpc

from multicloud_fs_pb2 import (
    AccessRequest,
    ChmodRequest,
    ChownRequest,
    CreateRequest,
    ExistsRequest,
    GetAttrRequest,
    GetAttrResponse,
    MkdirRequest,
    ReadDirRequest,
    ReadRequest,
    RenameRequest,
    RmdirRequest,
    TruncateRequest,
    UnlinkRequest,
    UtimensRequest,
    WriteRequest,
)
from multicloud_fs_pb2_grpc import OperationsStub


class GrpcClient:
    def __init__(self, address: str, timeout: int = 10):
        options = [
            ("grpc.max_send_message_length", 50 * 1024 * 1024),
            ("grpc.max_receive_message_length", 50 * 1024 * 1024),
            ("grpc.keepalive_time_ms", 20000),
            ("grpc.keepalive_timeout_ms", 10000),
            ("grpc.keepalive_permit_without_calls", True),
            ("grpc.http2.min_time_between_pings_ms", 10000),
            ("grpc.max_connection_age_ms", 300000),
            ("grpc.max_connection_age_grace_ms", 30000),
        ]
        self.channel = grpc.insecure_channel(address, options=options)
        self.stub = OperationsStub(self.channel)
        self.timeout = timeout

    def exists(self, path: str) -> bool:
        try:
            response = self.stub.Exists(ExistsRequest(path=path), timeout=self.timeout)
            return response.exists
        except grpc.RpcError as e:
            logging.warning("gRPC exists method error: %s", e.details())
            return False

    def getattr(self, path: str) -> GetAttrResponse:
        try:
            response = self.stub.GetAttr(
                GetAttrRequest(path=path), timeout=self.timeout
            )
            return response
        except grpc.RpcError as e:
            logging.warning("gRPC getattr method error: %s", e.details())
            return GetAttrResponse()

    def readdir(self, path: str, offset: int):
        try:
            response = self.stub.ReadDir(
                ReadDirRequest(path=path, offset=offset), timeout=self.timeout
            )
            return response.entries
        except grpc.RpcError as e:
            logging.warning("gRPC readdir method error: %s", e.details())
            return []

    def read(self, path: str, size: int, offset: int) -> bytes:
        try:
            response = self.stub.Read(
                ReadRequest(path=path, size=size, offset=offset), timeout=self.timeout
            )
            return response.data
        except grpc.RpcError as e:
            logging.warning("gRPC read method error: %s", e.details())
            return b""

    def write(self, path: str, data: bytes, offset: int) -> int:
        try:
            response = self.stub.Write(
                WriteRequest(path=path, data=data, offset=offset), timeout=self.timeout
            )
            return response.bytes_written
        except grpc.RpcError as e:
            logging.warning("gRPC write method error: %s", e.details())
            return -1

    def truncate(self, path: str, size: int):
        try:
            response = self.stub.Truncate(
                TruncateRequest(path=path, size=size), timeout=self.timeout
            )
            return response.success
        except grpc.RpcError as e:
            logging.warning("gRPC truncate method error: %s", e.details())
            return -1

    def chown(self, path: str, uid: int, gid: int):
        try:
            response = self.stub.Chown(
                ChownRequest(path=path, uid=uid, gid=gid), timeout=self.timeout
            )
            return response.success
        except grpc.RpcError as e:
            logging.warning("gRPC chown method error: %s", e.details())
            return -1

    def chmod(self, path: str, mode: int):
        try:
            response = self.stub.Chmod(
                ChmodRequest(path=path, mode=mode), timeout=self.timeout
            )
            return response.success
        except grpc.RpcError as e:
            logging.warning("gRPC chmod method error: %s", e.details())
            return -1

    def unlink(self, path: str) -> bool:
        try:
            response = self.stub.Unlink(UnlinkRequest(path=path), timeout=self.timeout)
            return response.success
        except grpc.RpcError as e:
            logging.warning("gRPC unlink method error: %s", e.details())
            return False

    def rmdir(self, path: str) -> bool:
        try:
            response = self.stub.Rmdir(RmdirRequest(path=path), timeout=self.timeout)
            return response.success
        except grpc.RpcError as e:
            logging.warning("gRPC rmdir method error: %s", e.details())
            return False

    def rename(self, old_path: str, new_path: str) -> bool:
        try:
            response = self.stub.Rename(
                RenameRequest(old_path=old_path, new_path=new_path),
                timeout=self.timeout,
            )
            return response.success
        except grpc.RpcError as e:
            logging.warning("gRPC rename method error: %s", e.details())
            return False

    def access(self, path: str, mode: int) -> bool:
        try:
            response = self.stub.Access(
                AccessRequest(path=path, mode=mode), timeout=self.timeout
            )
            return response.success
        except grpc.RpcError as e:
            logging.warning("gRPC access method error: %s", e.details())
            return False

    def utimens(self, path: str, times=None) -> bool:
        try:
            if times:
                atime, mtime = times
                request = UtimensRequest(
                    path=path,
                    has_times=True,
                    atime_sec=int(atime),
                    atime_nsec=int((atime - int(atime)) * 1e9),
                    mtime_sec=int(mtime),
                    mtime_nsec=int((mtime - int(mtime)) * 1e9),
                )
            else:
                request = UtimensRequest(path=path, has_times=False)

            response = self.stub.Utimens(request, timeout=self.timeout)
            return response.success
        except grpc.RpcError as e:
            logging.warning("gRPC utimens method error: %s", e.details())
            return False

    def mkdir(self, path: str, mode: int) -> bool:
        try:
            response = self.stub.Mkdir(
                MkdirRequest(path=path, mode=mode), timeout=self.timeout
            )
            return response.success
        except grpc.RpcError as e:
            logging.warning("gRPC mkdir method error: %s", e.details())
            return False

    def create(self, path: str, flags: int, mode: int) -> bool:
        try:
            response = self.stub.Create(
                CreateRequest(path=path, flags=flags, mode=mode), timeout=self.timeout
            )
            return response.success
        except grpc.RpcError as e:
            logging.warning("gRPC create method error: %s", e.details())
            return False
