"""Independent source-to-composition proof, plus optional actual render receipts.

This module never imports the composer or its semantic classifier. Hashes,
offsets, retained equivalents and the finite paraphrase evidence are checked
against original sources, rather than trusted because an importer emitted them.
Passing composition alone does not certify a database import or UI rendering.
"""

import argparse
import gzip
import hashlib
import json
import re
import unicodedata
from functools import lru_cache
from html.parser import HTMLParser
from pathlib import Path

from tools.content_completion.country_labels import COUNTRIES


def sha(value):
    if not isinstance(value, str):
        value = json.dumps(
            value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
        )
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def _normal(value):
    value = value.translate(
        str.maketrans("يك٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹", "یک01234567890123456789")
    )
    value = re.sub(r"[\u064b-\u065f\u0670\u0640]", "", value)
    value = unicodedata.normalize("NFC", value).replace("\u200c", " ")
    return " ".join(value.casefold().split()).strip(" .!؟?؛;")


def _concepts(value):
    """Independently replay only the published V4 finite phrase equivalences."""
    value = _normal(value)
    patterns = (
        (r"(.+?) must (?:provide|submit) (.+)", False),
        (r"(.+?) (?:is|are) required (?:from|of) (.+)", True),
    )
    for expression, passive in patterns:
        match = re.fullmatch(expression, value)
        if match:
            subject, obj = (match[2], match[1]) if passive else (match[1], match[2])
            subject = re.sub(r"^(a|an|the)\s+", "", subject)
            obj = re.sub(r"^(a|an|the)\s+", "", obj)
            value = subject + " must provide " + obj
            break
    else:
        for expression in (
            r"متقاضیان باید (.+?) ارائه (?:دهند|کنند)",
            r"ارائه (.+?) برای متقاضیان الزامی است",
        ):
            match = re.fullmatch(expression, value)
            if match:
                value = "متقاضیان باید " + match[1] + " ارائه دهند"
                break
    for expression, replacement in (
        (r"\bpassport that is valid\b", "valid passport"),
        (r"\bcriteria for diagnosis\b", "diagnostic criteria"),
        (r"\badverse reactions to drugs\b", "adverse drug reactions"),
    ):
        value = re.sub(expression, replacement, value)
    return tuple(value.split())


def _medical(value):
    value = _normal(value)
    clinical = bool(
        re.search(
            r"تشخیص بیماری|درمان بیماری|درمان سرطان|عوارض جانبی|پاتوفیزیولوژی|"
            r"فارماکوکینتیک|فیزیولوژی|مکانیسم اثر|دوز دارو|دوز درمان|روش جراحی|"
            r"مراقبت بالینی|درمان بالینی|پروتکل درمان|تداخل دارو|منع مصرف|"
            r"\b(pathophysiology|pharmacokinetics|physiology|diagnosis|contraindications?|"
            r"drug interactions?|side effects?|clinical treatment|clinical nursing|"
            r"surgical technique|treatment protocol|therapeutic dose|mechanism of action|"
            r"diagnostic criteria|adverse drug reactions|adverse reactions to drugs)\b",
            value,
        )
    )
    general = bool(
        re.search(
            r"پذیرش|ویزای|مهاجرت|دانشگاه|شهریه|بورسیه|استخدام|حقوق پزشک|حقوق پرستار|"
            r"مجوز کار|معادل سازی|\b(admission|university|visa|immigration|scholarship|"
            r"employment|salary|salaries|licensing|tuition)\b",
            value,
        )
    )
    return (
        None if clinical and general else "radvisa.com" if clinical else "digivisa.ir"
    )


def _program(source, canonical):
    if not canonical:
        return "independent"
    title = _normal(source["title"])
    for name, pattern in (
        ("nursing", r"پرستار|nurs"),
        ("dentistry", r"دندان|dentist"),
        ("pharmacy", r"داروساز|داروسازی|pharmac"),
        ("medicine", r"پزشک|medical|medicine"),
        ("job-seeker", r"جستجوی کار|جاب سیکر|job seeker"),
        ("blue-card", r"بلو کارت|کارت آبی|blue card"),
        ("startup", r"استارتاپ|startup"),
        ("self-employed", r"خود اشتغال|self.employ"),
        ("school", r"مدرسه|school"),
        ("doctoral", r"دکتری|دکترا|phd|doctoral"),
    ):
        if re.search(pattern, title):
            return name
    return "general"


def _heading(source, index, default):
    for block in reversed(source["blocks"][: index + 1]):
        if block["type"] == "heading":
            return _concepts(block["text"])
    return _concepts(
        source["title"] if _context_key(source)[0] == "specific" else default
    )


def _heading_paths(source):
    annotations = {
        r["block_index"]: r for r in source.get("heading_structure_evidence", [])
    }
    stack, path, paths = [], (), []
    for index, block in enumerate(source["blocks"]):
        if block["type"] == "heading":
            level = block.get("level")
            if type(level) is not int or not 1 <= level <= 6:
                evidence = annotations.get(index, {})
                level = (
                    evidence.get("level") if evidence.get("confirmed") is True else None
                )
                level = level if type(level) is int and 1 <= level <= 6 else None
            if level is None:
                stack = [
                    (
                        None,
                        block["text"],
                        (source["source_id"], source["snapshot_id"], index),
                    )
                ]
            else:
                if level == 1:
                    stack = []
                while stack and stack[-1][0] is not None and stack[-1][0] >= level:
                    stack.pop()
                stack.append((level, block["text"], None))
            path = tuple(
                (depth, _concepts(label), unknown) for depth, label, unknown in stack
            )
        paths.append(path)
    return paths


class _HeadingText(HTMLParser):
    def __init__(self, markup):
        super().__init__(convert_charrefs=True)
        self.parts = []
        self.feed(markup)

    def handle_data(self, data):
        self.parts.append(data)


def _verify_raw_heading(source, evidence, block, cache):
    if evidence.get("confirmed") is not True:
        return True
    asset = source.get("raw_html_asset")
    expected = evidence.get("raw_html_sha256")
    if (
        not asset
        or not expected
        or expected != source.get("raw_html_sha256")
        or evidence.get("text_sha256") != sha(block["text"])
    ):
        return False
    try:
        key = (asset, expected, evidence.get("decoded_encoding", "utf-8"))
        if key not in cache:
            raw = Path(asset).read_bytes()
            if str(asset).endswith(".gz"):
                raw = gzip.decompress(raw)
            if hashlib.sha256(raw).hexdigest() != expected:
                return False
            cache[key] = (
                raw.decode("utf-8", errors="surrogateescape")
                if key[2] == "utf-8-surrogateescape-evidence-only"
                else raw.decode(key[2])
            )
        decoded = cache[key]
        matches = evidence.get("raw_matches", [])
        if not matches:
            return False
        for match in matches:
            start, end = (
                match.get("decoded_character_start"),
                match.get("decoded_character_end"),
            )
            if (
                type(start) is not int
                or type(end) is not int
                or not 0 <= start < end <= len(decoded)
            ):
                return False
            tag = decoded[start:end]
            heading = re.match(r"<h([1-6])\b", tag, re.IGNORECASE)
            if (
                not heading
                or int(heading[1]) != evidence.get("level")
                or match.get("level") != evidence.get("level")
            ):
                return False
            if (
                tag != match.get("raw_heading_tag")
                or sha(tag) != match.get("raw_heading_sha256")
                or _normal(" ".join(_HeadingText(tag).parts)) != _normal(block["text"])
            ):
                return False
        return True
    except (OSError, UnicodeError, LookupError, EOFError):
        return False


def _context_key(source):
    return _context_key_cached(
        _normal(source["title"]), tuple(sorted(source["taxonomy"]["country_codes"]))
    )


@lru_cache(maxsize=4096)
def _context_key_cached(title, country_codes):
    groups = {
        "study": (
            "تحصیل",
            "تحصیلی",
            "پذیرش",
            "دانشجویی",
            "study",
            "studying",
            "admission",
            "education",
        ),
        "work": ("کار", "کاری", "استخدام", "work", "working", "employment"),
        "investment": ("سرمایه گذاری", "investment", "investor"),
        "tourist": ("گردشگری", "توریستی", "tourist", "tourism", "visitor"),
        "family": ("خانوادگی", "ازدواج", "family", "marriage"),
    }
    routes = [
        name
        for name, words in groups.items()
        if any(
            re.search(r"(?<!\w)" + re.escape(word) + r"(?!\w)", title) for word in words
        )
    ]
    if len(routes) == 1:
        countries = [
            name for code in country_codes for name in [code, *COUNTRIES.get(code, ())]
        ]
        words = [
            *countries,
            *groups[routes[0]],
            "در",
            "به",
            "ویزا",
            "ویزای",
            "مهاجرت",
            "in",
            "to",
            "for",
            "a",
            "an",
            "the",
            "visa",
            "immigration",
        ]
        rest = title
        for word in sorted(set(words), key=lambda word: (-len(word), word)):
            rest = re.sub(r"(?<!\w)" + re.escape(_normal(word)) + r"(?!\w)", " ", rest)
        if not re.search(r"\w", rest):
            return "generic", routes[0]
    return "specific", _concepts(title)


def _scope_markers(source):
    title = _normal(source["title"])
    return (
        tuple(re.findall(r"\d+(?:[./-]\d+)*", title)),
        tuple(
            re.findall(
                r"(?<!\w)(?:without|with|except|exempt|temporary|permanent|بدون|موقت|دائم|استثنا)(?!\w).*$",
                title,
            )
        ),
        source.get("effective_date"),
    )


class AuditFailure(ValueError):
    def __init__(self, report, missing_segments):
        super().__init__(
            "source_to_composition_audit_failed:" + str(len(report["errors"]))
        )
        self.report = report
        self.missing_segments = missing_segments


def audit(sources, articles, supplements=(), route_receipts=None):
    errors, variants, covered, expected, aliases = [], {}, set(), set(), {}
    retained_count, semantic_count, exact_count = 0, 0, 0
    raw_heading_cache = {}

    def fail(code, **context):
        errors.append({"code": code, **context})

    for source in [*sources, *supplements]:
        if not source.get("blocks"):
            continue
        identity = (source["source_id"], source["snapshot_id"])
        if identity in variants and variants[identity] != source:
            fail(
                "conflicting_source_snapshot_identity",
                source_id=identity[0],
                snapshot_id=identity[1],
            )
            continue
        variants[identity] = source
        body = "\n\n".join(b["text"] for b in source["blocks"])
        if source["body_text"] != body or source.get("body_sha256", sha(body)) != sha(
            body
        ):
            fail(
                "source_body_or_hash_mismatch",
                source_id=identity[0],
                snapshot_id=identity[1],
            )
        eligible = (
            source.get("consolidation_disposition")
            == "body_ready_for_unreviewed_composition"
            or source.get("complete_article_body") is True
        )
        if eligible:
            expected.update((*identity, i) for i in range(len(source["blocks"])))
        for evidence in source.get("heading_structure_evidence", []):
            index = evidence.get("block_index")
            if (
                type(index) is not int
                or not 0 <= index < len(source["blocks"])
                or not _verify_raw_heading(
                    source, evidence, source["blocks"][index], raw_heading_cache
                )
            ):
                fail(
                    "raw_heading_structure_evidence_invalid",
                    source_id=identity[0],
                    snapshot_id=identity[1],
                    block_index=index,
                )
    scope_paths = {key: _heading_paths(source) for key, source in variants.items()}

    def origin(ref, article):
        identity = (ref.get("source_id"), ref.get("snapshot_id"))
        source = variants.get(identity)
        if source is None:
            fail(
                "orphan_source_snapshot",
                article_id=article["article_id"],
                source_id=identity[0],
                snapshot_id=identity[1],
            )
            return None
        index = ref.get("block_index")
        if type(index) is not int or not 0 <= index < len(source["blocks"]):
            fail("invalid_source_block_index", article_id=article["article_id"])
            return None
        block = source["blocks"][index]
        if ref.get("source_title", source["title"]) != source["title"]:
            fail(
                "source_title_provenance_changed",
                article_id=article["article_id"],
                source_id=identity[0],
                block_index=index,
            )
        if (
            ref.get("structure_sha256") != sha(block)
            or ref.get("sha256") != sha(block["text"])
            or ref.get("url") != source["url"]
            or ref.get("publisher", source["domain"]) != source["domain"]
        ):
            fail(
                "source_ref_hash_or_origin_changed",
                article_id=article["article_id"],
                source_id=identity[0],
                block_index=index,
            )
        start, end = ref.get("start"), ref.get("end")
        if (
            type(start) is not int
            or type(end) is not int
            or not 0 <= start <= end <= len(source["body_text"])
            or source["body_text"][start:end] != block["text"]
        ):
            fail(
                "source_ref_offsets_changed",
                article_id=article["article_id"],
                source_id=identity[0],
                block_index=index,
            )
        if source["language"] != article["locale"]:
            fail(
                "fabricated_locale_or_translation",
                article_id=article["article_id"],
                source_id=identity[0],
            )
        covered.add((*identity, index))
        return source, block, index

    seen_articles, article_blocks = set(), {}
    for article in articles:
        aid = article["article_id"]
        identity = (aid, article["locale"])
        if identity in seen_articles:
            fail("duplicate_article_locale", article_id=aid)
        seen_articles.add(identity)
        if (
            article.get("published") is not False
            or article.get("publication_allowed") is not False
        ):
            fail("unauthorized_publication_flag", article_id=aid)
        if (
            article.get("verification_state") not in (None, "unverified")
            or article.get("reviewer_id") is not None
        ):
            fail("fabricated_verification_or_review", article_id=aid)
        canonical = article.get("content_class") == "canonical"
        scoped_sources = [
            s for s in variants.values() if s["source_id"] in article["source_ids"]
        ]
        domains = {s["domain"] for s in scoped_sources}
        if "radmohajer.ir" in domains and (canonical or domains != {"radmohajer.ir"}):
            fail("radmohajer_independence_violated", article_id=aid)
        country_union = {
            c for s in scoped_sources for c in s["taxonomy"]["country_codes"]
        }
        if set(article["country_codes"]) - country_union:
            fail("fabricated_country_association", article_id=aid)
        if canonical and (
            len(article["country_codes"]) != 1 or not article.get("visa_category")
        ):
            fail("invalid_canonical_destination", article_id=aid)
        for old in article.get("source_prior_article_ids", []):
            previous = aliases.setdefault((old, article["locale"]), aid)
            if previous != aid:
                fail(
                    "prior_identity_maps_to_multiple_articles",
                    article_id=aid,
                    old_article_id=old,
                )
        blocks, refs, omitted = {}, {}, {}
        for omission in article.get("omissions", []):
            ref = omission["provenance"]
            key = (ref["source_id"], ref["snapshot_id"], ref["block_index"])
            if key in omitted:
                fail("duplicate_omission_decision", article_id=aid)
            omitted[key] = omission
        for section in article["sections"]:
            for block in section["blocks"]:
                retained_count += 1
                bid = block["id"]
                if bid in blocks:
                    fail("duplicate_retained_block_id", article_id=aid, block_id=bid)
                blocks[bid] = block
                original = block["original_structure"]
                if (
                    block["text"] != original["text"]
                    or block["type"] != original["type"]
                ):
                    fail(
                        "rendered_block_differs_from_selected_structure",
                        article_id=aid,
                        block_id=bid,
                    )
                selected = block.get("selected_origin", block["provenance"][0])
                selected_data = origin(selected, article)
                if selected_data and selected_data[1] != original:
                    fail(
                        "selected_origin_not_retained_verbatim",
                        article_id=aid,
                        block_id=bid,
                    )
                if selected_data and block["type"] == "heading":
                    chosen_source, chosen_original, chosen_index = selected_data
                    annotation = next(
                        (
                            r
                            for r in chosen_source.get("heading_structure_evidence", [])
                            if r["block_index"] == chosen_index
                        ),
                        None,
                    )
                    expected_level = chosen_original.get("level")
                    if type(expected_level) is not int or not 1 <= expected_level <= 6:
                        expected_level = (
                            annotation.get("level")
                            if annotation and annotation.get("confirmed") is True
                            else None
                        )
                    if block.get(
                        "heading_level", chosen_original.get("level")
                    ) != expected_level or (
                        annotation
                        and block.get("heading_structure_evidence") != annotation
                    ):
                        fail(
                            "rendered_heading_level_not_bound_to_selected_raw",
                            article_id=aid,
                            block_id=bid,
                        )
                if selected not in block["provenance"]:
                    fail(
                        "selected_origin_missing_from_provenance",
                        article_id=aid,
                        block_id=bid,
                    )
                preferred = _medical(block["text"])
                for ref in block["provenance"]:
                    key = (ref["source_id"], ref["snapshot_id"], ref["block_index"])
                    refs[key] = bid
                    data = origin(ref, article)
                    if not data or not selected_data:
                        continue
                    source, raw, index = data
                    chosen, _, chosen_index = selected_data
                    if (
                        canonical
                        and source["taxonomy"]["country_codes"]
                        != article["country_codes"]
                    ):
                        fail(
                            "wrong_canonical_country",
                            article_id=aid,
                            source_id=source["source_id"],
                        )
                    same_scope = (
                        source["language"] == chosen["language"]
                        and sorted(source["taxonomy"]["country_codes"])
                        == sorted(chosen["taxonomy"]["country_codes"])
                        and _program(source, canonical) == _program(chosen, canonical)
                        and _heading(source, index, article["title"])
                        == _heading(chosen, chosen_index, article["title"])
                        and _scope_markers(source) == _scope_markers(chosen)
                        and _context_key(source) == _context_key(chosen)
                        and scope_paths[(source["source_id"], source["snapshot_id"])][
                            index
                        ]
                        == scope_paths[(chosen["source_id"], chosen["snapshot_id"])][
                            chosen_index
                        ]
                    )
                    if not same_scope:
                        fail(
                            "deduplication_crosses_source_scope",
                            article_id=aid,
                            source_id=source["source_id"],
                            block_index=index,
                        )
                    decision = omitted.get(key)
                    is_selected = all(
                        ref[k] == selected[k]
                        for k in ("source_id", "snapshot_id", "block_index")
                    )
                    if not is_selected and not decision:
                        fail(
                            "duplicate_removal_missing_decision",
                            article_id=aid,
                            source_id=source["source_id"],
                            block_index=index,
                        )
                    if is_selected and decision:
                        fail(
                            "selected_origin_marked_removed",
                            article_id=aid,
                            block_id=bid,
                        )
                    if raw == original:
                        if (
                            decision
                            and decision.get("equivalence_evidence", {}).get("kind")
                            != "exact"
                        ):
                            fail(
                                "exact_duplicate_evidence_misclassified",
                                article_id=aid,
                                source_id=source["source_id"],
                                block_index=index,
                            )
                        continue
                    evidence = (decision or {}).get("equivalence_evidence", {})
                    same_attributes = {k: v for k, v in raw.items() if k != "text"} == {
                        k: v for k, v in original.items() if k != "text"
                    }
                    tokens = _concepts(raw["text"])
                    if (
                        not decision
                        or decision.get("represented_block_id") != bid
                        or evidence.get("kind") != "semantic"
                        or evidence.get("policy_version")
                        != "RAD_CONTENT_PRECEDENCE_V4.1"
                        or evidence.get("rule")
                        != "ordered_concepts_with_explicit_phrase_equivalence"
                        or {
                            evidence.get("left_structure_sha256"),
                            evidence.get("right_structure_sha256"),
                        }
                        != {sha(raw), sha(original)}
                        or raw["type"] != "paragraph"
                        or original["type"] != "paragraph"
                        or not same_attributes
                        or not same_scope
                        or _medical(raw["text"]) is None
                        or _medical(original["text"]) is None
                        or len(tokens) < 4
                        or tokens != _concepts(original["text"])
                        or evidence.get("signature_sha256") != sha(tokens)
                    ):
                        fail(
                            "unjustified_semantic_removal",
                            article_id=aid,
                            source_id=source["source_id"],
                            block_index=index,
                        )
                eligible_publishers = {
                    r.get(
                        "publisher",
                        variants.get((r["source_id"], r["snapshot_id"]), {}).get(
                            "domain"
                        ),
                    )
                    for r in block["provenance"]
                }
                if (
                    preferred in eligible_publishers
                    and selected.get(
                        "publisher",
                        selected_data[0]["domain"] if selected_data else None,
                    )
                    != preferred
                ):
                    fail(
                        "passage_source_precedence_violated",
                        article_id=aid,
                        block_id=bid,
                    )
        for key, omission in omitted.items():
            target = blocks.get(omission.get("represented_block_id"))
            if target is None or refs.get(key) != target["id"]:
                fail(
                    "dedup_target_missing_or_unlinked",
                    article_id=aid,
                    source_id=key[0],
                    block_index=key[2],
                )
            if omission.get("equivalence_evidence", {}).get("kind") == "semantic":
                semantic_count += 1
            else:
                exact_count += 1
        ledger_keys = set()
        for row in article.get("segment_ledger", []):
            key = (row["source_id"], row["snapshot_id"], row["block_index"])
            if key in ledger_keys:
                fail(
                    "duplicate_source_segment_ledger_row",
                    article_id=aid,
                    source_id=key[0],
                    block_index=key[2],
                )
            ledger_keys.add(key)
            if refs.get(key) != row.get("represented_block_id"):
                fail(
                    "ledger_target_missing_or_unlinked",
                    article_id=aid,
                    source_id=key[0],
                    block_index=key[2],
                )
        if ledger_keys != set(refs):
            fail("provenance_and_segment_ledger_differ", article_id=aid)
        if {key[0] for key in refs} != set(article["source_ids"]):
            fail("declared_sources_differ_from_actual_provenance", article_id=aid)
        article_blocks[identity] = blocks
    missing = [
        {"source_id": s, "snapshot_id": snap, "block_index": i}
        for s, snap, i in sorted(expected - covered)
    ]
    if missing:
        fail("eligible_source_segments_missing", count=len(missing))
    if covered - expected:
        fail("ineligible_source_segments_composed", count=len(covered - expected))
    render_errors, route_count = [], 0
    if route_receipts is not None:
        by_route = {(r["article_id"], r["locale"]): r for r in route_receipts}
        for identity, blocks in article_blocks.items():
            receipt = by_route.get(identity)
            hashes = {b: sha(v["original_structure"]) for b, v in blocks.items()}
            if (
                not receipt
                or receipt.get("rendered_structure_hashes") != hashes
                or receipt.get("admin_authorized") is not True
                or not receipt.get("revision_id")
                or not receipt.get("route")
                or receipt.get("body_render_verified") is not True
            ):
                render_errors.append(
                    {
                        "article_id": identity[0],
                        "locale": identity[1],
                        "code": "render_receipt_missing_or_incomplete",
                    }
                )
            else:
                route_count += 1
    summary = {
        "status": "FAIL" if errors else "PASS",
        "composition_status": "FAIL" if errors else "PASS",
        "source_snapshot_variants": len(variants),
        "eligible_source_segments": len(expected),
        "source_segments_accounted": len(expected & covered),
        "missing_source_segments": len(missing),
        "article_locales": len(seen_articles),
        "retained_destination_blocks": retained_count,
        "semantic_duplicate_representations": semantic_count,
        "exact_duplicate_representations": exact_count,
        "prior_identity_mappings": len(aliases),
        "verified_admin_render_routes": route_count,
        "application_status": "NOT_RUN"
        if route_receipts is None
        else "FAIL"
        if render_errors
        else "PASS",
        "application_errors": render_errors,
        "errors": errors,
        "hosted_write_claim": False,
        "publication_allowed": False,
    }
    if errors:
        raise AuditFailure(summary, missing)
    return summary


def _read(path):
    opener = gzip.open if path.suffix == ".gz" else open
    with opener(path, "rt", encoding="utf-8") as stream:
        return [json.loads(line) for line in stream if line.strip()]


def verify_directory(directory):
    manifest = json.loads((directory / "manifest.json").read_text(encoding="utf-8"))
    for name, expected in manifest["files"].items():
        path = (directory / name).resolve()
        if (
            not path.is_relative_to(directory.resolve())
            or hashlib.sha256(path.read_bytes()).hexdigest() != expected
        ):
            raise ValueError("manifest_path_or_checksum_mismatch:" + name)
    supplements = directory / "supplements.jsonl.gz"
    receipts = directory / "route-receipts.jsonl.gz"
    return audit(
        _read(directory / "sources.jsonl.gz"),
        _read(directory / "articles.jsonl.gz"),
        _read(supplements) if supplements.exists() else (),
        _read(receipts) if receipts.exists() else None,
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True)
    args = parser.parse_args()
    try:
        report = verify_directory(args.directory)
    except AuditFailure as error:
        (args.directory / "missing-source-segments.json").write_text(
            json.dumps(error.missing_segments, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        (args.directory / "independent-audit.json").write_text(
            json.dumps(error.report, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        raise
    (args.directory / "independent-audit.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(json.dumps(report, ensure_ascii=False))
