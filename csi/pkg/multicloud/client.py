import logging
import os
import subprocess


class MulticloudClient:
    def __init__(self, redis_url, node_url):
        self.redis_url = redis_url
        self.node_url = node_url
        self.node_mount_path = "/shared/multicloud_fs"
        self.node_root_path = "/var/lib/multicloud/root"
        self.node_mount = None
        logging.info(f"MulticloudClient initialized with Redis URL: {redis_url}")

        if os.environ.get("SKIP_NODE_MOUNT") == "true":
            logging.info("SKIP_NODE_MOUNT is set, skipping node mount initialization")
        else:
            self._start_node_mount()

    def mount(self, volume_path, target_path):
        logging.info(f"Mounting {self.node_mount_path} to {target_path}")

        os.makedirs(target_path, exist_ok=True)

        try:
            subprocess.run(
                [
                    "mount",
                    "--bind",
                    self.node_mount_path,
                    target_path,
                ],
                check=True,
            )
            logging.info(
                f"Created bind mount from {self.node_mount_path} to {target_path}"
            )
            return True
        except Exception as e:
            logging.error(f"Failed to create bind mount: {e}")
            return False

    def _start_node_mount(self):
        logging.info(
            f"Starting node-level multicloud_fs mount at {self.node_mount_path}"
        )
        os.makedirs(self.node_mount_path, exist_ok=True)
        os.makedirs(self.node_root_path, exist_ok=True)

        port = 5000

        cmd = [
            "/usr/local/bin/multicloud_fs",
            "-f",
            self.node_mount_path,
            "-r",
            self.node_root_path,
            "-i",
            self.node_url,
            "-p",
            str(port),
            "-u",
            self.redis_url,
        ]

        logging.info(f"Executing: {' '.join(cmd)}")

        process = subprocess.Popen(cmd)
        self.node_mount = {"process": process, "port": port}

        logging.info(f"Started node-level multicloud_fs with PID {process.pid}")
        return True

    def unmount(self, target_path):
        logging.info(f"Unmounting {target_path}")

        try:
            subprocess.run(["umount", target_path], check=True)
            logging.info(f"Unmounted {target_path}")
            return True
        except Exception as e:
            logging.error(f"Failed to unmount {target_path}: {e}")
            return False
