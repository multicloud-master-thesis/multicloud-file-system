import argparse
import platform
import signal
import sys
import threading

import fuse

from file_system import MultiCloudFS
from grpc_client_manager import GrpcClientManager
from grpc_server import serve

fuse.fuse_python_api = (0, 2)


def run_server_process(root_path, port):
    serve(root_path, port)


def parse_args():
    parser = argparse.ArgumentParser(description="Run the MultiCloudFS")
    parser.add_argument(
        "-r", "--root_path", required=True, help="Root path for the file system"
    )
    parser.add_argument(
        "-p", "--port", required=True, type=int, help="Port for the gRPC server"
    )
    parser.add_argument(
        "-f", "--mount_path", required=True, help="Mount path for the file system"
    )
    parser.add_argument(
        "-i", "--host_ip", default="localhost", help="Host of the server"
    )
    parser.add_argument(
        "-u", "--redis_url", required=True, help="URL for the Redis server"
    )
    parser.add_argument("-d", "--debug", action="store_true", help="Enable debug mode")
    parser.add_argument(
        "-s", "--single", action="store_true", help="Enable single-threaded mode"
    )

    args = parser.parse_args()

    return args


def run():
    args = parse_args()
    threading.Thread(
        target=run_server_process, args=(args.root_path, args.port), daemon=True
    ).start()
    client_manager = GrpcClientManager(
        redis_url=args.redis_url, url=f"{args.host_ip}:{args.port}"
    )
    server = MultiCloudFS(
        dash_s_do="setsingle", root_path=args.root_path, client=client_manager
    )
    client_manager.initialize_files(server.get_files())

    def signal_handler(sig, frame):
        print("Shutting down, cleaning up resources...")
        client_manager.remove_manager(server.get_files())
        sys.exit(0)

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    fuse_args = ["-f", args.mount_path]
    if platform.system() != "Darwin":
        fuse_args += ["-o", "nonempty"]
    if args.debug:
        fuse_args.append("-d")
    if args.single:
        fuse_args.append("-s")
    server.parse(errex=1, args=fuse_args)
    server.main()
    client_manager.remove_manager(server.get_files())
