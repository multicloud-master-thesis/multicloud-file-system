import csi_pb2
import csi_pb2_grpc
import logging

class IdentityService(csi_pb2_grpc.IdentityServicer):
    def __init__(self, name, version):
        self.name = name
        self.version = version
        logging.info(f"Identity service initialized: {name} v{version}")

    def GetPluginInfo(self, request, context):
        logging.info("GetPluginInfo called")
        return csi_pb2.GetPluginInfoResponse(
            name=self.name,
            vendor_version=self.version
        )

    def GetPluginCapabilities(self, request, context):
        logging.info("GetPluginCapabilities called")
        return csi_pb2.GetPluginCapabilitiesResponse(
            capabilities=[
                csi_pb2.PluginCapability(
                    service=csi_pb2.PluginCapability.Service(
                        type=csi_pb2.PluginCapability.Service.CONTROLLER_SERVICE
                    )
                ),
                csi_pb2.PluginCapability(
                    volume_expansion=csi_pb2.PluginCapability.VolumeExpansion(
                        type=csi_pb2.PluginCapability.VolumeExpansion.ONLINE
                    )
                )
            ]
        )

    def Probe(self, request, context):
        logging.info("Probe called")
        response = csi_pb2.ProbeResponse()
        response.ready.value = True
        return response

    def register(self, server):
        csi_pb2_grpc.add_IdentityServicer_to_server(self, server)