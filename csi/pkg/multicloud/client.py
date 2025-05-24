import logging
import os
import subprocess
import time


class MulticloudClient:
    def __init__(self, redis_url, node_url):
        self.redis_url = redis_url
        self.node_url = node_url
        self.mounts = {}
        logging.info(f"MulticloudClient initialized with Redis URL: {redis_url}")

    def mount(self, volume_path, target_path):
        """Mount the multicloud filesystem to the target path"""
        logging.info(f"Mounting {volume_path} to {target_path}")

        port = 5000 + len(self.mounts)

        os.makedirs(volume_path, exist_ok=True)
        os.makedirs(target_path, exist_ok=True)

        cmd = [
            "/usr/local/bin/multicloud_fs",
            "-f",
            target_path,
            "-r",
            volume_path,
            "-i",
            self.node_url,
            "-p",
            str(port),
            "-u",
            self.redis_url,
        ]

        logging.info(f"Executing: {' '.join(cmd)}")

        process = subprocess.Popen(cmd)

        self.mounts[target_path] = {
            "process": process,
            "port": port,
            "volume_path": volume_path,
        }

        self._wait_for_mount(target_path)

    def unmount(self, target_path):
        """Unmount the multicloud filesystem from the target path"""
        if target_path not in self.mounts:
            logging.info(f"Target path {target_path} is not mounted, skipping unmount")
            return

        logging.info(f"Unmounting {target_path}")

        mount_info = self.mounts[target_path]
        process = mount_info["process"]

        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()

        self.mounts.pop(target_path, None)

        logging.info(f"Successfully unmounted {target_path}")

    def _wait_for_mount(self, path, timeout=30):
        """Wait for filesystem to be mounted"""
        start_time = time.time()
        while time.time() - start_time < timeout:
            try:
                with open(os.path.join(path, ".mount_check"), "w") as f:
                    f.write("test")
                logging.info(f"Mount at {path} is ready")
                return True
            except Exception as e:
                logging.debug(f"Mount not ready yet: {str(e)}")
                time.sleep(1)

        logging.error(
            f"Mount at {path} failed to become ready within {timeout} seconds"
        )
        return False
