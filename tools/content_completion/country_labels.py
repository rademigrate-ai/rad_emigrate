"""Source-supported destination names, without changing the sealed taxonomy."""

from tools.plan3_content.taxonomy import COUNTRIES as SEALED_COUNTRIES

COUNTRIES = {
    **SEALED_COUNTRIES,
    "KW": ["کویت", "Kuwait"],
    "ID": ["اندونزی", "Indonesia"],
    "SI": ["اسلوونی", "Slovenia"],
    "EC": ["اکوادور", "Ecuador"],
    "BY": ["بلاروس", "Belarus"],
    "LK": ["سریلانکا", "Sri Lanka"],
    "MX": ["مکزیک", "Mexico"],
}
