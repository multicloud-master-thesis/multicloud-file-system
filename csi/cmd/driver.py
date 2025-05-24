#!/usr/bin/env python3
import argparse
import logging
import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from pkg.driver.driver import MulticloudCSIDriver


def main():
    parser = argparse.ArgumentParser(description="Multicloud CSI Driver")
    parser.add_argument("--endpoint", required=True, help="gRPC endpoint")
    parser.add_argument("--nodeid", required=True, help="Node ID")
    parser.add_argument("--redis-url", required=True, help="Redis URL")
    parser.add_argument("--node-url", required=True, help="URL of the current node")
    parser.add_argument(
        "--root-dir",
        default="/var/lib/multicloud/volumes",
        help="Root directory for volumes",
    )
    parser.add_argument(
        "--mount-point",
        default="/var/lib/multicloud/mounts",
        help="Mount point base directory",
    )
    parser.add_argument("--log-level", default="INFO", help="Log level")
    args = parser.parse_args()

    numeric_level = getattr(logging, args.log_level.upper(), None)
    if not isinstance(numeric_level, int):
        raise ValueError(f"Invalid log level: {args.log_level}")
    logging.basicConfig(
        level=numeric_level, format="%(asctime)s - %(levelname)s - %(message)s"
    )

    # Create directories if they don't exist
    os.makedirs(args.root_dir, exist_ok=True)
    os.makedirs(args.mount_point, exist_ok=True)

    driver = MulticloudCSIDriver(
        endpoint=args.endpoint,
        node_id=args.nodeid,
        redis_url=args.redis_url,
        mount_point=args.mount_point,
        root_dir=args.root_dir,
        node_url=args.node_url,
    )

    driver.run()


if __name__ == "__main__":
    main()
