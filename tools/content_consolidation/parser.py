"""Bind legacy bodies to the actual H1 article box, never the largest sidebar.

The sealed Plan3 extractor remains immutable/reproducible. This versioned adapter
records excluded chrome separately; source HTML and old parsed records survive.
"""

from urllib.parse import urljoin, urlsplit

from bs4 import BeautifulSoup

from tools.plan3_content.parser import digest, extract, text


def extract_primary(html: bytes, url: str) -> dict:
    soup = BeautifulSoup(html, "html.parser", from_encoding="utf-8")
    omitted = []
    candidates = soup.select(".BoxSizeAsli .Box > .BoxCenter")
    if candidates:
        h1 = soup.find("h1")
        box = h1.find_parent(class_="Box") if h1 else None
        chosen = box.find(class_="BoxCenter", recursive=False) if box else None
        if chosen is None:
            return {
                "title": text(h1.get_text(" ", strip=True)) if h1 else "",
                "body_text": "",
                "blocks": [],
                "body_status": "unbound_article_region",
                "warnings": ["primary_article_region_requires_review"],
                "selector": None,
                "omitted_regions": [],
                "language": None,
            }
        for node in candidates:
            if (
                node is not chosen
                and chosen not in node.parents
                and node not in chosen.parents
            ):
                value = text(node.get_text(" ", strip=True))
                omitted.append(
                    {
                        "reason": "separate_nonarticle_box_not_owned_by_h1",
                        "sha256": digest(value),
                        "chars": len(value),
                    }
                )
                node.decompose()
        # Legacy navigation/date/comment links live in their own first Row.
        # Retain metadata in the correction ledger, not in the article prose.
        for node in list(chosen.find_all(class_="Row", recursive=False)):
            if node.select_one(".DateRegister, a.Back") and not node.select_one(
                "p,h2,h3,table,ul,ol"
            ):
                value = text(node.get_text(" ", strip=True))
                omitted.append(
                    {
                        "reason": "article_navigation_date_comment_chrome",
                        "sha256": digest(value),
                        "text": value,
                    }
                )
                node.decompose()
    body = (
        chosen
        if candidates
        else soup.select_one(
            '[itemprop="articleBody"], .item-page .article-body, article .entry-content, .item-page'
        )
    )
    assets = []
    if body:
        for node in body.select(
            "img[src],video[src],audio[src],source[src],iframe[src]"
        ):
            target = urljoin(url, str(node.get("src", "")))
            if urlsplit(target).scheme in ("https", "http"):
                assets.append(
                    {
                        "url": target,
                        "kind": node.name,
                        "alt": str(node.get("alt", "")),
                        "reuse_status": "rights_and_technical_review_required",
                        "public_render_allowed": False,
                    }
                )
    result = extract(str(soup).encode("utf-8"), url)
    result["selector_version"] = "h1-owned-body-v2"
    result["omitted_regions"] = omitted
    result["source_assets"] = assets
    return result
