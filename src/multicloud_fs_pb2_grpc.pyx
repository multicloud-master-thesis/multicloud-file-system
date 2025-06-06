# Generated by the gRPC Python protocol compiler plugin. DO NOT EDIT!
"""Client and server classes corresponding to protobuf-defined services."""
import warnings

import grpc

import multicloud_fs_pb2 as multicloud__fs__pb2

GRPC_GENERATED_VERSION = "1.71.0"
GRPC_VERSION = grpc.__version__
_version_not_supported = False

try:
    from grpc._utilities import first_version_is_lower

    _version_not_supported = first_version_is_lower(
        GRPC_VERSION, GRPC_GENERATED_VERSION
    )
except ImportError:
    _version_not_supported = True

if _version_not_supported:
    raise RuntimeError(
        f"The grpc package installed is at version {GRPC_VERSION},"
        + f" but the generated code in multicloud_fs_pb2_grpc.py depends on"
        + f" grpcio>={GRPC_GENERATED_VERSION}."
        + f" Please upgrade your grpc module to grpcio>={GRPC_GENERATED_VERSION}"
        + f" or downgrade your generated code using grpcio-tools<={GRPC_VERSION}."
    )


class OperationsStub(object):
    """Missing associated documentation comment in .proto file."""

    def __init__(self, channel):
        """Constructor.

        Args:
            channel: A grpc.Channel.
        """
        self.Exists = channel.unary_unary(
            "/multi_cloud_fs.Operations/Exists",
            request_serializer=multicloud__fs__pb2.ExistsRequest.SerializeToString,
            response_deserializer=multicloud__fs__pb2.ExistsResponse.FromString,
            _registered_method=True,
        )
        self.GetAttr = channel.unary_unary(
            "/multi_cloud_fs.Operations/GetAttr",
            request_serializer=multicloud__fs__pb2.GetAttrRequest.SerializeToString,
            response_deserializer=multicloud__fs__pb2.GetAttrResponse.FromString,
            _registered_method=True,
        )
        self.ReadDir = channel.unary_unary(
            "/multi_cloud_fs.Operations/ReadDir",
            request_serializer=multicloud__fs__pb2.ReadDirRequest.SerializeToString,
            response_deserializer=multicloud__fs__pb2.ReadDirResponse.FromString,
            _registered_method=True,
        )
        self.Read = channel.unary_unary(
            "/multi_cloud_fs.Operations/Read",
            request_serializer=multicloud__fs__pb2.ReadRequest.SerializeToString,
            response_deserializer=multicloud__fs__pb2.ReadResponse.FromString,
            _registered_method=True,
        )
        self.Write = channel.unary_unary(
            "/multi_cloud_fs.Operations/Write",
            request_serializer=multicloud__fs__pb2.WriteRequest.SerializeToString,
            response_deserializer=multicloud__fs__pb2.WriteResponse.FromString,
            _registered_method=True,
        )
        self.Truncate = channel.unary_unary(
            "/multi_cloud_fs.Operations/Truncate",
            request_serializer=multicloud__fs__pb2.TruncateRequest.SerializeToString,
            response_deserializer=multicloud__fs__pb2.TruncateResponse.FromString,
            _registered_method=True,
        )
        self.Chown = channel.unary_unary(
            "/multi_cloud_fs.Operations/Chown",
            request_serializer=multicloud__fs__pb2.ChownRequest.SerializeToString,
            response_deserializer=multicloud__fs__pb2.ChownResponse.FromString,
            _registered_method=True,
        )
        self.Chmod = channel.unary_unary(
            "/multi_cloud_fs.Operations/Chmod",
            request_serializer=multicloud__fs__pb2.ChmodRequest.SerializeToString,
            response_deserializer=multicloud__fs__pb2.ChmodResponse.FromString,
            _registered_method=True,
        )
        self.Unlink = channel.unary_unary(
            "/multi_cloud_fs.Operations/Unlink",
            request_serializer=multicloud__fs__pb2.UnlinkRequest.SerializeToString,
            response_deserializer=multicloud__fs__pb2.UnlinkResponse.FromString,
            _registered_method=True,
        )
        self.Rmdir = channel.unary_unary(
            "/multi_cloud_fs.Operations/Rmdir",
            request_serializer=multicloud__fs__pb2.RmdirRequest.SerializeToString,
            response_deserializer=multicloud__fs__pb2.RmdirResponse.FromString,
            _registered_method=True,
        )
        self.Rename = channel.unary_unary(
            "/multi_cloud_fs.Operations/Rename",
            request_serializer=multicloud__fs__pb2.RenameRequest.SerializeToString,
            response_deserializer=multicloud__fs__pb2.RenameResponse.FromString,
            _registered_method=True,
        )
        self.Access = channel.unary_unary(
            "/multi_cloud_fs.Operations/Access",
            request_serializer=multicloud__fs__pb2.AccessRequest.SerializeToString,
            response_deserializer=multicloud__fs__pb2.AccessResponse.FromString,
            _registered_method=True,
        )
        self.Utimens = channel.unary_unary(
            "/multi_cloud_fs.Operations/Utimens",
            request_serializer=multicloud__fs__pb2.UtimensRequest.SerializeToString,
            response_deserializer=multicloud__fs__pb2.UtimensResponse.FromString,
            _registered_method=True,
        )
        self.Mkdir = channel.unary_unary(
            "/multi_cloud_fs.Operations/Mkdir",
            request_serializer=multicloud__fs__pb2.MkdirRequest.SerializeToString,
            response_deserializer=multicloud__fs__pb2.MkdirResponse.FromString,
            _registered_method=True,
        )
        self.Create = channel.unary_unary(
            "/multi_cloud_fs.Operations/Create",
            request_serializer=multicloud__fs__pb2.CreateRequest.SerializeToString,
            response_deserializer=multicloud__fs__pb2.CreateResponse.FromString,
            _registered_method=True,
        )


class OperationsServicer(object):
    """Missing associated documentation comment in .proto file."""

    def Exists(self, request, context):
        """Missing associated documentation comment in .proto file."""
        context.set_code(grpc.StatusCode.UNIMPLEMENTED)
        context.set_details("Method not implemented!")
        raise NotImplementedError("Method not implemented!")

    def GetAttr(self, request, context):
        """Missing associated documentation comment in .proto file."""
        context.set_code(grpc.StatusCode.UNIMPLEMENTED)
        context.set_details("Method not implemented!")
        raise NotImplementedError("Method not implemented!")

    def ReadDir(self, request, context):
        """Missing associated documentation comment in .proto file."""
        context.set_code(grpc.StatusCode.UNIMPLEMENTED)
        context.set_details("Method not implemented!")
        raise NotImplementedError("Method not implemented!")

    def Read(self, request, context):
        """Missing associated documentation comment in .proto file."""
        context.set_code(grpc.StatusCode.UNIMPLEMENTED)
        context.set_details("Method not implemented!")
        raise NotImplementedError("Method not implemented!")

    def Write(self, request, context):
        """Missing associated documentation comment in .proto file."""
        context.set_code(grpc.StatusCode.UNIMPLEMENTED)
        context.set_details("Method not implemented!")
        raise NotImplementedError("Method not implemented!")

    def Truncate(self, request, context):
        """Missing associated documentation comment in .proto file."""
        context.set_code(grpc.StatusCode.UNIMPLEMENTED)
        context.set_details("Method not implemented!")
        raise NotImplementedError("Method not implemented!")

    def Chown(self, request, context):
        """Missing associated documentation comment in .proto file."""
        context.set_code(grpc.StatusCode.UNIMPLEMENTED)
        context.set_details("Method not implemented!")
        raise NotImplementedError("Method not implemented!")

    def Chmod(self, request, context):
        """Missing associated documentation comment in .proto file."""
        context.set_code(grpc.StatusCode.UNIMPLEMENTED)
        context.set_details("Method not implemented!")
        raise NotImplementedError("Method not implemented!")

    def Unlink(self, request, context):
        """Missing associated documentation comment in .proto file."""
        context.set_code(grpc.StatusCode.UNIMPLEMENTED)
        context.set_details("Method not implemented!")
        raise NotImplementedError("Method not implemented!")

    def Rmdir(self, request, context):
        """Missing associated documentation comment in .proto file."""
        context.set_code(grpc.StatusCode.UNIMPLEMENTED)
        context.set_details("Method not implemented!")
        raise NotImplementedError("Method not implemented!")

    def Rename(self, request, context):
        """Missing associated documentation comment in .proto file."""
        context.set_code(grpc.StatusCode.UNIMPLEMENTED)
        context.set_details("Method not implemented!")
        raise NotImplementedError("Method not implemented!")

    def Access(self, request, context):
        """Missing associated documentation comment in .proto file."""
        context.set_code(grpc.StatusCode.UNIMPLEMENTED)
        context.set_details("Method not implemented!")
        raise NotImplementedError("Method not implemented!")

    def Utimens(self, request, context):
        """Missing associated documentation comment in .proto file."""
        context.set_code(grpc.StatusCode.UNIMPLEMENTED)
        context.set_details("Method not implemented!")
        raise NotImplementedError("Method not implemented!")

    def Mkdir(self, request, context):
        """Missing associated documentation comment in .proto file."""
        context.set_code(grpc.StatusCode.UNIMPLEMENTED)
        context.set_details("Method not implemented!")
        raise NotImplementedError("Method not implemented!")

    def Create(self, request, context):
        """Missing associated documentation comment in .proto file."""
        context.set_code(grpc.StatusCode.UNIMPLEMENTED)
        context.set_details("Method not implemented!")
        raise NotImplementedError("Method not implemented!")


def add_OperationsServicer_to_server(servicer, server):
    rpc_method_handlers = {
        "Exists": grpc.unary_unary_rpc_method_handler(
            servicer.Exists,
            request_deserializer=multicloud__fs__pb2.ExistsRequest.FromString,
            response_serializer=multicloud__fs__pb2.ExistsResponse.SerializeToString,
        ),
        "GetAttr": grpc.unary_unary_rpc_method_handler(
            servicer.GetAttr,
            request_deserializer=multicloud__fs__pb2.GetAttrRequest.FromString,
            response_serializer=multicloud__fs__pb2.GetAttrResponse.SerializeToString,
        ),
        "ReadDir": grpc.unary_unary_rpc_method_handler(
            servicer.ReadDir,
            request_deserializer=multicloud__fs__pb2.ReadDirRequest.FromString,
            response_serializer=multicloud__fs__pb2.ReadDirResponse.SerializeToString,
        ),
        "Read": grpc.unary_unary_rpc_method_handler(
            servicer.Read,
            request_deserializer=multicloud__fs__pb2.ReadRequest.FromString,
            response_serializer=multicloud__fs__pb2.ReadResponse.SerializeToString,
        ),
        "Write": grpc.unary_unary_rpc_method_handler(
            servicer.Write,
            request_deserializer=multicloud__fs__pb2.WriteRequest.FromString,
            response_serializer=multicloud__fs__pb2.WriteResponse.SerializeToString,
        ),
        "Truncate": grpc.unary_unary_rpc_method_handler(
            servicer.Truncate,
            request_deserializer=multicloud__fs__pb2.TruncateRequest.FromString,
            response_serializer=multicloud__fs__pb2.TruncateResponse.SerializeToString,
        ),
        "Chown": grpc.unary_unary_rpc_method_handler(
            servicer.Chown,
            request_deserializer=multicloud__fs__pb2.ChownRequest.FromString,
            response_serializer=multicloud__fs__pb2.ChownResponse.SerializeToString,
        ),
        "Chmod": grpc.unary_unary_rpc_method_handler(
            servicer.Chmod,
            request_deserializer=multicloud__fs__pb2.ChmodRequest.FromString,
            response_serializer=multicloud__fs__pb2.ChmodResponse.SerializeToString,
        ),
        "Unlink": grpc.unary_unary_rpc_method_handler(
            servicer.Unlink,
            request_deserializer=multicloud__fs__pb2.UnlinkRequest.FromString,
            response_serializer=multicloud__fs__pb2.UnlinkResponse.SerializeToString,
        ),
        "Rmdir": grpc.unary_unary_rpc_method_handler(
            servicer.Rmdir,
            request_deserializer=multicloud__fs__pb2.RmdirRequest.FromString,
            response_serializer=multicloud__fs__pb2.RmdirResponse.SerializeToString,
        ),
        "Rename": grpc.unary_unary_rpc_method_handler(
            servicer.Rename,
            request_deserializer=multicloud__fs__pb2.RenameRequest.FromString,
            response_serializer=multicloud__fs__pb2.RenameResponse.SerializeToString,
        ),
        "Access": grpc.unary_unary_rpc_method_handler(
            servicer.Access,
            request_deserializer=multicloud__fs__pb2.AccessRequest.FromString,
            response_serializer=multicloud__fs__pb2.AccessResponse.SerializeToString,
        ),
        "Utimens": grpc.unary_unary_rpc_method_handler(
            servicer.Utimens,
            request_deserializer=multicloud__fs__pb2.UtimensRequest.FromString,
            response_serializer=multicloud__fs__pb2.UtimensResponse.SerializeToString,
        ),
        "Mkdir": grpc.unary_unary_rpc_method_handler(
            servicer.Mkdir,
            request_deserializer=multicloud__fs__pb2.MkdirRequest.FromString,
            response_serializer=multicloud__fs__pb2.MkdirResponse.SerializeToString,
        ),
        "Create": grpc.unary_unary_rpc_method_handler(
            servicer.Create,
            request_deserializer=multicloud__fs__pb2.CreateRequest.FromString,
            response_serializer=multicloud__fs__pb2.CreateResponse.SerializeToString,
        ),
    }
    generic_handler = grpc.method_handlers_generic_handler(
        "multi_cloud_fs.Operations", rpc_method_handlers
    )
    server.add_generic_rpc_handlers((generic_handler,))
    server.add_registered_method_handlers(
        "multi_cloud_fs.Operations", rpc_method_handlers
    )


# This class is part of an EXPERIMENTAL API.
class Operations(object):
    """Missing associated documentation comment in .proto file."""

    @staticmethod
    def Exists(
        request,
        target,
        options=(),
        channel_credentials=None,
        call_credentials=None,
        insecure=False,
        compression=None,
        wait_for_ready=None,
        timeout=None,
        metadata=None,
    ):
        return grpc.experimental.unary_unary(
            request,
            target,
            "/multi_cloud_fs.Operations/Exists",
            multicloud__fs__pb2.ExistsRequest.SerializeToString,
            multicloud__fs__pb2.ExistsResponse.FromString,
            options,
            channel_credentials,
            insecure,
            call_credentials,
            compression,
            wait_for_ready,
            timeout,
            metadata,
            _registered_method=True,
        )

    @staticmethod
    def GetAttr(
        request,
        target,
        options=(),
        channel_credentials=None,
        call_credentials=None,
        insecure=False,
        compression=None,
        wait_for_ready=None,
        timeout=None,
        metadata=None,
    ):
        return grpc.experimental.unary_unary(
            request,
            target,
            "/multi_cloud_fs.Operations/GetAttr",
            multicloud__fs__pb2.GetAttrRequest.SerializeToString,
            multicloud__fs__pb2.GetAttrResponse.FromString,
            options,
            channel_credentials,
            insecure,
            call_credentials,
            compression,
            wait_for_ready,
            timeout,
            metadata,
            _registered_method=True,
        )

    @staticmethod
    def ReadDir(
        request,
        target,
        options=(),
        channel_credentials=None,
        call_credentials=None,
        insecure=False,
        compression=None,
        wait_for_ready=None,
        timeout=None,
        metadata=None,
    ):
        return grpc.experimental.unary_unary(
            request,
            target,
            "/multi_cloud_fs.Operations/ReadDir",
            multicloud__fs__pb2.ReadDirRequest.SerializeToString,
            multicloud__fs__pb2.ReadDirResponse.FromString,
            options,
            channel_credentials,
            insecure,
            call_credentials,
            compression,
            wait_for_ready,
            timeout,
            metadata,
            _registered_method=True,
        )

    @staticmethod
    def Read(
        request,
        target,
        options=(),
        channel_credentials=None,
        call_credentials=None,
        insecure=False,
        compression=None,
        wait_for_ready=None,
        timeout=None,
        metadata=None,
    ):
        return grpc.experimental.unary_unary(
            request,
            target,
            "/multi_cloud_fs.Operations/Read",
            multicloud__fs__pb2.ReadRequest.SerializeToString,
            multicloud__fs__pb2.ReadResponse.FromString,
            options,
            channel_credentials,
            insecure,
            call_credentials,
            compression,
            wait_for_ready,
            timeout,
            metadata,
            _registered_method=True,
        )

    @staticmethod
    def Write(
        request,
        target,
        options=(),
        channel_credentials=None,
        call_credentials=None,
        insecure=False,
        compression=None,
        wait_for_ready=None,
        timeout=None,
        metadata=None,
    ):
        return grpc.experimental.unary_unary(
            request,
            target,
            "/multi_cloud_fs.Operations/Write",
            multicloud__fs__pb2.WriteRequest.SerializeToString,
            multicloud__fs__pb2.WriteResponse.FromString,
            options,
            channel_credentials,
            insecure,
            call_credentials,
            compression,
            wait_for_ready,
            timeout,
            metadata,
            _registered_method=True,
        )

    @staticmethod
    def Truncate(
        request,
        target,
        options=(),
        channel_credentials=None,
        call_credentials=None,
        insecure=False,
        compression=None,
        wait_for_ready=None,
        timeout=None,
        metadata=None,
    ):
        return grpc.experimental.unary_unary(
            request,
            target,
            "/multi_cloud_fs.Operations/Truncate",
            multicloud__fs__pb2.TruncateRequest.SerializeToString,
            multicloud__fs__pb2.TruncateResponse.FromString,
            options,
            channel_credentials,
            insecure,
            call_credentials,
            compression,
            wait_for_ready,
            timeout,
            metadata,
            _registered_method=True,
        )

    @staticmethod
    def Chown(
        request,
        target,
        options=(),
        channel_credentials=None,
        call_credentials=None,
        insecure=False,
        compression=None,
        wait_for_ready=None,
        timeout=None,
        metadata=None,
    ):
        return grpc.experimental.unary_unary(
            request,
            target,
            "/multi_cloud_fs.Operations/Chown",
            multicloud__fs__pb2.ChownRequest.SerializeToString,
            multicloud__fs__pb2.ChownResponse.FromString,
            options,
            channel_credentials,
            insecure,
            call_credentials,
            compression,
            wait_for_ready,
            timeout,
            metadata,
            _registered_method=True,
        )

    @staticmethod
    def Chmod(
        request,
        target,
        options=(),
        channel_credentials=None,
        call_credentials=None,
        insecure=False,
        compression=None,
        wait_for_ready=None,
        timeout=None,
        metadata=None,
    ):
        return grpc.experimental.unary_unary(
            request,
            target,
            "/multi_cloud_fs.Operations/Chmod",
            multicloud__fs__pb2.ChmodRequest.SerializeToString,
            multicloud__fs__pb2.ChmodResponse.FromString,
            options,
            channel_credentials,
            insecure,
            call_credentials,
            compression,
            wait_for_ready,
            timeout,
            metadata,
            _registered_method=True,
        )

    @staticmethod
    def Unlink(
        request,
        target,
        options=(),
        channel_credentials=None,
        call_credentials=None,
        insecure=False,
        compression=None,
        wait_for_ready=None,
        timeout=None,
        metadata=None,
    ):
        return grpc.experimental.unary_unary(
            request,
            target,
            "/multi_cloud_fs.Operations/Unlink",
            multicloud__fs__pb2.UnlinkRequest.SerializeToString,
            multicloud__fs__pb2.UnlinkResponse.FromString,
            options,
            channel_credentials,
            insecure,
            call_credentials,
            compression,
            wait_for_ready,
            timeout,
            metadata,
            _registered_method=True,
        )

    @staticmethod
    def Rmdir(
        request,
        target,
        options=(),
        channel_credentials=None,
        call_credentials=None,
        insecure=False,
        compression=None,
        wait_for_ready=None,
        timeout=None,
        metadata=None,
    ):
        return grpc.experimental.unary_unary(
            request,
            target,
            "/multi_cloud_fs.Operations/Rmdir",
            multicloud__fs__pb2.RmdirRequest.SerializeToString,
            multicloud__fs__pb2.RmdirResponse.FromString,
            options,
            channel_credentials,
            insecure,
            call_credentials,
            compression,
            wait_for_ready,
            timeout,
            metadata,
            _registered_method=True,
        )

    @staticmethod
    def Rename(
        request,
        target,
        options=(),
        channel_credentials=None,
        call_credentials=None,
        insecure=False,
        compression=None,
        wait_for_ready=None,
        timeout=None,
        metadata=None,
    ):
        return grpc.experimental.unary_unary(
            request,
            target,
            "/multi_cloud_fs.Operations/Rename",
            multicloud__fs__pb2.RenameRequest.SerializeToString,
            multicloud__fs__pb2.RenameResponse.FromString,
            options,
            channel_credentials,
            insecure,
            call_credentials,
            compression,
            wait_for_ready,
            timeout,
            metadata,
            _registered_method=True,
        )

    @staticmethod
    def Access(
        request,
        target,
        options=(),
        channel_credentials=None,
        call_credentials=None,
        insecure=False,
        compression=None,
        wait_for_ready=None,
        timeout=None,
        metadata=None,
    ):
        return grpc.experimental.unary_unary(
            request,
            target,
            "/multi_cloud_fs.Operations/Access",
            multicloud__fs__pb2.AccessRequest.SerializeToString,
            multicloud__fs__pb2.AccessResponse.FromString,
            options,
            channel_credentials,
            insecure,
            call_credentials,
            compression,
            wait_for_ready,
            timeout,
            metadata,
            _registered_method=True,
        )

    @staticmethod
    def Utimens(
        request,
        target,
        options=(),
        channel_credentials=None,
        call_credentials=None,
        insecure=False,
        compression=None,
        wait_for_ready=None,
        timeout=None,
        metadata=None,
    ):
        return grpc.experimental.unary_unary(
            request,
            target,
            "/multi_cloud_fs.Operations/Utimens",
            multicloud__fs__pb2.UtimensRequest.SerializeToString,
            multicloud__fs__pb2.UtimensResponse.FromString,
            options,
            channel_credentials,
            insecure,
            call_credentials,
            compression,
            wait_for_ready,
            timeout,
            metadata,
            _registered_method=True,
        )

    @staticmethod
    def Mkdir(
        request,
        target,
        options=(),
        channel_credentials=None,
        call_credentials=None,
        insecure=False,
        compression=None,
        wait_for_ready=None,
        timeout=None,
        metadata=None,
    ):
        return grpc.experimental.unary_unary(
            request,
            target,
            "/multi_cloud_fs.Operations/Mkdir",
            multicloud__fs__pb2.MkdirRequest.SerializeToString,
            multicloud__fs__pb2.MkdirResponse.FromString,
            options,
            channel_credentials,
            insecure,
            call_credentials,
            compression,
            wait_for_ready,
            timeout,
            metadata,
            _registered_method=True,
        )

    @staticmethod
    def Create(
        request,
        target,
        options=(),
        channel_credentials=None,
        call_credentials=None,
        insecure=False,
        compression=None,
        wait_for_ready=None,
        timeout=None,
        metadata=None,
    ):
        return grpc.experimental.unary_unary(
            request,
            target,
            "/multi_cloud_fs.Operations/Create",
            multicloud__fs__pb2.CreateRequest.SerializeToString,
            multicloud__fs__pb2.CreateResponse.FromString,
            options,
            channel_credentials,
            insecure,
            call_credentials,
            compression,
            wait_for_ready,
            timeout,
            metadata,
            _registered_method=True,
        )
