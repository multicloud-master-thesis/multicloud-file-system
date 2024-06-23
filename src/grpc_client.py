import logging

import grpc

from multicloud_fs_pb2 import (
    ExistsRequest,
    GetAttrRequest,
    GetAttrResponse,
    ReadDirRequest,
    ReadRequest,
)
from multicloud_fs_pb2_grpc import OperationsStub


class GrpcClient:
    def __init__(self, address: str):
        self.channel = grpc.insecure_channel(address)
        self.stub = OperationsStub(self.channel)

    def exists(self, path: str) -> bool:
        try:
            response = self.stub.Exists(ExistsRequest(path=path), timeout=3)
            return response.exists
        except grpc.RpcError as e:
            logging.warning("gRPC exists method error: %s", e.details())
            return False

    def getattr(self, path: str) -> GetAttrResponse:
        try:
            response = self.stub.GetAttr(GetAttrRequest(path=path), timeout=3)
            return response
        except grpc.RpcError as e:
            logging.warning("gRPC getattr method error: %s", e.details())
            return GetAttrResponse()

    def readdir(self, path: str, offset: int) -> list[str]:
        try:
            response = self.stub.ReadDir(
                ReadDirRequest(path=path, offset=offset), timeout=3
            )
            return response.entries
        except grpc.RpcError as e:
            logging.warning("gRPC readdir method error: %s", e.details())
            return []

    def read(self, path: str, size: int, offset: int) -> bytes:
        try:
            response = self.stub.Read(
                ReadRequest(path=path, size=size, offset=offset), timeout=3
            )
            return response.data
        except grpc.RpcError as e:
            logging.warning("gRPC read method error: %s", e.details())
            return b""
