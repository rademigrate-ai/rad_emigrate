"""Source-specific extraction; original body text and tables remain available."""

from __future__ import annotations

import hashlib
import json
import re
import unicodedata
from urllib.parse import (
    parse_qsl,
    quote,
    unquote,
    urlencode,
    urljoin,
    urlsplit,
    urlunsplit,
)

from bs4 import (
    BeautifulSoup,
    Comment,
    Declaration,
    NavigableString,
    ProcessingInstruction,
    Tag,
)

HOSTS = frozenset({"radvisa.com", "digivisa.ir", "radmohajer.ir"})
TRACKING = {"fbclid", "gclid", "_ga", "ref", "ref_src", "yclid", "mc_cid", "mc_eid"}
REMOVED = ("script", "style", "iframe", "object", "embed", "noscript", "template")


def normalize_url(value: str, base: str | None = None) -> str:
    value = urljoin(base, value.strip()) if base else value.strip()
    p = urlsplit(value)
    if p.scheme not in ("http", "https") or p.username or p.password:
        raise ValueError("unsafe_url")
    host = (p.hostname or "").lower().removeprefix("www.")
    if not host or p.port not in (None, 80, 443):
        raise ValueError("unsafe_url")
    path = unicodedata.normalize("NFC", p.path) or "/"
    decoded = unquote(path, errors="strict")
    if any(ord(c) < 32 for c in decoded) or "\\" in decoded:
        raise ValueError("unsafe_url")
    # Do not merge case-sensitive paths, language variants or meaningful query IDs.
    if path != "/":
        path = path.rstrip("/")
    query = sorted(
        (
            (k, v)
            for k, v in parse_qsl(p.query, keep_blank_values=True)
            if not k.lower().startswith("utm_") and k.lower() not in TRACKING
        ),
        key=lambda pair: pair[0],
    )
    path = quote(path, safe="/%:@!$&'()*+,;=-._~")
    # Decode only unreserved ASCII; encoded slashes, percent signs and separators
    # may carry meaning and must never be collapsed into another source identity.
    path = re.sub(
        r"%([0-9a-fA-F]{2})",
        lambda m: (
            chr(int(m[1], 16))
            if re.fullmatch(r"[A-Za-z0-9._~-]", chr(int(m[1], 16)))
            else "%" + m[1].upper()
        ),
        path,
    )
    return urlunsplit(("https", host, path, urlencode(query), ""))


def text(value: str) -> str:
    return re.sub(r"\s+", " ", unicodedata.normalize("NFC", value)).strip()


def search_normalize(value: str) -> str:
    """Search/dedup key only. Never replace displayed source text with this key."""
    value = value.translate(
        str.maketrans("يك٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹", "یک01234567890123456789")
    )
    return text(re.sub(r"[\u064b-\u065f\u0670\u0640]", "", value)).casefold()


def digest(value: object) -> str:
    data = (
        value
        if isinstance(value, str)
        else json.dumps(
            value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
        )
    )
    return hashlib.sha256(data.encode("utf8")).hexdigest()


def extract(html: bytes, url: str) -> dict:
    soup = BeautifulSoup(html, "html.parser", from_encoding="utf-8")
    document_base = url
    base = soup.find("base", href=True)
    if base:
        candidate = urljoin(url, str(base["href"]))
        try:
            normalize_url(candidate)
            document_base = (
                candidate  # Keep trailing slash semantics for relative links.
            )
        except (ValueError, UnicodeError):
            pass
    h1 = soup.find("h1")
    title = (
        text(h1.get_text(" ", strip=True))
        if h1
        else text(soup.title.get_text(" ", strip=True))
        if soup.title
        else ""
    )
    links = []
    for node in soup.select('a[href], link[rel="alternate"], link[rel="canonical"]'):
        raw = node.get("href", "")
        try:
            target = normalize_url(raw, document_base)
        except (ValueError, UnicodeError):
            continue
        links.append(
            {
                "url": target,
                "label": text(node.get_text(" ", strip=True)),
                "rel": node.get("rel", []),
                "hreflang": node.get("hreflang"),
            }
        )
    canonical = next((a["url"] for a in links if "canonical" in a["rel"]), None)
    html_language = (
        (soup.html.get("lang", "") if soup.html else "").split("-")[0].lower()
    )
    dates = []
    for node in soup.select(
        'meta[property], meta[name], time, [itemprop="datePublished"], [itemprop="dateModified"]'
    ):
        key = node.get("property") or node.get("name") or node.get("itemprop") or "time"
        if (
            any(
                word in key.lower()
                for word in ["date", "time", "published", "modified"]
            )
            or node.name == "time"
        ):
            value = (
                node.get("content")
                or node.get("datetime")
                or text(node.get_text(" ", strip=True))
            )
            if value:
                dates.append({"field": key, "value": value, "evidence": "page_markup"})
    for node in soup.select('script[type="application/ld+json"]'):
        try:
            data = json.loads(node.string or node.get_text())

            def visit(obj):
                if isinstance(obj, dict):
                    for k, v in obj.items():
                        if k in ("datePublished", "dateModified") and isinstance(
                            v, str
                        ):
                            dates.append(
                                {"field": k, "value": v, "evidence": "json_ld"}
                            )
                        elif isinstance(v, (list, dict)):
                            visit(v)
                elif isinstance(obj, list):
                    for v in obj:
                        visit(v)

            visit(data)
        except (ValueError, TypeError, RecursionError):
            pass
    selector = None
    body = None
    for candidate in [
        '[itemprop="articleBody"]',
        ".BoxSizeAsli .Box > .BoxCenter",
        ".item-page .article-body",
        "article .entry-content",
        ".item-page",
    ]:
        nodes = soup.select(candidate)
        if nodes:
            body, selector = (
                max(nodes, key=lambda n: len(n.get_text(" ", strip=True))),
                candidate,
            )
            break
    if body is None:
        return {
            "title": title,
            "blocks": [],
            "body_text": "",
            "body_status": "no_recognized_article_container",
            "language": html_language or None,
            "links": links,
            "canonical_url": canonical,
            "dates": dates,
            "selector": None,
            "warnings": [],
            "source_container_text_chars": 0,
        }
    # Metadata/navigation have already been captured. Detach the owned article
    # subtree instead of serializing and reparsing every large legacy page.
    body = body.extract()
    warnings = []
    for comment in body.find_all(
        string=lambda value: isinstance(
            value, (Comment, Declaration, ProcessingInstruction)
        )
    ):
        comment.extract()
    for node in body.select(
        ",".join(REMOVED)
        + ", .article-info, .item-page-title, .comments, .comment-list, .social-share, .pagination, nav, form, button"
    ):
        warnings.append("removed_unsafe_or_nonarticle_markup")
        node.decompose()
    for node in body.select("img"):
        if node.get("alt", "").strip():
            warnings.append("image_present_text_only_capture")
    body_links = []
    for node in body.select("a[href]"):
        try:
            target = normalize_url(node.get("href", ""), document_base)
            body_links.append(
                {"url": target, "label": text(node.get_text(" ", strip=True))}
            )
        except (ValueError, UnicodeError):
            warnings.append("unsafe_or_nonweb_reference_removed")
    blocks = []

    def emit(kind, content, **extra):
        content = text(content)
        if content:
            blocks.append({"type": kind, "text": content, **extra})

    def walk(node):
        if isinstance(node, (Comment, Declaration, ProcessingInstruction)):
            return
        if isinstance(node, NavigableString):
            emit("paragraph", str(node))
            return
        if not isinstance(node, Tag) or node.name in REMOVED:
            return
        if re.fullmatch("h[1-6]", node.name):
            emit("heading", node.get_text(" ", strip=True), level=int(node.name[1]))
        elif node.name in ("ul", "ol"):

            def li_value(li):
                children = []
                own = []
                for part in li.children:
                    if isinstance(part, Tag) and part.name in ("ul", "ol"):
                        children.append(
                            {
                                "ordered": part.name == "ol",
                                "items": [
                                    li_value(n)
                                    for n in part.find_all("li", recursive=False)
                                ],
                            }
                        )
                    else:
                        own.append(
                            part.get_text(" ", strip=True)
                            if isinstance(part, Tag)
                            else str(part)
                        )
                return {"text": text(" ".join(own)), "children": children}

            items = [li_value(n) for n in node.find_all("li", recursive=False)]
            if items:
                blocks.append(
                    {
                        "type": "numbered_list" if node.name == "ol" else "bullet_list",
                        "text": text(node.get_text(" ", strip=True)),
                        "items": items,
                    }
                )
            else:
                warnings.append("malformed_list_preserved_without_inventing_structure")
                for child in node.children:
                    walk(child)
        elif node.name == "table":
            rows = []
            for tr in node.find_all("tr"):
                if tr.find_parent("table") is not node:
                    continue
                cells = [
                    {
                        "text": text(c.get_text(" ", strip=True)),
                        "header": c.name == "th",
                        "colspan": c.get("colspan", "1"),
                        "rowspan": c.get("rowspan", "1"),
                    }
                    for c in tr.find_all(["td", "th"], recursive=False)
                ]
                if cells:
                    rows.append(cells)
            if rows:
                blocks.append(
                    {
                        "type": "table",
                        "text": text(node.get_text(" ", strip=True)),
                        "rows": rows,
                        "caption": text(node.caption.get_text(" ", strip=True))
                        if node.caption
                        else None,
                    }
                )
        elif node.name in ("p", "blockquote", "pre"):
            if node.find(["table", "ul", "ol"]):
                for child in node.children:
                    walk(child)
            else:
                kind = (
                    "heading"
                    if node.name == "p"
                    and len(node.get_text(" ", strip=True)) <= 180
                    and node.find(["strong", "b"])
                    and text(node.get_text())
                    == text(node.find(["strong", "b"]).get_text())
                    else "paragraph"
                )
                emit(kind, node.get_text(" ", strip=True))
        elif node.name in ("img", "br", "hr"):
            return
        elif not node.find(
            [
                "p",
                "table",
                "ul",
                "ol",
                "div",
                "section",
                "h1",
                "h2",
                "h3",
                "h4",
                "h5",
                "h6",
            ]
        ):
            emit("paragraph", node.get_text(" ", strip=True))
        else:
            for child in node.children:
                walk(child)

    for child in body.children:
        walk(child)
    body_text = "\n\n".join(b["text"] for b in blocks)
    full_text = text(body.get_text(" ", strip=True))
    captured = text(" ".join(b["text"] for b in blocks))
    # Preserve the full recognized subtree even when legacy markup has unusual mixed inline text.
    if full_text and captured != full_text:
        warnings.append("mixed_markup_text_comparison_requires_review")
    persian = len(re.findall(r"[\u0600-\u06ff]", body_text))
    latin = len(re.findall(r"[A-Za-z]", body_text))
    language = "fa" if persian > latin else "en" if latin else html_language or None
    if html_language in ("fa", "en") and language and html_language != language:
        warnings.append("html_language_disagrees_with_body")
    return {
        "title": title,
        "blocks": blocks,
        "body_text": body_text,
        "body_status": "complete_source_container"
        if full_text and captured == full_text
        else "partial_extraction"
        if body_text
        else "empty_body",
        "language": language,
        "html_language": html_language or None,
        "links": links,
        "canonical_url": canonical,
        "dates": dates,
        "selector": selector,
        "body_links": body_links,
        "warnings": sorted(set(warnings)),
        "source_container_text_chars": len(full_text),
    }
