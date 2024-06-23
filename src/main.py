import multiprocessing
import os

import fuse

from file_system import MultiCloudFS
from grpc_server import serve
from src.grpc_client_manager import GrpcClientManager

fuse.fuse_python_api = (0, 2)


def run_server_process():
    serve(os.getenv("ROOT_PATH"), int(os.getenv("PORT")))


def main():
    multiprocessing.Process(target=run_server_process, daemon=True).start()
    client_manager = GrpcClientManager(redis_url=os.getenv("REDIS_URL"), url=f'localhost:{os.getenv("PORT")}')
    server = MultiCloudFS(
        dash_s_do="setsingle", root_path=os.getenv("ROOT_PATH"), client=client_manager
    )

    server.parse(errex=1)
    server.main()
    client_manager.remove_manager(server.get_files())


if __name__ == "__main__":
    main()
