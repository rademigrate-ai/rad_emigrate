"""Versioned capture adapters; raw bytes and historical extraction stay immutable."""

from __future__ import annotations

import copy
import re
from urllib.parse import unquote, urljoin, urlsplit

from bs4 import BeautifulSoup

from tools.content_completion.country_labels import COUNTRIES
from tools.plan3_content.parser import (
    digest,
    extract,
    normalize_url,
    search_normalize,
    text,
)

PARSER_VERSION = "rad-owned-article-v4"
HOSTS = {"radvisa.com", "digivisa.ir", "radmohajer.ir"}


def original_url(value, base=None):
    """Unwrap archived links without fetching or collapsing encoded delimiters."""
    value = urljoin(base, value) if base else value
    parsed = urlsplit(value)
    if parsed.hostname in {
        "web.archive.org",
        "www.web.archive.org",
    } or parsed.path.startswith("/web/"):
        match = re.match(r"^/web/\d{1,14}(?:[a-z_]+)?/(https?://.+)$", parsed.path)
        if not match:
            raise ValueError("unsupported_archive_link")
        value = match[1] + (("?" + parsed.query) if parsed.query else "")
    return normalize_url(value)


def country_evidence(title, url, body):
    """Never infer India from engineering, UK from Ukraine or Rome from a form."""
    aliases = copy.deepcopy(COUNTRIES)
    aliases["GB"] += ["انگلیس"]
    aliases["US"] += ["ایالات متحده", "ایالات متحده آمریکا"]
    aliases["AE"] = ["امارات", "امارات متحده عربی", "United Arab Emirates", "UAE"]
    hits = {}
    for label, value in (
        ("title", title),
        ("url_path", unquote(urlsplit(url).path).replace("-", " ")),
        ("body", body),
    ):
        normalized = search_normalize(value)
        records = []
        for code, names in aliases.items():
            for name in names:
                needle = search_normalize(name)
                match = re.search(
                    r"(?<!\w)" + re.escape(needle) + r"(?!\w)", normalized
                )
                if match:
                    records.append(
                        {
                            "country_code": code,
                            "location": label,
                            "matched_alias": name,
                            "normalized_excerpt": normalized[
                                max(0, match.start() - 70) : match.end() + 100
                            ],
                        }
                    )
                    break
        hits[label] = records
    title_codes = {r["country_code"] for r in hits["title"]}
    path_codes = {r["country_code"] for r in hits["url_path"]}
    body_codes = {r["country_code"] for r in hits["body"]}
    disagreement = bool(title_codes and path_codes and title_codes != path_codes)
    chosen = set() if disagreement else title_codes or path_codes
    # Body mentions alone are candidates: neighbors, examples and origin countries
    # are not automatic destination assignments.
    return {
        "country_codes": sorted(chosen),
        "evidence": [r for group in hits.values() for r in group],
        "body_candidates": sorted(body_codes),
        "human_review_required": disagreement or not chosen or len(chosen) != 1,
        "disagreement": disagreement,
    }


def _rewrite_links(soup, base):
    links = []
    for node in soup.select("a[href]"):
        original = str(node["href"])
        try:
            resolved = original_url(original, base)
        except (ValueError, UnicodeError):
            continue
        links.append(
            {
                "original_href": original,
                "url": resolved,
                "label": text(node.get_text(" ", strip=True)),
            }
        )
        node["href"] = resolved
    return links


def _parse_region(region, url, title, partial=False):
    region = copy.deepcopy(region)
    multipart = bool(
        region.select_one(".article-index,.pagenavcounter,table.contenttoc")
    )
    for node in region.select(
        ".article-info,.page-header,.pagenav,.pagination,script,style,form,nav"
    ):
        node.decompose()
    owned_links = _rewrite_links(region, url)
    wrapper = BeautifulSoup(
        '<html lang="fa"><head></head><body><div itemprop="articleBody"></div></body></html>',
        "html.parser",
    )
    wrapper.select_one('[itemprop="articleBody"]').append(region)
    result = extract(str(wrapper).encode("utf-8"), url)
    result["title"] = title
    result["parser_version"] = PARSER_VERSION
    result["original_links"] = owned_links
    result["assets"] = []
    for node in region.select("img[src],video[src],audio[src],source[src]"):
        try:
            target = original_url(str(node["src"]), url)
        except (ValueError, UnicodeError):
            continue
        result["assets"].append(
            {
                "url": target,
                "kind": node.name,
                "alt": str(node.get("alt", "")),
                "reuse_status": "rights_and_editorial_review_required",
                "public_render_allowed": False,
            }
        )
    chars = sum(len(b["text"]) for b in result["blocks"] if b["type"] != "heading")
    placeholders = (
        bool(
            re.search(
                r"(?:در حال (?:بروز|به روز)|به زودی|under construction|coming soon)",
                search_normalize(result["body_text"]),
                re.I,
            )
        )
        and chars < 300
    )
    result["completeness"] = (
        "partial_listing_excerpt"
        if partial
        else (
            "thin_or_placeholder_requires_review"
            if chars < 120 or placeholders
            else "complete_owned_article_container"
        )
    )
    if multipart and not partial:
        result["completeness"] = "multipart_article_requires_followup"
    if "\ufffd" in result["body_text"]:
        result["completeness"] = "encoding_damage_requires_review"
    result["body_sha256"] = digest(result["body_text"]) if result["body_text"] else None
    result["normalized_body_sha256"] = (
        digest(search_normalize(result["body_text"])) if result["body_text"] else None
    )
    result["structure_sha256"] = digest(result["blocks"])
    return result


def parse_mohajer(raw, url):
    """Separate owned full articles, partial listing excerpts and discovery leads."""
    if urlsplit(original_url(url)).hostname != "radmohajer.ir":
        raise ValueError("wrong_publisher_for_adapter")
    soup = BeautifulSoup(raw, "html.parser", from_encoding="utf-8")
    page = soup.select_one(".item-page")
    body = soup.select_one('[itemprop="articleBody"]')
    heading = (
        page.select_one(
            '.page-header [itemprop="headline"],.page-header h1,.page-header h2'
        )
        if page
        else None
    ) or soup.find("h1")
    title = text(heading.get_text(" ", strip=True)) if heading else ""
    canonical = soup.select_one('link[rel="canonical"][href]')
    declared = None
    if canonical:
        try:
            declared = original_url(str(canonical["href"]), url)
        except (ValueError, UnicodeError):
            pass
    discovery = []
    for node in soup.select("a[href]"):
        try:
            target = original_url(str(node["href"]), url)
            if urlsplit(target).hostname == "radmohajer.ir" and target not in discovery:
                discovery.append(target)
        except (ValueError, UnicodeError):
            pass
    dates = [
        {"field": str(node.get("itemprop") or "time"), "value": str(node["datetime"])}
        for node in soup.select("time[datetime]")
    ]
    result = {
        "title": title,
        "declared_canonical_url": declared,
        "dates": dates,
        "parser_version": PARSER_VERSION,
        "discovered_urls": discovery,
        "articles": [],
        "listing_excerpts": [],
    }
    if body is not None or page is not None:
        region = body if body is not None else page
        article = _parse_region(region, url, title)
        article["url"] = original_url(url)
        result["articles"].append(article)
        result["page_kind"] = (
            "article"
            if article["completeness"] == "complete_owned_article_container"
            else "incomplete_article"
        )
        return result
    # Blog category entries are teasers even without a read-more control. Do not
    # label a clipped paragraph a complete article merely because it is long.
    for entry in soup.select('.blog [itemprop="blogPost"],.blog .items-leading > div'):
        anchor = entry.select_one(
            '.page-header a[href],[itemprop="name"] a[href],h2 a[href]'
        )
        if not anchor:
            continue
        try:
            target = original_url(str(anchor["href"]), url)
        except (ValueError, UnicodeError):
            continue
        if urlsplit(target).hostname != "radmohajer.ir":
            continue
        parsed = _parse_region(
            entry, target, text(anchor.get_text(" ", strip=True)), partial=True
        )
        parsed["url"] = target
        if parsed["body_text"]:
            result["listing_excerpts"].append(parsed)
    result["page_kind"] = (
        "listing"
        if soup.select_one(".blog,.category-list,.categories-list")
        else "unrecognized_or_error_page"
    )
    return result
