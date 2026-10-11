"""Resumable, robots-respecting bulk acquisition pipeline for RAD Stage 3.

Reads a discovery dataset JSONL ({u, domain, prov, prior_class}), fetches each
eligible URL once (with retries/backoff), stores response bodies byte-exactly
in a content-addressed store, and appends one manifest record per attempt.

Safeguards: robots.txt per host (parsed and applied), descriptive UA, per-host
sequential requests, >=delay between requests to a host, 429 Retry-After honored,
bounded timeouts/size/retries, circuit breaker after repeated connection failures,
RFC 3986 percent-encoding of Persian/raw-space paths, resume by manifest replay.

No authentication, no form submission, no identity/proxy rotation.
All records are REVIEW_REQUIRED by default; nothing is promoted or published.
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import pathlib
import re
import ssl
import sys
import time
import urllib.error
import urllib.request
from urllib.parse import quote, urlsplit, urlunsplit

UA = "RAD-Stage3-Acquisition/1.0 (+owner-authorized read-only; github.com/rademigrate-ai/rad_emigrate)"
MAX_BYTES = 2 * 1024 * 1024
SOFT404_RE = re.compile(r"یافت\s*نشد|صفحه\s*مورد\s*نظر|not\s+found|\b404\b|صفحه وجود ندارد", re.I)
CANON_RE = re.compile(r'<link[^>]+rel=["\']canonical["\'][^>]+href=["\']([^"\']+)["\']', re.I)
CHARSET_RE = re.compile(r'charset=["\']?([\w\-]+)', re.I)


def encode_url(u: str) -> str:
    """RFC 3986 percent-encode path (Persian Unicode, raw spaces) keeping structure."""
    p = urlsplit(u.strip())
    path = quote(p.path, safe="/-_.~%!$&'()*+,;=:@")
    return urlunsplit((p.scheme, p.netloc.lower(), path, p.query, p.fragment))


def now() -> str:
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


class Robots:
    def __init__(self, root: pathlib.Path, ua: str):
        self.root = root
        self.ua = ua
        self.rules: dict[str, list[tuple[str, str]]] = {}
        self.evidence: dict[str, dict] = {}

    def load(self, domain: str, fetch) -> None:
        body = None
        cache = self.root / "raw" / domain / "robots.txt"
        if cache.is_file():
            body = cache.read_bytes()
            self.evidence[domain] = {"status": "cached", "sha256": hashlib.sha256(body).hexdigest()}
        else:
            try:
                status, body, _ = fetch(f"https://{domain}/robots.txt")
            except Exception as e:
                status, body = f"fetch_error: {type(e).__name__}", None
            if body is not None:
                cache.parent.mkdir(parents=True, exist_ok=True)
                cache.write_bytes(body)
            self.evidence[domain] = {"status": status}
        rules: list[tuple[str, str]] = []
        if body:
            agent = "*"
            for line in body.decode("utf-8", "replace").splitlines():
                line = line.strip()
                if line.lower().startswith("user-agent:"):
                    agent = line.split(":", 1)[1].strip()
                elif line.lower().startswith("disallow:") and agent in ("*", self.ua.split("/")[0]):
                    path = line.split(":", 1)[1].strip()
                    if path:
                        rules.append((agent, path))
        self.rules[domain] = rules

    def allowed(self, domain: str, url: str) -> bool:
        path = urlsplit(url).path or "/"
        for _agent, dis in self.rules.get(domain, []):
            if path.startswith(dis):
                return False
        return True


class _Recorder(urllib.request.HTTPRedirectHandler):
    def __init__(self):
        self.chain: list[dict] = []

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        self.chain.append({"from": req.full_url, "to": newurl, "status": code})
        return super().redirect_request(req, fp, code, msg, headers, newurl)


class Fetcher:
    def __init__(self, timeout: int, retries: int):
        self.timeout = timeout
        self.retries = retries
        self.ctx = ssl.create_default_context()

    def raw_get(self, url: str, method: str = "GET"):
        req = urllib.request.Request(encode_url(url), headers={"User-Agent": UA, "Accept": "text/html,application/xhtml+xml,*/*"})
        rec = _Recorder()
        opener = urllib.request.build_opener(rec, urllib.request.HTTPSHandler(context=self.ctx))
        r = opener.open(req, timeout=self.timeout)
        body = r.read(MAX_BYTES + 1) if method == "GET" else b""
        return r.status, body[:MAX_BYTES], {"final": r.geturl(), "ctype": r.headers.get("Content-Type", ""),
                                            "retry_after": r.headers.get("Retry-After"), "chain": rec.chain}


def _classify(status: int, body: bytes, ctype: str, final: str, chain: list) -> str:
    if status in (401, 403):
        return "restricted"
    if status == 404 or status >= 500:
        return "hard_404" if status == 404 else "server_error"
    if "html" not in (ctype or "") and "html" not in (body[:512].decode("utf-8", "replace").lower()):
        return "non_html"
    title_m = re.search(rb"<title[^>]*>(.*?)</title>", body[:8192], re.I | re.S)
    title = title_m.group(1).decode("utf-8", "replace") if title_m else ""
    if SOFT404_RE.search(title) or any("/404" in c.get("to", "") for c in chain):
        return "soft_404"
    if status == 200:
        return "redirect_live" if chain else "live_200"
    return f"http_{status}"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dataset", required=True)
    ap.add_argument("--root", required=True)
    ap.add_argument("--delay", type=float, default=2.2)
    ap.add_argument("--timeout", type=int, default=15)
    ap.add_argument("--retries", type=int, default=2)
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--retry-errors", action="store_true")
    a = ap.parse_args()

    root = pathlib.Path(a.root)
    manifest_path = root / "manifests" / "acquire_manifest.jsonl"
    state_path = root / "manifests" / "acquire_state.json"
    manifest_path.parent.mkdir(parents=True, exist_ok=True)

    rows = [json.loads(l) for l in pathlib.Path(a.dataset).read_text(encoding="utf-8").splitlines() if l.strip()]

    # resume: replay manifest
    done: dict[tuple[str, str], dict] = {}
    if manifest_path.is_file():
        for l in manifest_path.read_text(encoding="utf-8").splitlines():
            if l.strip():
                r = json.loads(l)
                done[(r["domain"], r["u"])] = r
    state = json.loads(state_path.read_text(encoding="utf-8")) if state_path.is_file() else {}

    fetcher = Fetcher(a.timeout, a.retries)
    robots = Robots(root, UA)

    def _fetch(u: str):
        last = None
        for attempt in range(a.retries + 1):
            try:
                return fetcher.raw_get(u)
            except urllib.error.HTTPError as e:
                if e.code == 429:
                    wait = min(int(e.headers.get("Retry-After", "30") or 30), 90)
                    print(f"    429 Retry-After {wait}s", flush=True)
                    time.sleep(wait)
                    last = e
                    continue
                body = e.read()[:1024] if hasattr(e, "read") else b""
                return e.code, body, {"final": u, "ctype": "", "retry_after": None, "chain": []}
            except Exception as e:  # timeouts, resets
                last = e
                time.sleep(3 * (attempt + 1))
        raise last if last else RuntimeError("fetch failed")

    domains = []
    for r in rows:
        if r["domain"] not in domains:
            domains.append(r["domain"])
    preferred = ["radmohajer.ir", "radvisa.com", "digivisa.ir"]
    domains.sort(key=lambda d: preferred.index(d) if d in preferred else 99)
    for d in domains:
        robots.load(d, _fetch)
        print(f"robots {d}: {robots.evidence[d]} disallow={robots.rules.get(d)}", flush=True)

    # priority: live evidence first (sitemap/nav), then archive/inventory-only; pilot-captured reused, not refetched
    def prio(r):
        p = set(r["prov"])
        if "pilot_capture" in p:
            return 0
        if any(x.startswith(("live_sitemap", "nav_home")) for x in p):
            return 1
        return 2
    ordered = sorted(rows, key=lambda r: (preferred.index(r["domain"]) if r["domain"] in preferred else 99, prio(r), r["u"]))

    failures_streak: dict[str, int] = {}
    stats: dict[str, dict] = {}
    processed = 0
    with manifest_path.open("a", encoding="utf-8") as mf:
        for r in ordered:
            dom, u = r["domain"], r["u"]
            st = stats.setdefault(dom, {"attempted": 0, "live_200": 0, "redirect_live": 0, "soft_404": 0,
                                        "hard_404": 0, "restricted": 0, "server_error": 0, "non_html": 0,
                                        "skipped_pilot": 0, "skipped_robots": 0, "error": 0})
            prev = done.get((dom, u))
            if prev and (not a.retry_errors or prev.get("class") not in ("server_error", "error")):
                continue
            if state.get(dom, {}).get("circuit_open"):
                print(f"[{dom}] circuit open; skipping remaining", flush=True)
                break
            if a.limit and processed >= a.limit:
                break
            processed += 1
            if "pilot_capture" in r["prov"]:
                rec = {"domain": dom, "u": u, "class": "reused_pilot_capture", "at": now(),
                       "prov": r["prov"], "review_status": "REVIEW_REQUIRED",
                       "note": "byte-exact capture exists in stage3_three_site_snapshot_pilot_20261011"}
                mf.write(json.dumps(rec, ensure_ascii=False) + "\n"); mf.flush()
                st["skipped_pilot"] += 1
                continue
            if not robots.allowed(dom, u):
                rec = {"domain": dom, "u": u, "class": "robots_disallowed", "at": now(), "prov": r["prov"],
                       "review_status": "REVIEW_REQUIRED"}
                mf.write(json.dumps(rec, ensure_ascii=False) + "\n"); mf.flush()
                st["skipped_robots"] += 1
                continue
            try:
                status, body, meta = _fetch(u)
                cls = _classify(status, body, meta["ctype"], meta["final"], meta["chain"])
                sha = None
                if body and cls in ("live_200", "redirect_live", "soft_404", "non_html"):
                    sha = hashlib.sha256(body).hexdigest()
                    dest = root / "raw" / dom / (sha + ".html")
                    if not dest.exists():
                        dest.parent.mkdir(parents=True, exist_ok=True)
                        dest.write_bytes(body)
                enc = "utf-8"
                cm = CHARSET_RE.search(body[:4096].decode("utf-8", "replace"))
                if cm: enc = cm.group(1)
                canon = None
                cm2 = CANON_RE.search(body[:65536].decode("utf-8", "replace"))
                if cm2: canon = cm2.group(1).strip()
                rec = {"domain": dom, "u": u, "normalized_fetch_url": encode_url(u), "at": now(),
                       "http_status": status, "class": cls, "final_url": meta["final"],
                       "redirect_chain": meta["chain"], "canonical_url": canon,
                       "content_type": meta["ctype"], "encoding": enc,
                       "bytes": len(body), "sha256": sha,
                       "snapshot_path": f"raw/{dom}/{sha}.html" if sha else None,
                       "prov": r["prov"], "retry_history": [],
                       "robots": "allowed", "review_status": "REVIEW_REQUIRED",
                       "truncated_2mb": len(body) >= MAX_BYTES}
                mf.write(json.dumps(rec, ensure_ascii=False) + "\n"); mf.flush()
                st[cls] = st.get(cls, 0) + 1
                failures_streak[dom] = 0
            except Exception as e:
                rec = {"domain": dom, "u": u, "at": now(), "class": "error",
                       "error": f"{type(e).__name__}: {e}", "prov": r["prov"], "review_status": "REVIEW_REQUIRED"}
                mf.write(json.dumps(rec, ensure_ascii=False) + "\n"); mf.flush()
                st["error"] += 1
                failures_streak[dom] = failures_streak.get(dom, 0) + 1
                if failures_streak[dom] >= 15:
                    state.setdefault(dom, {})["circuit_open"] = True
                    print(f"[{dom}] circuit breaker: 15 consecutive connection failures", flush=True)
            st["attempted"] += 1
            state[dom] = {**state.get(dom, {}), **st}
            state_path.write_text(json.dumps(state, indent=1), encoding="utf-8")
            time.sleep(a.delay)
            if processed % 100 == 0:
                print(f"progress {processed}: {json.dumps(stats)}", flush=True)
    print("FINAL", json.dumps(stats, indent=1), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
