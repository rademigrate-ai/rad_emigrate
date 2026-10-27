"""Original-block placements for historical student/work classification conflicts."""

from tools.content_completion.recover_geography import make_draft

PLANS = {
    "478f54a3-40f5-50ab-917b-3e2af0454363": (
        "NO",
        list(range(58)),
        [("study", list(range(34, 43)), "general")],
    ),
    "588dd6c7-b0d9-5369-89b1-aec4bea9c644": (
        "FR",
        list(range(11)),
        [("study", list(range(2, 8)), "general")],
    ),
    "d8b26ffb-1004-5aea-8fae-341b409d1aa6": (
        "GB",
        None,
        [("work", list(range(34)), "global-talent-research-and-academia")],
    ),
    "98706b3a-20ff-5ad9-9c0d-20f15ed1639b": (
        "CA",
        None,
        [("study", list(range(45)), "post-graduation-work")],
    ),
    "a6d1b908-117f-50f1-9db5-b47101ddb15a": (
        "AT",
        list(range(30)),
        [("study", list(range(16)), "study-context")],
    ),
    "1c8ba83b-708d-58a9-b351-d2a010cacefc": (
        "DE",
        None,
        [("study", list(range(15)), "student-employment")],
    ),
    "5dbe43ff-efe7-57e1-bb38-bc93771f3ee8": (
        "GB",
        None,
        [("study", list(range(14)), "student-employment")],
    ),
    "603faba9-d057-5a7d-9289-f9eac728d7e0": (
        "AU",
        None,
        [("study", list(range(16)), "student-employment")],
    ),
    "5347d1c0-a84d-507a-921d-2ae902a83e29": (
        "AU",
        None,
        [("study", list(range(26)), "student-employment")],
    ),
    "953ba4c7-7cfb-5aa9-bf5b-a2092793be3c": (
        "DE",
        None,
        [("study", list(range(17)), "post-graduation-work")],
    ),
    "eac20177-ecc4-53f1-b9af-90b6c2b0b346": (
        "GB",
        None,
        [("study", list(range(21)), "student-employment")],
    ),
    "58cb5387-7d65-517f-8988-deb03b5f2b5a": (
        "NZ",
        None,
        [
            ("work", list(range(7)) + [11, 12, 13], "nursing-and-post-study-work"),
            ("study", [7, 8, 9, 10], "study-to-work-course-selection"),
        ],
    ),
}


def contributions(sources, source_references):
    drafts, maps = [], []
    for sid, (country, independent, groups) in PLANS.items():
        source = sources[sid]
        if source["domain"] == "radmohajer.ir" or source["taxonomy"][
            "country_codes"
        ] != [country]:
            raise ValueError("historical_source_scope_conflict:" + sid)
        draft = make_draft(source)
        draft["recovery_placement"] = {
            "independent_indices": independent,
            "contributions": [
                {
                    "country": country,
                    "visa_category": route,
                    "indices": indices,
                    "program": program,
                }
                for route, indices, program in groups
            ],
            "rationale": "Source concerns rights during/after study or the explicitly separated nursing pathway. Visa-specific sections join the continuous category page; source facts and dated claims remain unverified.",
            "historical_existing_source": True,
        }
        capture = source_references[sid]
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
