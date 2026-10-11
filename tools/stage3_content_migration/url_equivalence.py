#!/usr/bin/env python3
"""Shared URL-equivalence key (F-03) for Stage 3 ingestion tooling.

Used by BOTH simulate_ingestion.py and generate_ingest_sql.py so the
simulation and the generated SQL can never disagree about what counts as the
same document.

Equivalence rules (deliberately conservative — only transformations that
route to the same resource on the captured sites):
  * surrounding whitespace trimmed (whole URL and each path segment)
  * scheme + host lowercased; default port dropped
  * percent-encoding decoded (these sites route on decoded paths; raw
    Persian and %D8%A7... forms are the same resource)
  * percent-decoded path Unicode-normalized to NFC (composed vs decomposed
    forms of the same characters must not split a document)
  * trailing slashes ignored (https://x.ir, https://x.ir/ are one document)
  * host case folded; IDN punycode vs Unicode host forms folded

Explicitly NOT unified (distinct resources by evidence):
  * path case (ASP.NET routes may be case-insensitive, but collapsing
    distinct-case dataset rows could silently drop content — keep separate
    and let ON CONFLICT handle exact matches)
  * query strings (kept, order-preserving; only empty query dropped)
  * Persian ZWNJ vs space in paths (different bytes on disk; the sites emit
    both forms as distinct URLs)
  * fragments (dropped — never sent to servers)
"""
from __future__ import annotations

import unicodedata
import urllib.parse

DEFAULT_PORTS = {"http": "80", "https": "443"}


def url_key(u: str) -> str:
    """Canonical equivalence key for two URLs claiming the same document."""
    raw = (u or "").strip()
    if not raw:
        return ""
    # split scheme
    if "://" in raw:
        scheme, rest = raw.split("://", 1)
    else:
        scheme, rest = "https", raw
    scheme = scheme.lower()
    # fragment never participates
    rest = rest.split("#", 1)[0]
    # separate query (kept verbatim except emptiness)
    if "?" in rest:
        authority_and_path, query = rest.split("?", 1)
    else:
        authority_and_path, query = rest, None
    # authority vs path
    if "/" in authority_and_path:
        authority, path = authority_and_path.split("/", 1)
        path = "/" + path
    else:
        authority, path = authority_and_path, ""
    # userinfo kept as-is (none expected on these hosts); host + port
    if "@" in authority:
        userinfo, hostport = authority.rsplit("@", 1)
    else:
        userinfo, hostport = "", authority
    hostport = hostport.strip().rstrip(".")
    if ":" in hostport:
        host, port = hostport.rsplit(":", 1)
        if port.isdigit():
            if DEFAULT_PORTS.get(scheme) == port:
                port = ""
        else:
            host, port = hostport, ""
    else:
        host, port = hostport, ""
    host = host.strip().lower()
    if host.startswith("[") and host.endswith("]"):
        pass  # IPv6 literal: keep brackets, already lowercased
    # percent-decode + NFC on the path (percent-encoded UTF-8 only)
    path = urllib.parse.unquote(path)
    path = unicodedata.normalize("NFC", path)
    # per-segment whitespace trim, drop empty segments' meaning of trailing /
    segs = [s.strip() for s in path.split("/")]
    while segs and segs[-1] == "":
        segs.pop()
    while segs and segs[0] == "":
        segs.pop(0)
    path = "/" + "/".join(segs) if segs else ""
    key = scheme + "://"
    if userinfo:
        key += userinfo + "@"
    key += host + (":" + port if port else "") + path
    if query:
        # decode+trim+re-encode each pair so 'id= 5' and 'id=5' agree,
        # keep order and duplicate keys
        pairs = []
        for kv in query.split("&"):
            if not kv:
                continue
            k, _, v = kv.partition("=")
            k2 = urllib.parse.unquote_plus(k).strip()
            v2 = urllib.parse.unquote_plus(v).strip()
            pairs.append(urllib.parse.quote(k2, safe="") + "="
                         + urllib.parse.quote(v2, safe=""))
        if pairs:
            key += "?" + "&".join(pairs)
    return key
