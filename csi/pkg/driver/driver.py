import grpc
from concurrent import futures
import logging

from .identity import IdentityService
from .controller import ControllerService
from .node import NodeService


class MulticloudCSIDriver:
    def __init__(self, endpoint, node_id, redis_url, mount_point, root_dir, node_url):
        self.endpoint = endpoint
        self.node_id = node_id
        self.redis_url = redis_url
        self.mount_point = mount_point
        self.root_dir = root_dir
        self.node_url = node_url

        # Driver name and version
        self.name = "csi.multicloud.fs"
        self.version = "0.1.0"

    def run(self):
        server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))

        # Register CSI services
        identity_service = IdentityService(self.name, self.version)
        identity_service.register(server)

        controller_service = ControllerService(
            driver_name=self.name,
            node_id=self.node_id,
            redis_url=self.redis_url,
            root_dir=self.root_dir,
        )
        controller_service.register(server)

        node_service = NodeService(
            driver_name=self.name,
            node_id=self.node_id,
            mount_point=self.mount_point,
            root_dir=self.root_dir,
            redis_url=self.redis_url,
            node_url=self.node_url
        )
        node_service.register(server)

        server.add_insecure_port(self.endpoint)
        server.start()

        logging.info(f"CSI driver {self.name} started on {self.endpoint}")

        # Keep the server running
        server.wait_for_termination()
