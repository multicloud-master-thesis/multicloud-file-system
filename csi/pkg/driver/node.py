import logging
import os
import shutil

import csi_pb2
import csi_pb2_grpc

from ..multicloud.client import MulticloudClient


class NodeService(csi_pb2_grpc.NodeServicer):
    def __init__(
        self, driver_name, node_id, mount_point, root_dir, redis_url, node_url
    ):
        self.driver_name = driver_name
        self.node_id = node_id
        self.mount_point = mount_point
        self.root_dir = root_dir
        self.redis_url = redis_url
        self.node_url = node_url
        self.multicloud_client = MulticloudClient(redis_url, node_url)
        logging.info(f"Node service initialized: {driver_name} on {node_id}")

    def NodeStageVolume(self, request, context):
        volume_id = request.volume_id
        staging_path = request.staging_target_path
        logging.info(f"Staging volume {volume_id} at {staging_path}")

        os.makedirs(staging_path, exist_ok=True)

        volume_path = os.path.join(self.root_dir, volume_id)
        os.makedirs(volume_path, exist_ok=True)

        return csi_pb2.NodeStageVolumeResponse()

    def NodeUnstageVolume(self, request, context):
        volume_id = request.volume_id
        staging_path = request.staging_target_path
        logging.info(f"Unstaging volume {volume_id} from {staging_path}")

        return csi_pb2.NodeUnstageVolumeResponse()

    def NodePublishVolume(self, request, context):
        volume_id = request.volume_id
        staging_path = request.staging_target_path
        target_path = request.target_path
        volume_path = os.path.join(self.root_dir, volume_id)
        logging.info(
            f"Publishing volume {volume_id} from {staging_path} to {target_path}"
        )

        os.makedirs(target_path, exist_ok=True)

        self.multicloud_client.mount(volume_path, target_path)

        return csi_pb2.NodePublishVolumeResponse()

    def NodeUnpublishVolume(self, request, context):
        volume_id = request.volume_id
        target_path = request.target_path
        logging.info(f"Unpublishing volume {volume_id} from {target_path}")

        self.multicloud_client.unmount(target_path)
        shutil.rmtree(target_path, ignore_errors=True)

        return csi_pb2.NodeUnpublishVolumeResponse()

    def NodeGetCapabilities(self, request, context):
        caps = [
            csi_pb2.NodeServiceCapability(
                rpc=csi_pb2.NodeServiceCapability.RPC(
                    type=csi_pb2.NodeServiceCapability.RPC.STAGE_UNSTAGE_VOLUME
                )
            )
        ]
        return csi_pb2.NodeGetCapabilitiesResponse(capabilities=caps)

    def NodeGetInfo(self, request, context):
        return csi_pb2.NodeGetInfoResponse(
            node_id=self.node_id,
            max_volumes_per_node=100,  # Adjust based on your system capabilities
            accessible_topology=csi_pb2.Topology(
                segments={"kubernetes.io/hostname": self.node_id}
            ),
        )

    def register(self, server):
        csi_pb2_grpc.add_NodeServicer_to_server(self, server)
