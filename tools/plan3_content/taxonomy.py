"""Versioned editorial association rules. These do not verify legal claims."""

import re
from urllib.parse import unquote, urlsplit

from .parser import search_normalize

VERSION = "rad-plan3-taxonomy-1"
COUNTRIES = {
    "AU": ["استرالیا", "Australia"],
    "AT": ["اتریش", "Austria"],
    "CA": ["کانادا", "Canada"],
    "DE": ["آلمان", "Germany"],
    "GB": ["انگلستان", "بریتانیا", "United Kingdom", "UK"],
    "US": ["آمریکا", "امریکا", "ایالات متحده", "United States", "USA"],
    "SE": ["سوئد", "Sweden"],
    "NL": ["هلند", "Netherlands"],
    "DK": ["دانمارک", "Denmark"],
    "FR": ["فرانسه", "France"],
    "NO": ["نروژ", "Norway"],
    "FI": ["فنلاند", "Finland"],
    "IT": ["ایتالیا", "Italy"],
    "ES": ["اسپانیا", "Spain"],
    "PT": ["پرتغال", "Portugal"],
    "BE": ["بلژیک", "Belgium"],
    "CH": ["سوئیس", "سوییس", "Switzerland"],
    "IE": ["ایرلند", "Ireland"],
    "IS": ["ایسلند", "Iceland"],
    "PL": ["لهستان", "Poland"],
    "HU": ["مجارستان", "Hungary"],
    "CZ": ["چک", "Czechia", "Czech Republic"],
    "SK": ["اسلواکی", "Slovakia"],
    "RO": ["رومانی", "Romania"],
    "GR": ["یونان", "Greece"],
    "TR": ["ترکیه", "Turkey", "Türkiye"],
    "AM": ["ارمنستان", "Armenia"],
    "RU": ["روسیه", "Russia"],
    "UA": ["اوکراین", "Ukraine"],
    "CN": ["چین", "China"],
    "JP": ["ژاپن", "Japan"],
    "IN": ["هند", "India"],
    "MY": ["مالزی", "Malaysia"],
    "TH": ["تایلند", "Thailand"],
    "PH": ["فیلیپین", "Philippines"],
    "NZ": ["نیوزیلند", "نیوزلند", "New Zealand"],
    "AE": ["امارات", "دبی", "Dubai", "United Arab Emirates"],
    "OM": ["عمان", "Oman"],
    "QA": ["قطر", "Qatar"],
    "ZA": ["آفریقای جنوبی", "South Africa"],
    "GE": ["گرجستان", "Georgia"],
    "CY": ["قبرس", "Cyprus"],
    "LU": ["لوکزامبورگ", "Luxembourg"],
    "KR": ["کره جنوبی", "South Korea"],
    "SG": ["سنگاپور", "Singapore"],
    "BR": ["برزیل", "Brazil"],
    "AR": ["آرژانتین", "Argentina"],
    "MT": ["مالت", "Malta"],
    "HR": ["کرواسی", "Croatia"],
    "EE": ["استونی", "Estonia"],
    "LT": ["لیتوانی", "Lithuania"],
    "LV": ["لتونی", "Latvia"],
    "BG": ["بلغارستان", "Bulgaria"],
    "MD": ["مولداوی", "Moldova"],
    "IR": ["ایران", "Iran"],
}
PATHWAYS = (
    "study",
    "work",
    "investment",
    "tourist",
    "marriage",
    "medical-study",
    "medical-work",
    "credential-recognition",
    "residence",
    "general",
)


def matches(value, words):
    value = search_normalize(value.replace("-", " ").replace("_", " "))
    return any(
        re.search(r"(?<!\w)" + re.escape(search_normalize(w)) + r"(?!\w)", value)
        for w in words
    )


def classify(title: str, url: str) -> dict:
    path = unquote(urlsplit(url).path).replace("-", " ")
    title_countries = [
        code for code, words in COUNTRIES.items() if matches(title, words)
    ]
    path_countries = [code for code, words in COUNTRIES.items() if matches(path, words)]
    countries = title_countries or path_countries
    s = search_normalize(title + " " + path.rsplit("/", 1)[-1])
    medical = bool(
        re.search("پزشک|دندان|پرستار|داروساز|پیراپزشک|medical|dentist|nursing", s)
    )
    study = bool(
        re.search(
            "تحصیل|دانشگاه|دانشجو|پذیرش|بورسیه|آموزش|مدرسه|study|university|student|scholarship",
            s,
        )
    )
    work = bool(
        re.search(
            r"(?<!\w)(کار|کاری|شغل|استخدام|اسکیل|جاب|work|employment|skilled)(?!\w)", s
        )
    )
    if re.search("معادل|اعتبارسنج|credential|recognition|licens", s):
        pathway = "credential-recognition"
    elif medical and study:
        pathway = "medical-study"
    elif medical and work:
        pathway = "medical-work"
    elif study:
        pathway = "study"
    elif work:
        pathway = "work"
    elif re.search(
        "سرمایه|ثبت شرکت|خرید ملک|کارآفرین|استارتاپ|investment|investor|business", s
    ):
        pathway = "investment"
    elif re.search("توریست|گردشگر|بازدید|tourist|visitor|tourism", s):
        pathway = "tourist"
    elif re.search("ازدواج|همسر|نامزد|خانواده|marriage|spouse|family", s):
        pathway = "marriage"
    elif re.search("اقامت|residen", s):
        pathway = "residence"
    else:
        pathway = "general"
    if re.search("هزینه|زندگی|living|cost", s):
        topic = "living-costs"
    elif re.search("مدارک|مدرک|documents|checklist", s):
        topic = "documents"
    elif re.search("شرایط|eligibility|requirements", s):
        topic = "eligibility"
    elif re.search("دانشگاه|university", s):
        topic = "institution"
    elif re.search("بورسیه|scholarship", s):
        topic = "scholarships"
    elif medical:
        topic = "medical-profession"
    elif "/news/" in url:
        topic = "news"
    else:
        topic = "guide"
    leaf = unquote(urlsplit(url).path).lower()
    if leaf in ("/", "/fa", "/en"):
        page_type = "home"
    elif re.search(r"/(?:catnews|catcontent|catproduct|category|tags?)(?:/|$)", leaf):
        page_type = "category"
    elif re.search("contact|contacts|تماس", leaf):
        page_type = "contact"
    elif re.search("about|درباره", leaf):
        page_type = "organization"
    elif "/news/" in leaf:
        page_type = "news"
    elif re.search("privacy|terms|حریم|قوانین", leaf):
        page_type = "legal"
    else:
        page_type = "article"
    return {
        "country_codes": sorted(set(countries)),
        "country_code": countries[0] if len(countries) == 1 else None,
        "country_evidence": "source_title"
        if title_countries
        else "source_url"
        if path_countries
        else "unresolved",
        "pathway": pathway,
        "topic": topic,
        "page_type": page_type,
        "taxonomy_version": VERSION,
        "classification_status": "inferred_requires_editorial_review",
        "country_disagreement": bool(
            title_countries
            and path_countries
            and not set(title_countries).issubset(path_countries)
        ),
        "multiple_pathways_detected": medical and study and work,
    }
