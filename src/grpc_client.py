import grpc

from multicloud_fs_pb2 import (ExistsRequest, GetAttrRequest, ReadDirRequest,
                               ReadRequest)
from multicloud_fs_pb2_grpc import OperationsStub


class GrpcClient:
    def __init__(self, address):
        self.channel = grpc.insecure_channel(address)
        self.stub = OperationsStub(self.channel)

    def exists(self, path):
        response = self.stub.Exists(ExistsRequest(path=path))
        return response.exists

    def getattr(self, path):
        response = self.stub.GetAttr(GetAttrRequest(path=path))
        return response

    def readdir(self, path, offset):
        response = self.stub.ReadDir(ReadDirRequest(path=path, offset=offset))
        return response.entries

    def read(self, path, size, offset):
        response = self.stub.Read(ReadRequest(path=path, size=size, offset=offset))
        return response.data
