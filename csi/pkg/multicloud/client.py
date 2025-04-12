import subprocess
import os
import logging
import time


class MulticloudClient:
    def __init__(self, redis_url, node_url):
        self.redis_url = redis_url
        self.node_url = node_url
        self.mounts = {}  # Track active mounts
        logging.info(f"MulticloudClient initialized with Redis URL: {redis_url}")

    def mount(self, volume_path, target_path):
        """Mount the multicloud filesystem to the target path"""
        logging.info(f"Mounting {volume_path} to {target_path}")

        # Get an available port (simple increment for this example)
        port = 5000 + len(self.mounts)

        # Create the necessary directories
        os.makedirs(volume_path, exist_ok=True)
        os.makedirs(target_path, exist_ok=True)

        # Start the multicloud filesystem using your entrypoint
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
            self.redis_url
        ]

        logging.info(f"Executing: {' '.join(cmd)}")

        # Start in background
        process = subprocess.Popen(cmd)

        # Track this mount point
        self.mounts[target_path] = {
            "process": process,
            "port": port,
            "volume_path": volume_path,
        }

        # Wait for mount to be ready (adjust timeout as needed)
        self._wait_for_mount(target_path)

    def unmount(self, target_path):
        """Unmount the multicloud filesystem from the target path"""
        if target_path not in self.mounts:
            logging.info(f"Target path {target_path} is not mounted, skipping unmount")
            return

        logging.info(f"Unmounting {target_path}")

        # Get the process and terminate it
        mount_info = self.mounts[target_path]
        process = mount_info["process"]

        if process.poll() is None:  # Process is still running
            process.terminate()
            try:
                process.wait(timeout=5)  # Wait for graceful termination
            except subprocess.TimeoutExpired:
                process.kill()  # Force kill if needed

        # Remove from tracked mounts
        self.mounts.pop(target_path, None)

        logging.info(f"Successfully unmounted {target_path}")

    def _wait_for_mount(self, path, timeout=30):
        """Wait for filesystem to be mounted"""
        start_time = time.time()
        while time.time() - start_time < timeout:
            # Check if mounted (simple file existence check)
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
