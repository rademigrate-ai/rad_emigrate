"""Versioned, conservative passage policy; never a claim of legal verification.

Only a bounded set of explicit linguistic equivalences can remove a paraphrase.
Unrecognised semantic overlap is retained. Similarity scores alone never prove
equivalence. Structured blocks require exact structure and text equality.
"""

import re
from functools import lru_cache

from tools.content_completion.country_labels import COUNTRIES
from tools.plan3_content.parser import digest, search_normalize

VERSION = "RAD_CONTENT_PRECEDENCE_V4.1"

# Profession names, salaries, professional recognition and medical admission
# deliberately do not establish a clinical subject.
CLINICAL = re.compile(
    r"تشخیص بیماری|درمان بیماری|درمان سرطان|عوارض جانبی|پاتوفیزیولوژی|"
    r"فارماکوکینتیک|فیزیولوژی|مکانیسم اثر|دوز دارو|دوز درمان|روش جراحی|"
    r"مراقبت بالینی|درمان بالینی|پروتکل درمان|تداخل دارو|منع مصرف|"
    r"\b(?:pathophysiology|pharmacokinetics|physiology|diagnosis|"
    r"contraindications?|drug interactions?|side effects?|"
    r"clinical treatment|clinical nursing|surgical technique|"
    r"treatment protocol|therapeutic dose|mechanism of action|"
    r"diagnostic criteria|adverse drug reactions|adverse reactions to drugs)\b"
)
GENERAL = re.compile(
    r"پذیرش|ویزای|مهاجرت|دانشگاه|شهریه|بورسیه|استخدام|حقوق پزشک|"
    r"حقوق پرستار|مجوز کار|معادل سازی|\b(?:admission|university|visa|"
    r"immigration|scholarship|employment|salary|salaries|licensing|tuition)\b"
)


def classify_passage(value):
    """Classify the block's assertions, never its parent article's title."""
    value = search_normalize(value).replace("\u200c", " ")
    clinical = bool(CLINICAL.search(value))
    general = bool(GENERAL.search(value))
    return (
        "mixed_uncertain"
        if clinical and general
        else ("specialist_medical" if clinical else "general")
    )


def preferred_publisher(value):
    category = classify_passage(value)
    if category == "mixed_uncertain":
        return None
    return "radvisa.com" if category == "specialist_medical" else "digivisa.ir"


def _noun(value):
    return re.sub(r"^(?:a|an|the)\s+", "", value.strip())


def semantic_signature(value):
    """Return ordered concepts and the applied finite equivalence rules.

    Keep predicates, negation, modifiers, numbers, jurisdictions and dates.
    Full-sentence active/passive templates keep subject and object distinct.
    This intentionally is not a bag-of-words or fuzzy-match classifier.
    """
    value = search_normalize(value).replace("\u200c", " ")
    value = value.strip(" .!؟?؛;")
    rules = []
    active = re.fullmatch(r"(.+?) must (?:provide|submit) (.+)", value)
    passive = re.fullmatch(r"(.+?) (?:is|are) required (?:from|of) (.+)", value)
    persian_active = re.fullmatch(r"متقاضیان باید (.+?) ارائه (?:دهند|کنند)", value)
    persian_passive = re.fullmatch(r"ارائه (.+?) برای متقاضیان الزامی است", value)
    if active:
        value = f"{_noun(active[1])} must provide {_noun(active[2])}"
        rules.append("applicant_document_requirement_active_passive_v1")
    elif passive:
        value = f"{_noun(passive[2])} must provide {_noun(passive[1])}"
        rules.append("applicant_document_requirement_active_passive_v1")
    elif persian_active or persian_passive:
        match = persian_active or persian_passive
        value = f"متقاضیان باید {match[1]} ارائه دهند"
        rules.append("persian_applicant_document_requirement_v1")
    replacements = (
        (r"\bpassport that is valid\b", "valid passport", "valid_passport_v1"),
        (
            r"\bcriteria for diagnosis\b",
            "diagnostic criteria",
            "diagnostic_criteria_v1",
        ),
        (
            r"\badverse reactions to drugs\b",
            "adverse drug reactions",
            "drug_reaction_v1",
        ),
    )
    for pattern, replacement, rule in replacements:
        value, count = re.subn(pattern, replacement, value)
        if count:
            rules.append(rule)
    # Internal punctuation remains scope-bearing. In particular decimal points,
    # dates, conjunctions and comma-separated conditions are not discarded.
    return tuple(value.split()), tuple(sorted(set(rules)))


def scope_key(source, heading, program):
    """Every comparable block must share language, country and section scope."""
    return (
        source["language"],
        tuple(sorted(source["taxonomy"]["country_codes"])),
        program,
        semantic_signature(heading)[0],
        source_scope_markers(source),
        title_context(source),
    )


def title_context(source):
    """Only plainly generic same-country route titles may share context.

    Any remaining audience, city, condition or program word keeps the complete
    source title scope. Unknown wording is preserved rather than approximated.
    """
    return _title_context(
        search_normalize(source["title"]).replace("\u200c", " "),
        tuple(sorted(source["taxonomy"]["country_codes"])),
    )


@lru_cache(maxsize=4096)
def _title_context(value, country_codes):
    route_words = {
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
    hits = [
        route
        for route, words in route_words.items()
        if any(
            re.search(r"(?<!\w)" + re.escape(word) + r"(?!\w)", value) for word in words
        )
    ]
    if len(hits) == 1:
        aliases = [
            alias
            for code in country_codes
            for alias in [code, *COUNTRIES.get(code, ())]
        ]
        removable = [
            *aliases,
            *route_words[hits[0]],
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
        remainder = value
        for word in sorted(set(removable), key=lambda word: (-len(word), word)):
            remainder = re.sub(
                r"(?<!\w)" + re.escape(search_normalize(word)) + r"(?!\w)",
                " ",
                remainder,
            )
        if not re.search(r"\w", remainder):
            return "generic_route", hits[0]
    return "specific_source_title", semantic_signature(value)[0]


def initial_heading(source, article_title):
    return (
        source["title"]
        if title_context(source)[0] == "specific_source_title"
        else article_title
    )


def source_scope_markers(source):
    """Preserve explicit title dates/conditions and machine effective dates."""
    title = search_normalize(source["title"])
    qualifiers = re.findall(
        r"(?<!\w)(?:without|with|except|exempt|temporary|permanent|بدون|موقت|دائم|استثنا)(?!\w).*$",
        title,
    )
    return (
        tuple(re.findall(r"\d+(?:[./-]\d+)*", title)),
        tuple(qualifiers),
        source.get("effective_date"),
    )


def equivalence(left, right):
    """Evidence for a safe removal, or None to preserve both originals."""
    if digest(left) == digest(right):
        return {"kind": "exact", "rule": "exact_structure_and_text_repetition"}
    if left.get("type") != "paragraph" or right.get("type") != "paragraph":
        return None
    # Links, inline formatting and every other captured attribute matter.
    left_extra = {k: v for k, v in left.items() if k != "text"}
    right_extra = {k: v for k, v in right.items() if k != "text"}
    if left_extra != right_extra:
        return None
    if "mixed_uncertain" in (
        classify_passage(left["text"]),
        classify_passage(right["text"]),
    ):
        return None
    a, ar = semantic_signature(left["text"])
    b, br = semantic_signature(right["text"])
    if a != b or len(a) < 4:
        return None
    return {
        "kind": "semantic",
        "rule": "ordered_concepts_with_explicit_phrase_equivalence",
        "linguistic_rules": sorted(set(ar + br)),
        "signature_sha256": digest(a),
        "left_structure_sha256": digest(left),
        "right_structure_sha256": digest(right),
        "policy_version": VERSION,
    }


def candidate_key(block):
    """Index safe candidates without quadratic comparison of the corpus."""
    if block.get("type") != "paragraph":
        return "exact", digest(block)
    return "paragraph", semantic_signature(block["text"])[0]
