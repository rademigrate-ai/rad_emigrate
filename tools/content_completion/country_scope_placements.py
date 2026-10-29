"""Reviewed body evidence for previously country-neutral primary articles.

Each pin names an inspected original block. These are editorial proposals, not
geographic inference from a city name or claims of current immigration law.
"""

from tools.content_completion.country_labels import COUNTRIES
from tools.content_completion.recover_geography import make_draft
from tools.plan3_content.parser import digest

# source_id, country, original evidence block
PINS = """
dedaf94f-9871-580e-9575-bc5fb9ea9647 GB 3
0ae737c7-bb84-5400-ad77-9970f3aa21c1 NL 0
7ae83f5e-5ded-559d-bfcf-50dc773633b0 DE 1
d21d0aa5-8b97-5b4e-8b16-8bd116198e1a DE 0
29469f80-8b5a-5132-aa05-41b584649116 BE 0
9ef79503-3581-5cf1-af92-be066d2389e1 CA 0
7b7935bb-11a3-55be-b96c-fcdf460d788e NL 0
dc23f6f5-075a-59ca-a5bb-3beb136b7d59 CA 0
d569aa2a-4cdd-5916-b67d-35b7ad07d5e3 CA 0
97a029b2-13f9-539b-9d7d-86066ea2d7dd DE 0
f9b092c3-a209-503f-930b-2c7c430ac3b1 ES 0
e0c301b7-202c-50e4-b411-b1fd53964da1 CA 0
67b6a64a-81c7-5731-86e9-b2674bdfb3a0 US 0
fac3a69b-564e-568c-b262-0cb4154b674b CA 0
1b9664e1-062f-569a-abcf-219315cfe939 US 1
c5b655ae-1469-57d2-92a8-b94e931a344a DE 0
51da2da7-1419-5465-bdfa-4168f30bc7d5 GB 9
f954132e-6f38-56c6-8166-dc93f044f8f7 GB 6
01288380-43d1-524c-b891-51ffa0ee560a ES 0
6e293c5f-8ec4-5c71-aa10-a61eea0c3359 GB 1
36e82a63-3929-5fc4-979e-f5d9be262bcb FR 0
b8dccd3e-656d-59b3-9041-93c98a86e42b AT 0
cb13618a-2f03-524a-b471-ba5841275931 NL 0
79753fd3-6a94-5c3d-be7c-45e61f1aa3a1 DE 0
963e93d2-ac8b-5346-ab03-e5aff55c277c CA 0
710621f7-8f69-5908-895a-574346d9fb7b AU 0
5f662c06-464d-5936-875e-b631fab19966 DE 0
c2416c77-ddb1-52a6-ab55-f451187a1bf2 IT 0
d1e1acba-f6b0-5c5e-9ea2-bec0ccd5b26f AU 2
cd1e31df-b48e-5cc5-a3af-a7f21f4fffb7 CA 0
0be866de-f46c-5a3b-9f45-31885027a84d DE 0
07a423b6-dcbf-5a08-8800-23079963d16a AT 0
1d5e0cd4-44b9-5510-ae7e-b0db78de53e4 DK 0
5704c1cd-0d6a-5b58-a0ff-d10437c179f7 FR 0
1e810df7-120b-530e-a73a-e5e89680ec86 CA 0
d8b5e494-3ef4-5ec6-9a6c-b87c08e011fb GB 0
6ba608c6-71e1-546b-a535-1d7821b33182 AU 0
1b4564b5-656a-5955-8852-1427cba3eae9 ES 0
caf64db0-bb35-551a-a8e3-0400d89a4117 GB 0
4f69edc8-061d-5a90-b911-e91a26b10ef5 AU 0
9da21ae2-209f-5f0b-b372-c4f40258fcb2 GB 0
3d7223b4-2131-59c6-9769-005003a8f626 CY 0
c3abcd82-9873-59b4-8af9-2df584a7c9d2 ES 0
b88d7411-468e-55e5-ab8c-a416f69f1a7d FR 0
f92f04d9-116f-5969-b4b5-504e6b4f88c3 DE 0
29032bec-da36-5e1d-b828-df0d0223a672 GB 0
4d8f14a7-b102-5f39-9bac-785b91b6d46e GB 0
15fc9cf1-24d3-5c29-b261-42be5f10f1f4 CA 0
2e118466-5ae3-57be-a9d9-71d36221b038 DE 0
49673f4d-2f3c-599f-9856-090d9f30239a GB 0
689a8c9a-2766-5848-8b7f-d9238adb421c GB 0
2eaa6a51-0ae1-5963-96aa-0a10d29c6260 US 0
16c808b6-bc0b-50f3-ba5b-e3f244fb86dc US 0
e70364b5-fb9f-5f3f-b2d5-d62824b2f8af US 0
fe5fe85c-5132-5f25-9ff0-4881b26cffd9 ZA 0
45972ee4-0553-556e-8515-f9121f70195c DK 0
1def5422-fedd-5220-9d24-6d0a050f2bc3 CA 0
b98d2372-74ed-51fd-9028-775462cbf30e CA 0
58fccda5-32d0-5ce2-9cc9-7800250c14de CA 0
1b4d48bc-014f-5cc7-87b6-6d031156c8d3 CA 0
36b595e2-f242-5f55-b22d-d38e662539d3 TR 0
41e87a17-d628-58e9-b569-31e3432ed36c NL 0
8be02204-6a1f-5942-a243-807d9d1ec4bf DE 0
a7660bcf-2acd-539b-aa26-75dbf8c568e5 KW 2
e5e26f16-2c04-5e3a-abeb-128880ee3ff4 ID 1
6b2a7979-13fd-59ff-98eb-c7fba615263b SI 0
50029d97-7702-55d3-9112-831cc5e2fcf6 EC 0
19794c9e-4e57-567e-b7ea-a30cb4bffe8f BY 0
d32193d3-a067-55ff-9f75-8d120d97a11b LK 0
e95db69f-f0c2-5722-b9e9-444de1559456 MX 0
840270b2-4bbc-5b0c-a264-0a5b1c72d973 KW 1
e6ca083f-850d-546a-8898-3170d6fb2d5c DE 3
"""

# Inclusive original ranges. Complete document/language/degree requirements
# include nested h3/h4 headings; keyword-only heading matches would lose them.
# Institution history/rankings and general city material remain independent.
STUDY_RANGES = {
    "d21d0aa5-8b97-5b4e-8b16-8bd116198e1a": [(35, 47), (51, 60)],
    "9ef79503-3581-5cf1-af92-be066d2389e1": [(19, 27)],
    "7b7935bb-11a3-55be-b96c-fcdf460d788e": [(27, 37), (40, 43)],
    "d569aa2a-4cdd-5916-b67d-35b7ad07d5e3": [(10, 16)],
    "97a029b2-13f9-539b-9d7d-86066ea2d7dd": [(5, 8), (14, 15)],
    "f9b092c3-a209-503f-930b-2c7c430ac3b1": [(4, 17)],
    "e0c301b7-202c-50e4-b411-b1fd53964da1": [(10, 18)],
    "67b6a64a-81c7-5731-86e9-b2674bdfb3a0": [(16, 19)],
    "c5b655ae-1469-57d2-92a8-b94e931a344a": [(10, 17)],
    "51da2da7-1419-5465-bdfa-4168f30bc7d5": [(12, 17)],
    "b8dccd3e-656d-59b3-9041-93c98a86e42b": [(5, 8)],
    "4f69edc8-061d-5a90-b911-e91a26b10ef5": [(18, 21), (24, 25)],
    "3d7223b4-2131-59c6-9769-005003a8f626": [(13, 15), (22, 24)],
    "c3abcd82-9873-59b4-8af9-2df584a7c9d2": [(15, 20)],
    "f92f04d9-116f-5969-b4b5-504e6b4f88c3": [(14, 20)],
    "29032bec-da36-5e1d-b828-df0d0223a672": [(17, 19)],
    "4d8f14a7-b102-5f39-9bac-785b91b6d46e": [(5, 11)],
    "2e118466-5ae3-57be-a9d9-71d36221b038": [(9, 17)],
    "689a8c9a-2766-5848-8b7f-d9238adb421c": [(5, 7), (38, 45)],
}

FULL_ROUTES = {
    "e6ca083f-850d-546a-8898-3170d6fb2d5c": ("work", "job-seeker"),
    "1def5422-fedd-5220-9d24-6d0a050f2bc3": ("study", "quebec-caq"),
    "b98d2372-74ed-51fd-9028-775462cbf30e": ("work", "nova-scotia-physician-stream"),
    "1b4d48bc-014f-5cc7-87b6-6d031156c8d3": ("work", "nova-scotia-physician-stream"),
    "58fccda5-32d0-5ce2-9cc9-7800250c14de": ("work", "nova-scotia-streams"),
    "36b595e2-f242-5f55-b22d-d38e662539d3": ("work", "physician-dentist-recognition"),
    "41e87a17-d628-58e9-b569-31e3432ed36c": ("work", "physician-dentist-recognition"),
    "8be02204-6a1f-5942-a243-807d9d1ec4bf": (
        "work",
        "iran-trained-nursing-recognition",
    ),
    "e95db69f-f0c2-5722-b9e9-444de1559456": ("study", "study-permit-and-admissions"),
    "d32193d3-a067-55ff-9f75-8d120d97a11b": ("study", "medicine-university-specific"),
}

# Explicit route boundaries in broad country guides. The complete guides stay
# in Other Titles; only these substantive original passages join Visa pages.
MIXED_ROUTES = {
    "a7660bcf-2acd-539b-aa26-75dbf8c568e5": [
        ("work", 8, 14),
        ("study", 15, 18),
        ("investment", 19, 24),
    ],
    "e5e26f16-2c04-5e3a-abeb-128880ee3ff4": [
        ("investment", 4, 5),
        ("work", 6, 7),
        ("study", 8, 9),
        ("family", 10, 11),
    ],
    "6b2a7979-13fd-59ff-98eb-c7fba615263b": [
        ("study", 8, 10),
        ("investment", 11, 12),
        ("work", 13, 14),
        ("family", 15, 17),
    ],
    "50029d97-7702-55d3-9112-831cc5e2fcf6": [
        ("study", 8, 9),
        ("investment", 10, 12),
        ("tourist", 13, 13),
        ("family", 14, 15),
    ],
    "19794c9e-4e57-567e-b7ea-a30cb4bffe8f": [
        ("study", 9, 10),
        ("work", 11, 12),
        ("investment", 13, 14),
        ("family", 15, 18),
    ],
}


def country_proposals(sources, source_references):
    drafts, maps, evidence = [], [], []
    for line in PINS.strip().splitlines():
        sid, country, raw_index = line.split()
        source = sources[sid]
        index = int(raw_index)
        excerpt = source["blocks"][index]["text"]
        aliases = COUNTRIES[country] + (["انگلیس"] if country == "GB" else [])
        if (
            source["domain"] == "radmohajer.ir"
            or (
                source["taxonomy"]["country_codes"]
                and not (
                    sid == "8be02204-6a1f-5942-a243-807d9d1ec4bf"
                    and source["taxonomy"]["country_codes"] == ["DE", "IR"]
                )
            )
            or not any(a.casefold() in excerpt.casefold() for a in aliases)
        ):
            raise ValueError("country_evidence_conflict:" + sid)
        proof = {
            "source_id": sid,
            "country_code": country,
            "source_block_index": index,
            "excerpt": excerpt,
            "source_body_sha256": source["body_sha256"],
            "source_block_sha256": digest(source["blocks"][index]),
            "status": "source_bound_proposal_not_legal_verification",
        }
        if source["taxonomy"]["country_codes"]:
            draft = make_draft(source)
            draft["country_codes"] = [country]
        else:
            draft = make_draft(source, proof)
        groups = []
        for first, last in STUDY_RANGES.get(sid, []):
            groups.extend(range(first, last + 1))
        independent = list(range(len(source["blocks"])))
        route, program = "study", "institution-specific-admission"
        if sid == "49673f4d-2f3c-599f-9856-090d9f30239a":
            independent, groups, route, program = (
                None,
                list(range(len(source["blocks"]))),
                "work",
                "medicine-plab-recognition",
            )
        if sid == "9da21ae2-209f-5f0b-b372-c4f40258fcb2":
            independent, groups, program = (
                None,
                list(range(len(source["blocks"]))),
                "study-advantages-and-limitations",
            )
        if sid == "3d7223b4-2131-59c6-9769-005003a8f626":
            program = "northern-cyprus-institution-medicine"
        if sid in FULL_ROUTES:
            route, program = FULL_ROUTES[sid]
            independent, groups = None, list(range(len(source["blocks"])))
        contributions = (
            [
                {
                    "country": country,
                    "visa_category": route,
                    "indices": groups,
                    "program": program,
                }
            ]
            if groups
            else []
        )
        if sid in MIXED_ROUTES:
            contributions = [
                {
                    "country": country,
                    "visa_category": route,
                    "indices": list(range(first, last + 1)),
                    "program": "source-country-route",
                }
                for route, first, last in MIXED_ROUTES[sid]
            ]
        draft["recovery_placement"] = {
            "independent_indices": independent,
            "contributions": contributions,
            "rationale": "Original body explicitly establishes the country; retain the complete independent city/institution reader and contribute only inspected admission sections. Pure Visa-route sources join the canonical page with immutable history preserved.",
            "historical_existing_source": True,
            "country_scope_evidence": proof,
        }
        capture = source_references[sid]
        maps.append(
            {
                "article_id": draft["article_id"],
                "locale": draft["locale"],
                "map": {
                    "capture_status": "complete",
                    "sources": [
                        {
                            k: capture[k]
                            for k in ("snapshot_id", "body_sha256", "raw_html_sha256")
                        }
                    ],
                    "links": capture["links"],
                    "media_reuse": "not_authorized",
                    "legal_verification": "not_inferred_from_links",
                },
            }
        )
        drafts.append(draft)
        evidence.append(proof)
    return drafts, maps, evidence
