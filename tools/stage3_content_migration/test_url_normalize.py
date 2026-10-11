from url_normalize import normalize_url

def test_https_and_strip_www_and_tracking():
    assert normalize_url("http://www.radmohajer.ir/fa/?utm_source=x&id=1") == "https://radmohajer.ir/fa?id=1"

def test_trailing_slash():
    assert normalize_url("https://radmohajer.ir/fa/contacts/") == "https://radmohajer.ir/fa/contacts"

def test_fragment_dropped():
    assert normalize_url("https://radmohajer.ir/fa/#top") == "https://radmohajer.ir/fa"

def test_port80_stripped():
    assert normalize_url("http://digivisa.ir:80/") in ("https://digivisa.ir", "https://digivisa.ir/")

def test_percent_encoded_persian_equals_raw_persian():
    raw = "https://radmohajer.ir/fa/component/content/article/181-انگلستان"
    encoded = "https://radmohajer.ir/fa/component/content/article/181-%D8%A7%D9%86%DA%AF%D9%84%D8%B3%D8%AA%D8%A7%D9%86"
    assert normalize_url(raw) == normalize_url(encoded)

def test_percent_encoding_case_insensitive():
    lower = "https://radmohajer.ir/fa/a%2fb"
    upper = "https://radmohajer.ir/fa/a%2Fb"
    assert normalize_url(lower) == normalize_url(upper)

def test_raw_space_percent_20_equivalence():
    assert normalize_url("https://radmohajer.ir/fa/a b") == normalize_url("https://radmohajer.ir/fa/a%20b")

def test_legacy_non_utf8_sequence_left_unchanged():
    # 0xE0 0xB6 is invalid UTF-8 (truncated Sinhala); must not be mangled.
    out = normalize_url("https://digivisa.ir/fa/%E0%B6")
    assert "%E0%B6" in out

if __name__ == "__main__":
    test_https_and_strip_www_and_tracking()
    test_trailing_slash()
    test_fragment_dropped()
    test_port80_stripped()
    test_percent_encoded_persian_equals_raw_persian()
    test_percent_encoding_case_insensitive()
    test_raw_space_percent_20_equivalence()
    test_legacy_non_utf8_sequence_left_unchanged()
    print("url_normalize OK")
