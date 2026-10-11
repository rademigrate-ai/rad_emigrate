#!/usr/bin/env python3
"""Sensitive-data scanner for Stage 3 artifacts (stdlib-only).

Scans text/JSONL/HTML files for credentials and private data while treating
public ASP.NET __VIEWSTATE/__EVENTVALIDATION fields contextually: they are
reported as 'info' findings for review, never auto-classified as secrets.

CLI:
  python scan_secrets.py <path> [<path> ...] [--json out.json]

Exit code 0 = no BLOCK findings; 1 = at least one BLOCK finding.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

# severity: block = must not be committed; review = human judgement needed
#           (e.g. public business contact info, VIEWSTATE); info = telemetry
PATTERNS = [
    ("private_key_block", "block",
     re.compile(r"-----BEGIN (RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----")),
    ("aws_access_key", "block",
     re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
    ("aws_secret_key", "block",
     re.compile(r"(?i)aws_secret_access_key\s*[:=]\s*['\"]?[A-Za-z0-9/+=]{40}")),
    ("github_token", "block",
     re.compile(r"\b(gh[pousr]_[A-Za-z0-9]{36,255})\b")),
    ("supabase_service_key", "block",
     re.compile(r"\bsb_secret_[A-Za-z0-9_-]{20,}\b")),
    ("supabase_jwt_admin", "block",
     re.compile(r"\bservice_role.{0,40}eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.")),
    ("supabase_db_url", "block",
     re.compile(r"postgres(?:ql)?://[^\s\"']+@[^/\s\"']*(?:supabase|pooler)[^\s\"']*",
                re.I)),
    ("generic_db_url_creds", "block",
     re.compile(r"postgres(?:ql)?://[A-Za-z0-9_]+:[^@\s\"']{6,}@")),
    ("bearer_token", "block",
     re.compile(r"(?i)bearer\s+[A-Za-z0-9._\-]{24,}")),
    ("jwt", "block",
     re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b")),
    ("openai_key", "block", re.compile(r"\bsk-[A-Za-z0-9]{48,}\b")),
    ("stripe_key", "block", re.compile(r"\b[sr]k_(?:live|test)_[A-Za-z0-9]{20,}\b")),
    ("google_api_key", "block", re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b")),
    ("basic_auth_url", "block",
     re.compile(r"https?://[A-Za-z0-9_.-]+:[^@\s\"'/]{4,}@")),
    ("session_cookie_value", "review",
     re.compile(r"(?i)(sessionid|phpsessid|aspsessionid|connect\.sid)\s*=\s*"
                r"[A-Za-z0-9+/=]{20,}")),
    ("viewstate", "review",
     re.compile(r'name="__VIEWSTATE"[^>]*value="([^"]{40,})"')),
    ("private_email", "review",
     re.compile(r"\b[A-Za-z0-9._%+-]+@(?!gmail|yahoo|outlook|hotmail|icloud|aol|protonmail|proton|mail|radmohajer|radvisa|digivisa)"
                r"[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b")),
    ("national_id_like", "review",
     re.compile(r"(?i)(national.?id|passport.?no|شماره ملی|شماره پاسپورت)\D{0,5}\d{6,}")),
]

VIEWSTATE_NOTE = ("Public ASP.NET VIEWSTATE is base64 page state; not a secret "
                  "by itself, but must be reviewed for embedded personal data.")


def scan_text(text: str, source: str = "") -> list[dict]:
    findings = []
    for name, severity, rx in PATTERNS:
        for m in rx.finditer(text):
            ctx_start = max(0, m.start() - 40)
            ctx_end = min(len(text), m.end() + 40)
            snippet = text[ctx_start:ctx_end].replace("\n", " ")
            findings.append({
                "rule": name, "severity": severity, "source": source,
                "offset": m.start(),
                "context": snippet,
                "note": VIEWSTATE_NOTE if name == "viewstate" else None,
            })
    return findings


def scan_file(path: pathlib.Path) -> list[dict]:
    try:
        data = path.read_bytes()
    except OSError as e:
        return [{"rule": "unreadable", "severity": "review",
                 "source": str(path), "error": str(e)}]
    # binary guard
    if b"\x00" in data[:4096]:
        return []
    text = data.decode("utf-8", "replace")
    return scan_text(text, source=str(path))


def iter_files(root: pathlib.Path):
    for p in sorted(root.rglob("*")):
        if p.is_file():
            yield p


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("paths", nargs="+")
    ap.add_argument("--json", help="write findings JSON to this path")
    args = ap.parse_args()
    all_findings = []
    for raw in args.paths:
        p = pathlib.Path(raw)
        if p.is_dir():
            for f in iter_files(p):
                all_findings.extend(scan_file(f))
        elif p.is_file():
            all_findings.extend(scan_file(p))
    blocks = [f for f in all_findings if f["severity"] == "block"]
    reviews = [f for f in all_findings if f["severity"] == "review"]
    report = {
        "scanned_paths": args.paths,
        "block_findings": len(blocks),
        "review_findings": len(reviews),
        "findings": all_findings,
    }
    if args.json:
        pathlib.Path(args.json).write_text(
            json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"block": len(blocks), "review": len(reviews)},
                     ensure_ascii=False))
    return 1 if blocks else 0


if __name__ == "__main__":
    sys.exit(main())
