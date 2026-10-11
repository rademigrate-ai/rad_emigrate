"""Deterministic URL normalization for RAD content migration.

Canonicalizes percent-encoding: a path containing raw UTF-8 (Persian) text and
the same path percent-encoded (any hex case) normalize identically. Legacy
non-UTF-8 percent-sequences are left byte-for-byte untouched rather than
mangled (decode failure keeps the original path).
"""
from urllib.parse import urlparse, urlunparse, parse_qs, urlencode, unquote, quote

TRACKING_PARAMS = {
  "utm_source","utm_medium","utm_campaign","utm_term","utm_content","utm_id",
  "gclid","fbclid","mc_cid","mc_eid","ref","ref_src","_ga","yclid",
}

def normalize_url(url: str) -> str:
    url = (url or "").strip()
    if not url:
        return ""
    if url.startswith("http://"):
        url = "https://" + url[7:]
    p = urlparse(url)
    host = (p.hostname or "").lower()
    if host.startswith("www."):
        host = host[4:]
    path = p.path or "/"
    if path != "/" and path.endswith("/"):
        path = path[:-1]
    path = _canonicalize_percent_encoding(path)
    q = parse_qs(p.query, keep_blank_values=False)
    q = {k: v for k, v in q.items() if k.lower() not in TRACKING_PARAMS}
    query = urlencode(q, doseq=True)
    return urlunparse(("https", host, path, "", query, ""))


def _canonicalize_percent_encoding(path: str) -> str:
    """Decode percent-sequences (UTF-8) then re-encode canonically.

    Legacy non-UTF-8 percent-sequences return the path unchanged (never mangled).
    """
    try:
        decoded = unquote(path, encoding="utf-8", errors="strict")
    except UnicodeDecodeError:
        return path
    return quote(decoded, safe="/?#[]@!$&'()*+,;=-._~")
