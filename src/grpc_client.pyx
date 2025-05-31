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
        # Configure client with better keepalive settings and message sizes
        options = [
            # Increase maximum message size for large file transfers
            ('grpc.max_send_message_length', 50 * 1024 * 1024),  # 50 MB
            ('grpc.max_receive_message_length', 50 * 1024 * 1024),  # 50 MB
            # Client keepalive settings
            ('grpc.keepalive_time_ms', 15000),  # 15 seconds - send pings every 15 seconds
            ('grpc.keepalive_timeout_ms', 10000),  # 10 seconds - wait 10s for ping ack
            ('grpc.keepalive_permit_without_calls', True),  # Send pings even if idle
            ('grpc.http2.max_pings_without_data', 5),  # Allow up to 5 pings without data
            ('grpc.min_reconnect_backoff_ms', 1000),  # 1 second min reconnect backoff
            ('grpc.max_reconnect_backoff_ms', 10000),  # 10 seconds max reconnect backoff
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
