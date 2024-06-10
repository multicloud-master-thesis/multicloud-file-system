import os
import threading

import fuse
from dotenv import load_dotenv

from file_system import MultiCloudFS
from grpc_client import GrpcClient
from grpc_server import serve

fuse.fuse_python_api = (0, 2)


def main():
    load_dotenv()

    threading.Thread(
        target=serve, args=(os.getenv("ROOT_PATH"), int(os.getenv("PORT")))
    ).start()

    client = GrpcClient(os.getenv("CLOUD_ADDRESS"))
    server = MultiCloudFS(
        dash_s_do="setsingle", root_path=os.getenv("ROOT_PATH"), client=client
    )

    server.parse(errex=1)
    server.main()


if __name__ == "__main__":
    main()
