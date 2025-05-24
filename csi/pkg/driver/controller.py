import json
import logging
import os
import time
import uuid

import csi_pb2
import csi_pb2_grpc
import redis


class ControllerService(csi_pb2_grpc.ControllerServicer):
    def __init__(self, driver_name, node_id, redis_url, root_dir):
        self.driver_name = driver_name
        self.node_id = node_id
        self.redis_url = redis_url
        self.root_dir = root_dir
        self.redis_client = redis.from_url(redis_url)
        logging.info(f"Controller service initialized: {driver_name} on {node_id}")

    def CreateVolume(self, request, context):
        volume_id = f"{request.name}-{str(uuid.uuid4())[:8]}"
        capacity_bytes = request.capacity_range.required_bytes
        logging.info(
            f"Creating volume {volume_id} with capacity {capacity_bytes} bytes"
        )

        if self.redis_client.hexists("csi:volumes", volume_id):
            logging.info(f"Volume {volume_id} already exists")
            volume_data = json.loads(self.redis_client.hget("csi:volumes", volume_id))
            return csi_pb2.CreateVolumeResponse(
                volume=csi_pb2.Volume(
                    volume_id=volume_id, capacity_bytes=volume_data["capacity_bytes"]
                )
            )

        volume_data = {
            "id": volume_id,
            "capacity_bytes": capacity_bytes,
            "created_at": str(time.time()),
        }

        self.redis_client.hset("csi:volumes", volume_id, json.dumps(volume_data))

        volume_path = os.path.join(self.root_dir, volume_id)
        os.makedirs(volume_path, exist_ok=True)

        return csi_pb2.CreateVolumeResponse(
            volume=csi_pb2.Volume(volume_id=volume_id, capacity_bytes=capacity_bytes)
        )

    def DeleteVolume(self, request, context):
        volume_id = request.volume_id
        logging.info(f"Deleting volume {volume_id}")

        self.redis_client.hdel("csi:volumes", volume_id)

        return csi_pb2.DeleteVolumeResponse()

    def ControllerPublishVolume(self, request, context):
        volume_id = request.volume_id
        node_id = request.node_id
        logging.info(f"Publishing volume {volume_id} to node {node_id}")

        self.redis_client.hset(f"csi:volume:{volume_id}:nodes", node_id, "published")

        return csi_pb2.ControllerPublishVolumeResponse()

    def ControllerUnpublishVolume(self, request, context):
        volume_id = request.volume_id
        node_id = request.node_id
        logging.info(f"Unpublishing volume {volume_id} from node {node_id}")

        self.redis_client.hdel(f"csi:volume:{volume_id}:nodes", node_id)

        return csi_pb2.ControllerUnpublishVolumeResponse()

    def ValidateVolumeCapabilities(self, request, context):
        return csi_pb2.ValidateVolumeCapabilitiesResponse(
            confirmed=csi_pb2.ValidateVolumeCapabilitiesResponse.Confirmed(
                volume_context=request.volume_context,
                volume_capabilities=request.volume_capabilities,
            )
        )

    def ControllerGetCapabilities(self, request, context):
        caps = [
            csi_pb2.ControllerServiceCapability(
                rpc=csi_pb2.ControllerServiceCapability.RPC(
                    type=csi_pb2.ControllerServiceCapability.RPC.CREATE_DELETE_VOLUME
                )
            ),
            csi_pb2.ControllerServiceCapability(
                rpc=csi_pb2.ControllerServiceCapability.RPC(
                    type=csi_pb2.ControllerServiceCapability.RPC.PUBLISH_UNPUBLISH_VOLUME
                )
            ),
        ]
        return csi_pb2.ControllerGetCapabilitiesResponse(capabilities=caps)

    def register(self, server):
        csi_pb2_grpc.add_ControllerServicer_to_server(self, server)
