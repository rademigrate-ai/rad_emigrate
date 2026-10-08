"""Deterministic URL normalization for RAD content migration."""
from urllib.parse import urlparse, urlunparse, parse_qs, urlencode

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
    q = parse_qs(p.query, keep_blank_values=False)
    q = {k: v for k, v in q.items() if k.lower() not in TRACKING_PARAMS}
    query = urlencode(q, doseq=True)
    return urlunparse(("https", host, path, "", query, ""))
