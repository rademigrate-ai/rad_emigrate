"""Stage 3 extraction + quality engine (stdlib-only, no bs4/lxml).

Reads the acquisition manifest and raw (or pilot) HTML snapshots, extracts
primary content with provenance, classifies each page PASS / REVIEW / FAIL
with reproducible reasons, and writes per-domain extracted JSONL plus a
quality ledger, duplicate map, and near-duplicate detection.

Never modifies captured HTML. Titles are never invented: fallbacks are
recorded with title_source (og:title / h1 / first_heading) and shell_title.
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import pathlib
import re
import sys
from collections import Counter
from html.parser import HTMLParser

BRAND_SHELL_RE = re.compile(r"موسسه\s*بین\s*المللی\s*راد|موسسه راد|^RAD\b|radmohajer|digivisa|radvisa|مشاوره مهاجرت و امور بین المللی راد", re.I)
SOFT404_RE = re.compile(r"یافت\s*نشد|صفحه\s*مورد\s*نظر|not\s+found|صفحه وجود ندارد", re.I)
CONTAINER_HINTS = re.compile(r"(item-page|com-content|art-post-content|art-article|entry-content|post-content|blog-content|article-content|news-content|contentbody|art-post\b|main-content|page-content|field-item|content\s*$)", re.I)
BOILER_HINTS = re.compile(r"(nav|menu|footer|sidebar|breadcrumb|cookie|social|share|banner|comment)", re.I)
MOJIBAKE_RE = re.compile(r"â€|Ø§Ù|Ø´|Ã|Â»")

MAIN_TAGS = {"article", "main"}


class PageParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.title_parts: list[str] = []
        self._in_title = False
        self.metas: dict[str, str] = {}
        self.canonical = None
        self.lang = None
        self.h1: list[str] = []
        self.h2: list[str] = []
        self._heading = None
        self._heading_buf: list[str] = []
        self.links: list[str] = []
        self._anchor = None
        self._anchor_buf: list[str] = []
        # candidate containers: stack of (tag, key, text_parts, para_parts, depth_opened)
        self.stack: list[dict] = []
        self.candidates: list[dict] = []
        self.paragraphs: list[str] = []
        self._p_buf: list[str] | None = None

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == "html" and a.get("lang"):
            self.lang = a["lang"]
        elif tag == "title":
            self._in_title = True
        elif tag == "meta":
            key = a.get("property") or a.get("name") or ""
            if key and a.get("content"):
                self.metas[key.lower()] = a["content"]
        elif tag == "link" and (a.get("rel") or "").lower() == "canonical":
            self.canonical = a.get("href")
        elif tag in ("h1", "h2"):
            self._heading = tag
            self._heading_buf = []
        elif tag == "a" and a.get("href"):
            self.links.append(a["href"])
            self._anchor = a["href"]
            self._anchor_buf = []
        elif tag == "p":
            self._p_buf = []
        elif tag in ("div", "section", "article", "main", "td"):
            key = f"{a.get('class','')} {a.get('id','')}".strip()
            if tag in MAIN_TAGS or (key and CONTAINER_HINTS.search(key) and not BOILER_HINTS.search(key)):
                c = {"tag": tag, "key": key or tag, "text": [], "paras": []}
                self.stack.append(c)
                self.candidates.append(c)
            else:
                self.stack.append(None)
        else:
            if tag not in ("script", "style", "noscript"):
                self.stack.append(None) if tag in ("span", "li", "td", "blockquote", "strong", "em", "br") else None

    def handle_endtag(self, tag):
        if tag == "title":
            self._in_title = False
        elif tag in ("h1", "h2") and self._heading == tag:
            txt = re.sub(r"\s+", " ", "".join(self._heading_buf)).strip()
            if txt:
                (self.h1 if tag == "h1" else self.h2).append(txt)
            self._heading = None
        elif tag == "a" and self._anchor is not None:
            self._anchor = None
        elif tag == "p" and self._p_buf is not None:
            txt = re.sub(r"\s+", " ", "".join(self._p_buf)).strip()
            if txt:
                self.paragraphs.append(txt)
                for c in self.stack:
                    if c:
                        c["paras"].append(txt)
            self._p_buf = None
        elif tag in ("div", "section", "article", "main", "td") and self.stack:
            self.stack.pop()

    def handle_data(self, data):
        if self._in_title:
            self.title_parts.append(data)
        if self._heading is not None:
            self._heading_buf.append(data)
        if self._p_buf is not None:
            self._p_buf.append(data)
        for c in self.stack:
            if c:
                c["text"].append(data)

    @property
    def title(self) -> str:
        return re.sub(r"\s+", " ", "".join(self.title_parts)).strip()


def pick_main(p: PageParser) -> tuple[str, str, str, list[str]]:
    """Return (text, method, confidence, headings)."""
    best = None
    for c in p.candidates:
        text = re.sub(r"\s+", " ", " ".join(c["text"])).strip()
        paras = c["paras"]
        score = len(" ".join(paras)) if paras else len(text) // 2
        if best is None or score > best[0]:
            best = (score, text, c["key"], paras)
    if best and best[0] >= 300:
        heads = [h for h in p.h1 + p.h2 if h and h not in best[2]]
        return best[1], f"container:{best[2][:60]}", "high", heads
    # fallback: paragraph-density heuristic
    joined = " ".join(p.paragraphs)
    if len(joined) >= 200:
        return joined, "paragraph_density_fallback", "medium", p.h1 + p.h2
    return joined, "low_content", "low", p.h1 + p.h2


def shingles(text: str, k: int = 5) -> set[str]:
    t = re.sub(r"\s+", " ", text.lower())
    return {t[i:i + k * 8] for i in range(0, max(len(t) - k * 8, 1), k * 8)}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--pilot-root", default="artifacts/stage3_three_site_snapshot_pilot_20261011")
    a = ap.parse_args()
    root = pathlib.Path(a.root)
    pilot = pathlib.Path(a.pilot_root)
    pilot_man = json.loads((pilot / "STAGE3_THREE_SITE_PILOT_MANIFEST.json").read_text(encoding="utf-8"))
    pilot_by_key = {(r["domain"], r["u"]): pilot / r["content_file"] for r in pilot_man["records"]}

    recs = [json.loads(l) for l in (root / "manifests" / "acquire_manifest.jsonl").read_text(encoding="utf-8").splitlines() if l.strip()]
    line_counter: Counter[str] = Counter()

    # pass 1: parse and collect common lines (boilerplate detection)
    parsed = []
    for r in recs:
        if r["class"] not in ("live_200", "redirect_live", "reused_pilot_capture"):
            continue
        src = root / r["snapshot_path"] if r.get("snapshot_path") else pilot_by_key.get((r["domain"], r["u"]))
        if src is None or not pathlib.Path(src).is_file():
            continue
        body = pathlib.Path(src).read_bytes()
        sha = r.get("sha256") or next((pr["content_sha256"] for pr in pilot_man["records"]
                                       if pr["domain"] == r["domain"] and pr["u"] == r["u"]), None)
        r["sha256"] = sha
        try:
            text = body.decode("utf-8")
        except UnicodeDecodeError:
            text = body.decode("utf-8", errors="replace")
        p = PageParser()
        try:
            p.feed(text)
        except Exception:
            pass
        main_text, method, conf, heads = pick_main(p)
        for line in re.split(r"[\n\r]+", main_text):
            ls = line.strip()
            if 20 < len(ls) < 200:
                line_counter[ls] += 1
        parsed.append((r, p, text, main_text, method, conf))

    common = {l for l, c in line_counter.items() if c >= max(4, len(parsed) * 0.25)}

    out_dir = root / "extracted"
    out_dir.mkdir(exist_ok=True)
    for dom in {r["domain"] for r in recs}:
        (out_dir / f"{dom}.jsonl").write_text("", encoding="utf-8")  # idempotent rebuild
    seen_hash: dict[str, str] = {}
    seen_shingle: list[tuple[str, set[str]]] = []
    ledger = []
    dup_map = []
    stats = Counter()

    for r, p, text, main_text, method, conf in parsed:
        dom, u = r["domain"], r["u"]
        body_sha = r["sha256"]  # set in pass 1 for every parsed record
        reasons = []
        cls = "PASS"
        raw_title = p.title
        shell_title = bool(BRAND_SHELL_RE.search(raw_title)) or not raw_title
        title, title_source = raw_title, "html_title"
        if shell_title:
            og = p.metas.get("og:title")
            if og and not BRAND_SHELL_RE.search(og):
                title, title_source = og.strip(), "og:title_fallback_shell_title"
                reasons.append("shell_title_used_og")
            elif p.h1:
                title, title_source = p.h1[0], "h1_fallback_shell_title"
                reasons.append("shell_title_used_h1")
            elif p.h2:
                title, title_source = p.h2[0], "h2_fallback_shell_title"
                reasons.append("shell_title_used_h2")
            else:
                title, title_source = "", "none"
                reasons.append("shell_title_no_fallback")
        # quality
        repl = text.count("�")
        if SOFT404_RE.search(raw_title) or SOFT404_RE.search(main_text[:300]):
            cls, _ = "FAIL", reasons.append("soft404_content")
        if len(main_text) < 200:
            cls = "FAIL"; reasons.append(f"near_empty_main({len(main_text)}ch)")
        if repl > 5 or MOJIBAKE_RE.search(text[:20000]):
            cls = "FAIL"; reasons.append(f"encoding_defect(replacement={repl})")
        if r.get("truncated_2mb"):
            cls = "REVIEW" if cls == "PASS" else cls; reasons.append("response_truncated_2mb")
        if shell_title and cls == "PASS":
            cls = "REVIEW"; reasons.append("shell_title_page")
        boiler = sum(1 for line in re.split(r"[\n\r]+", main_text) if line.strip() in common)
        total_lines = max(len([l for l in re.split(r"[\n\r]+", main_text) if l.strip()]), 1)
        if boiler / total_lines > 0.6 and cls == "PASS":
            cls = "REVIEW"; reasons.append("boilerplate_heavy")
        # duplicates
        dup_of = None
        if body_sha in seen_hash:
            dup_of = seen_hash[body_sha]; cls = "REVIEW"; reasons.append(f"exact_duplicate_of:{dup_of}")
        else:
            sh = shingles(main_text)
            for other_u, other_sh in seen_shingle:
                if sh and other_sh:
                    j = len(sh & other_sh) / len(sh | other_sh)
                    if j > 0.9:
                        dup_of = other_u; cls = "REVIEW"; reasons.append(f"near_duplicate_of:{other_u}")
                        break
            seen_shingle.append((u, sh))
        if body_sha not in seen_hash:
            seen_hash[body_sha] = u
        if dup_of:
            dup_map.append({"u": u, "duplicate_of": dup_of, "kind": "exact" if "exact_duplicate" in " ".join(reasons) else "near"})
        rec = {"domain": dom, "u": u, "final_url": r.get("final_url"), "canonical_url": p.canonical or r.get("canonical_url"),
               "snapshot_sha256": body_sha, "snapshot_path": r.get("snapshot_path") or f"pilot:{pilot_by_key.get((dom,u),'')}",
               "title": title, "title_source": title_source, "shell_title": shell_title,
               "description": p.metas.get("description", ""), "lang": p.lang or ("fa" if "/fa" in u or dom == "digivisa.ir" else None),
               "published": p.metas.get("article:published_time"), "modified": p.metas.get("article:modified_time"),
               "h1": p.h1[:3], "main_text": main_text, "main_chars": len(main_text),
               "extraction_method": method, "confidence": conf,
               "internal_links": sum(1 for l in p.links if r["domain"] in l or l.startswith("/")),
               "external_links": sum(1 for l in p.links if l.startswith("http") and r["domain"] not in l),
               "quality": cls, "quality_reasons": reasons,
               "review_status": "REVIEW_REQUIRED", "extractor": "stdlib_htmlparser_v1",
               "extracted_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")}
        stats[(dom, cls)] += 1
        ledger.append({"u": u, "domain": dom, "quality": cls, "reasons": reasons,
                       "main_chars": len(main_text), "confidence": conf, "title_source": title_source})
        with (out_dir / f"{dom}.jsonl").open("a", encoding="utf-8") as f:
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")

    (out_dir / "quality_ledger.jsonl").write_text(
        "\n".join(json.dumps(x, ensure_ascii=False) for x in ledger) + "\n", encoding="utf-8")
    (out_dir / "dup_map.json").write_text(json.dumps(dup_map, indent=1, ensure_ascii=False), encoding="utf-8")
    print(json.dumps({f"{d}:{q}": n for (d, q), n in sorted(stats.items())}, indent=1))
    print("ledger rows:", len(ledger), "| dups:", len(dup_map))
    return 0


if __name__ == "__main__":
    sys.exit(main())
