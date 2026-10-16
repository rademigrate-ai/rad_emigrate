"""Small localhost-only static server with Flutter Web history fallback."""

import argparse
import http.server
import os
from pathlib import Path
import socketserver


class SpaHandler(http.server.SimpleHTTPRequestHandler):
    def send_head(self):
        path = self.translate_path(self.path)
        if not os.path.exists(path) and "." not in Path(self.path).name:
            self.path = "/index.html"
        return super().send_head()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", default="build/web")
    parser.add_argument("--port", type=int, default=8794)
    args = parser.parse_args()
    os.chdir(args.directory)
    with socketserver.TCPServer(("127.0.0.1", args.port), SpaHandler) as server:
        server.serve_forever()


if __name__ == "__main__":
    main()
