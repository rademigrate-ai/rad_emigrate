"""DNS-pinned, exact-host research egress. Run behind an operator-owned HTTPS proxy.

No packages required. Reads allowlisted public articles only; cannot access RAD
databases, publish, or forward caller credentials. PDF extraction is unavailable.
"""

from __future__ import annotations

import base64
import concurrent.futures
import hmac
import http.client
import ipaddress
import json
import os
import socket
import ssl
import threading
import time
import urllib.parse
import urllib.robotparser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

AGENT = "RAD-Knowledge-Sync/1.0 (+https://radvisa.com)"
DNS_POOL = concurrent.futures.ThreadPoolExecutor(max_workers=4)


class EgressError(Exception):
    """Only fixed codes may be exposed; upstream exception text stays private."""


def public_addresses(host: str) -> list[str]:
    # IPv4-only by design. No mapped IPv6, NAT64 or transition-address bypass.
    future = DNS_POOL.submit(
        socket.getaddrinfo, host, 443, socket.AF_INET, socket.SOCK_STREAM
    )
    try:
        answers = future.result(timeout=5)
    except Exception:
        future.cancel()
        raise EgressError("source_dns_unavailable") from None
    addresses = []
    for answer in answers:
        address = ipaddress.ip_address(answer[4][0])
        if (
            address.version != 4
            or not address.is_global
            or address.is_multicast
            or address.is_reserved
        ):
            raise EgressError("source_dns_nonpublic")
        addresses.append(str(address))
    if not addresses:
        raise EgressError("source_dns_unavailable")
    return sorted(set(addresses))


class PinnedHTTPSConnection(http.client.HTTPSConnection):
    def __init__(self, host: str, address: str):
        super().__init__(host, 443, timeout=10, context=ssl.create_default_context())
        self.address = address
        self.expired = threading.Event()
        self.socket_lock = threading.Lock()

    def abort(self):
        self.expired.set()
        with self.socket_lock:
            if self.sock:
                try:
                    self.sock.shutdown(socket.SHUT_RDWR)
                except OSError:
                    pass
                self.sock.close()

    def check_deadline(self):
        if self.expired.is_set():
            raise EgressError("source_timeout")

    def connect(self):
        raw = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        raw.settimeout(self.timeout)
        try:
            with self.socket_lock:
                self.check_deadline()
                self.sock = raw
            raw.connect((self.address, 443))
            self.check_deadline()
            wrapped = self._context.wrap_socket(
                raw, server_hostname=self.host, do_handshake_on_connect=False
            )
            with self.socket_lock:
                if self.expired.is_set():
                    wrapped.close()
                    raise EgressError("source_timeout")
                self.sock = wrapped
            wrapped.do_handshake()
            self.check_deadline()
        except Exception:
            raw.close()
            raise


def pinned_request(url: str, *, max_bytes: int):
    parsed = urllib.parse.urlsplit(url)
    addresses = public_addresses(parsed.hostname)
    connection = PinnedHTTPSConnection(parsed.hostname, addresses[0])

    timer = threading.Timer(15, connection.abort)
    timer.daemon = True
    timer.start()
    try:
        path = urllib.parse.urlunsplit(("", "", parsed.path or "/", parsed.query, ""))
        # Explicit headers only: no Authorization, cookies, referer or proxy data.
        connection.request(
            "GET",
            path,
            headers={
                "User-Agent": AGENT,
                "Accept": "text/html,text/plain;q=0.9",
                "Accept-Encoding": "identity",
            },
        )
        response = connection.getresponse()
        connection.check_deadline()
        length = response.getheader("content-length")
        if length and int(length) > max_bytes:
            raise EgressError("source_too_large")
        body = response.read(max_bytes + 1)
        connection.check_deadline()
        if len(body) > max_bytes:
            raise EgressError("source_too_large")
        headers = {
            name: response.getheader(name)
            for name in ("content-type", "content-encoding", "location")
            if response.getheader(name)
        }
        if headers.get("content-encoding", "identity").lower() != "identity":
            raise EgressError("unsupported_source_encoding")
        return response.status, headers, body
    except EgressError:
        raise
    except Exception:
        raise EgressError("source_fetch_failed") from None
    finally:
        timer.cancel()
        connection.close()


class ProtectedFetcher:
    def __init__(
        self,
        allowed_hosts,
        *,
        request=pinned_request,
        max_bytes=1_000_000,
        minimum_interval=1,
    ):
        if not 0 <= minimum_interval <= 30:
            raise ValueError("minimum_interval_must_be_between_0_and_30_seconds")
        self.allowed_hosts = frozenset(allowed_hosts)
        self.request = request
        self.max_bytes = max_bytes
        self.minimum_interval = minimum_interval
        self.robots = {}
        self.last_requests = {}
        self.lock = threading.Lock()

    def validate(self, url):
        try:
            parsed = urllib.parse.urlsplit(url)
            host = parsed.hostname
            valid = (
                parsed.scheme == "https"
                and host in self.allowed_hosts
                and not parsed.username
                and not parsed.password
                and parsed.port in (None, 443)
                and not parsed.fragment
                and len(url) <= 2048
            )
            if (
                not host
                or not valid
                or host.endswith(".")
                or any(ord(c) <= 32 or ord(c) == 127 for c in url)
            ):
                raise ValueError()
            # Allowlist entries must be hostnames, never IP literals.
            try:
                ipaddress.ip_address(host)
            except ValueError:
                pass
            else:
                raise ValueError()
            return parsed
        except (ValueError, TypeError):
            raise EgressError("unsafe_source_url") from None

    def _request(self, url, max_bytes):
        host = urllib.parse.urlsplit(url).hostname
        # Reserve each host slot atomically; shared threads cannot bypass pacing.
        with self.lock:
            now = time.monotonic()
            wait = max(0, self.last_requests.get(host, 0) + self.minimum_interval - now)
            if wait > 30:
                raise EgressError("source_rate_limited")
            self.last_requests[host] = now + wait
        if wait:
            time.sleep(wait)
        status, headers, body = self.request(url, max_bytes=max_bytes)
        if len(body) > max_bytes:
            raise EgressError("source_too_large")
        return status, headers, body

    def fetch(self, url):
        parsed = self.validate(url)
        host = parsed.hostname
        with self.lock:
            cached = self.robots.get(host)
        if not cached or cached[0] < time.monotonic():
            robots_url = f"https://{host}/robots.txt"
            status, _, raw = self._request(robots_url, 100_000)
            parser = urllib.robotparser.RobotFileParser(robots_url)
            if status == 404:
                parser.parse([])
            elif status == 200:
                parser.parse(raw.decode("utf-8", errors="replace").splitlines())
            else:
                raise EgressError("robots_unavailable")
            with self.lock:
                self.robots[host] = (time.monotonic() + 300, parser)
        else:
            parser = cached[1]
        if not parser.can_fetch(AGENT, url):
            raise EgressError("robots_disallowed")
        delay = parser.crawl_delay(AGENT) or parser.crawl_delay("*") or 0
        if delay > self.minimum_interval:
            # Operators must explicitly configure the larger interval; no silent bypass.
            raise EgressError("robots_crawl_delay_requires_configuration")
        status, headers, body = self._request(url, self.max_bytes)
        if 200 <= status < 300:
            media_type = headers.get("content-type", "").split(";", 1)[0].lower()
            if media_type not in ("text/html", "text/plain", "application/xhtml+xml"):
                raise EgressError("unsupported_source_type")
        # Never follow redirects here. The Edge caller revalidates every hop.
        return status, headers, body


def serve():
    token = os.environ.get("RAD_RESEARCH_EGRESS_TOKEN", "")
    hosts = {
        x.strip().lower()
        for x in os.environ.get("RAD_RESEARCH_EGRESS_HOSTS", "").split(",")
        if x.strip()
    }
    if len(token) < 32 or not hosts:
        raise SystemExit(
            "A 32-character token and explicit approved host allowlist are required"
        )
    fetcher = ProtectedFetcher(
        hosts,
        minimum_interval=max(
            1, float(os.environ.get("RAD_RESEARCH_EGRESS_INTERVAL", "1"))
        ),
    )
    for host in hosts:
        fetcher.validate(f"https://{host}/")
    capacity = threading.BoundedSemaphore(4)

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass  # Never log article queries or credentials.

        def respond(self, status, value):
            body = json.dumps(value).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_POST(self):
            self.connection.settimeout(5)
            authorization = self.headers.get("Authorization", "")
            # HTTP headers may contain Latin-1 bytes. Compare bounded bytes so
            # malformed credentials receive the same private 403 response.
            if (
                self.path != "/fetch"
                or len(authorization) > 4096
                or not hmac.compare_digest(
                    authorization.encode("utf-8"), ("Bearer " + token).encode("utf-8")
                )
            ):
                return self.respond(403, {"error": "forbidden"})
            if not capacity.acquire(blocking=False):
                return self.respond(429, {"error": "source_rate_limited"})
            try:
                size = int(self.headers.get("Content-Length", "0"))
                if not 0 < size <= 4096 or self.headers.get("Transfer-Encoding"):
                    raise EgressError("invalid_request")
                value = json.loads(self.rfile.read(size))
                if (
                    not isinstance(value, dict)
                    or set(value) != {"url"}
                    or not isinstance(value["url"], str)
                ):
                    raise EgressError("invalid_request")
                status, headers, body = fetcher.fetch(value["url"])
                self.respond(
                    200,
                    {
                        "status": status,
                        "headers": headers,
                        "body_base64": base64.b64encode(body).decode("ascii"),
                    },
                )
            except EgressError as error:
                self.respond(422, {"error": str(error)})
            except Exception:
                self.respond(422, {"error": "invalid_request"})
            finally:
                capacity.release()

    # HTTP is loopback-only. The operator supplies authenticated HTTPS ingress.
    server = ThreadingHTTPServer(
        ("127.0.0.1", int(os.environ.get("RAD_RESEARCH_EGRESS_PORT", "64980"))), Handler
    )
    server.daemon_threads = True
    server.serve_forever()


if __name__ == "__main__":
    serve()
