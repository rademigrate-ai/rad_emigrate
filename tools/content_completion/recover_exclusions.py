"""Explicitly recover substantive pages rejected by broad legal/FAQ/about filters."""

import copy

from tools.content_completion.recover_geography import make_draft, reference_capture

# source_id: (country links, retained independent block indices or None for
# main-only, [(country, Visa category, selected original indices)], rationale)
EXTRA = {
    "123697ad-33c1-55e7-bafd-c6afda0bc2b3": (
        ["CA"],
        list(range(63)),
        [],
        "Ontario is explicitly identified as a Canadian province in the original opening paragraph; its background article remains independent.",
    ),
    "a3bb3b04-7433-54b7-8dbf-f400f386462e": (
        [],
        list(range(6)),
        [],
        "General European migration and asylum discussion; no arbitrary single-country Visa assignment.",
    ),
    "b0bf13a3-e51f-58f6-86e7-4f8667d909e9": (
        ["CA"],
        None,
        [("CA", "study", list(range(33)))],
        "Complete Canadian study-permit employment eligibility and exceptions belong to Canada Study, preserving dated source claims.",
    ),
    "aa9639b2-53f7-5fba-9789-02e681c3fe5b": (
        [],
        list(range(11)),
        [],
        "General admissions, costs and student-Visa evidence; source distinguishes requirements between countries.",
    ),
    "b024aeea-7c2c-5664-93cb-924b549c3553": (
        [],
        list(range(14)),
        [("DE", "family", [2, 3]), ("GB", "family", list(range(7, 13)))],
        "General Europe article remains country-neutral; only explicit Germany family and UK guardian passages contribute to those countries.",
    ),
    "9a312140-6273-5aaf-afe4-ab1ed4f901f9": (
        ["DK"],
        None,
        [("DK", "family", [0, 1] + list(range(4, 16))), ("DK", "work", [2, 3])],
        "Denmark accompanying-family conditions and documents stay distinct from the two employment-route paragraphs; contradictory parent eligibility claims remain visible.",
    ),
    "9550de35-ae09-50fd-adb3-3408cb3dd8b2": (
        ["DK"],
        None,
        [("DK", "study", list(range(11)))],
        "Despite a malformed original title, the full body explicitly describes Danish medical study, admission, language, tuition and living costs.",
    ),
    "d98c2400-0750-5869-ae2a-c532df7e341a": (
        [],
        list(range(17)),
        [],
        "General physician qualification recognition and destination selection; country examples do not justify copying this entire article into each country's work page.",
    ),
    "47e3e133-da41-5ee5-8bc5-b6c8a675ba8a": (
        [],
        list(range(4, 35)),
        [("OM", "investment", [23, 24]), ("ES", "study", [32, 33, 34])],
        "All FAQ answers are retained independently; only Oman company registration and Spain study answers have explicit Visa-category destinations. Search/security/pagination controls are excluded.",
    ),
    "ede8a756-b3b9-541c-aceb-a7c6a9f45d7a": (
        [],
        list(range(4, 25)),
        [],
        "Complete medical-migration FAQ answers; country examples remain general. Search/security/pagination controls are excluded.",
    ),
    "caa929e1-afeb-5a21-b4c0-96313b911b84": (
        [],
        list(range(3, 11)),
        [("GB", "study", [7, 8])],
        "Original English FAQ remains English; only its UK Student Visa answer contributes to UK Study. No translation is invented.",
    ),
}


def retain_blocks(draft, indices):
    result = copy.deepcopy(draft)
    selected = set(indices)
    result["sections"] = []
    for section in draft["sections"]:
        new = copy.deepcopy(section)
        new["blocks"] = [
            b for b in new["blocks"] if b["provenance"][0]["block_index"] in selected
        ]
        if new["blocks"]:
            result["sections"].append(new)
    result["segment_ledger"] = [
        r for r in result["segment_ledger"] if r["block_index"] in selected
    ]
    result["claims"] = [
        r for r in result["claims"] if r["provenance"]["block_index"] in selected
    ]
    return result


def recover(sources, caches):
    drafts, maps = [], []
    for sid, (countries, independent, contributions, rationale) in EXTRA.items():
        source = sources[sid]
        capture = reference_capture(source, caches)
        if capture is None:
            raise ValueError("original_reference_capture_required:" + sid)
        draft = make_draft(source)
        draft["country_codes"] = countries
        draft["recovery_placement"] = {
            "independent_indices": independent,
            "contributions": [
                {"country": country, "visa_category": route, "indices": indices}
                for country, route, indices in contributions
            ],
            "rationale": rationale,
        }
        # These metadata name source passages; they are not an official legal validation.
        draft["classification_source_evidence"] = {
            "source_id": sid,
            "body_sha256": source["body_sha256"],
            "opening_excerpt": source["body_text"][:300],
        }
        for contribution in draft["recovery_placement"]["contributions"]:
            contribution["program"] = {
                "b0bf13a3-e51f-58f6-86e7-4f8667d909e9": "student-employment",
                "9550de35-ae09-50fd-adb3-3408cb3dd8b2": "medical-study",
                "b024aeea-7c2c-5664-93cb-924b549c3553": "guardian"
                if contribution["country"] == "GB"
                else "extended-family-exception",
                "9a312140-6273-5aaf-afe4-ab1ed4f901f9": "work-dependent-family"
                if contribution["visa_category"] == "family"
                else "employment-routes",
            }.get(sid, "general")
        drafts.append(draft)
        maps.append(
            {
                "article_id": draft["article_id"],
                "locale": draft["locale"],
                "expected_revision": 1,
                "map": {
                    "capture_status": "complete",
                    "sources": [
                        {
                            key: capture[key]
                            for key in ("snapshot_id", "body_sha256", "raw_html_sha256")
                        }
                    ],
                    "links": capture["links"],
                    "media_reuse": "not_authorized",
                    "legal_verification": "not_inferred_from_links",
                },
            }
        )
    return drafts, maps
