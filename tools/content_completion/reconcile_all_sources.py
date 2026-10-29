"""Compatibility entry point for evidence-backed, offline source reconciliation.

Importing this module performs no filesystem reads/writes or reconciliation.
The old script inferred countries from substrings and treated every missing
extraction as an archive. Use the HTML-aware versioned builder instead.
"""

from tools.content_completion.phase_bundle import main
from tools.content_completion.source_evidence import country_evidence, original_url
from tools.plan3_content.parser import search_normalize


def normalize_url(value):
    return original_url(value) if value else ""


def get_country_from_url_or_title(url, title, body_text):
    evidence = country_evidence(title or "", url, body_text or "")
    codes = evidence["country_codes"]
    return (
        codes[0] if len(codes) == 1 and not evidence["human_review_required"] else None
    )


def is_pathway_themed(title, body_text):
    combined = search_normalize((title or "") + " " + (body_text or ""))
    return any(
        word in combined.split()
        for word in (
            "ویزا",
            "ویزای",
            "اقامت",
            "مهاجرت",
            "تحصیل",
            "تحصیلی",
            "کاری",
            "شنگن",
            "پناهندگی",
        )
    )


if __name__ == "__main__":
    main()
