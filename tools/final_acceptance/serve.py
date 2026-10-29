"""Serve the compiled QA SPA on a loopback-only, dedicated local port."""

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit


class SpaHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        requested = Path(self.translate_path(urlsplit(self.path).path))
        if not requested.exists() and '.' not in Path(urlsplit(self.path).path).name:
            self.path = '/index.html'
        super().do_GET()

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', type=Path, required=True)
    args = parser.parse_args()
    if not (args.directory / 'index.html').is_file():
        raise ValueError('compiled_web_build_required')
    ThreadingHTTPServer(('127.0.0.1', 64331), partial(SpaHandler, directory=str(args.directory.resolve()))).serve_forever()
