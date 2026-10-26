"""Evidence-bound editorial proposals, never legal or publication approval.

Only explicit title/URL countries may establish destination scope. Unresolved
and comparative pages remain independent for human review, not guessed routes.
"""

import re

from tools.plan3_content.parser import search_normalize

VERSION = "country-category-v3"
LABELS = {
    "study": ("ویزای تحصیلی", "Study Visa"),
    "work": ("ویزای کار", "Work Visa"),
    "investment": ("سرمایه‌گذاری", "Investment"),
    "tourist": ("ویزای گردشگری", "Tourist Visa"),
    "family": ("خانواده و ازدواج", "Family and Marriage"),
}
ROUTES = {
    "family": r"ازدواج|همسر|نامزد|الحاق.*خانواده|family reunification|spouse|marriage",
    "investment": r"سرمایه|ثبت شرکت|خرید ملک|کارآفرین|استارتاپ|investment|investor|startup",
    "tourist": r"توریست|گردشگر|بازدید|tourist|visitor|tourism",
    "work": r"(?<!\w)(?:کار|کاری|شغل|استخدام|اسکیل|جاب|work|employment|skilled)(?!\w)",
    "study": r"تحصیل|دانشجو|پذیرش|بورسیه|مدرسه|study|student|scholarship|admission",
}
PROFESSIONS = {
    "nursing": r"پرستار|nurs",
    "dentistry": r"دندان|dentist",
    "pharmacy": r"داروساز|داروسازی|pharmac",
    "medicine": r"پزشک|medical|medicine",
}
DIRECT = r"ویزا|اجازه اقامت|مجوز تحصیل|پذیرش|شرایط ورود|مدارک.*(?:تحصیل|ثبت نام)|visa|admission|entry requirements|residence permit"


def program_scope(title):
    value = search_normalize(title)
    # A profession is scope-bearing. Other route identifiers remain explicit
    # editorial distinctions rather than being collapsed into a generic rule.
    for name, pattern in PROFESSIONS.items():
        if re.search(pattern, value):
            return name
    for name, pattern in {
        "job-seeker": r"جستجوی کار|جاب سیکر|job seeker",
        "blue-card": r"بلو کارت|کارت آبی|blue card",
        "startup": r"استارتاپ|startup",
        "self-employed": r"خود اشتغال|self.employ",
        "school": r"مدرسه|school",
        "doctoral": r"دکتری|دکترا|phd|doctoral",
    }.items():
        if re.search(pattern, value):
            return name
    return "general"


def source_mapping(source):
    title = search_normalize(source["title"])
    countries = source["taxonomy"]["country_codes"]
    route_hits = [key for key, pattern in ROUTES.items() if re.search(pattern, title)]
    profession = program_scope(title)
    if (
        not route_hits
        and profession in PROFESSIONS
        and re.search("مهاجرت|معادل|مجوز|recognition|migration", title)
    ):
        route_hits = ["work"]
    reason = "independent_nonvisa_material"
    independent = True
    route = None
    if source["domain"] == "radmohajer.ir":
        reason = "supplementary_publisher_remains_independent"
    elif len(countries) != 1 or source["taxonomy"].get("country_disagreement"):
        reason = "country_scope_requires_human_editorial_decision"
    elif len(route_hits) > 1:
        reason = "multiple_visa_categories_require_segment_review"
    elif route_hits:
        route = route_hits[0]
        # General university introductions remain independent. Relevant
        # admission/Visa sections are explicitly mapped below, not lost.
        institution = re.search("دانشگاه|کالج|university|college", title)
        if institution and not re.search(
            "ویزا|پذیرش|دانشجو|admission|visa|student", title
        ):
            reason = "institution_article_with_selective_admissions_contribution"
            route = "study"
        else:
            independent, reason = False, "explicit_country_and_visa_category"
    elif re.search("دانشگاه|کالج|university|college", title):
        route, reason = (
            "study",
            "institution_article_with_selective_admissions_contribution",
        )
    return {
        "mapping_version": VERSION,
        "country_codes": countries,
        "visa_category": route,
        "program": profession,
        "independent": independent,
        "reason": reason,
        "mapping_status": "proposed_requires_human_review",
        "country_evidence": source["taxonomy"]["country_evidence"],
    }


def relevant_segments(source, mapping):
    """Full main sources; explicitly scoped sections of independent sources.

    Partial contributions retain the COMPLETE section, not keyword sentences.
    Full independent articles remain available with every other segment intact.
    """
    if not mapping["independent"]:
        return list(range(len(source["blocks"])))
    if (
        source["domain"] == "radmohajer.ir"
        or len(mapping["country_codes"]) != 1
        or not mapping["visa_category"]
    ):
        return []
    selected, section = [], []

    def finish():
        if section and re.search(
            DIRECT,
            search_normalize(" ".join(source["blocks"][i]["text"] for i in section)),
        ):
            selected.extend(section)

    for i, block in enumerate(source["blocks"]):
        if block["type"] == "heading":
            finish()
            section = []
        section.append(i)
    finish()
    return selected
