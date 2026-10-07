from url_normalize import normalize_url

def test_https_and_strip_www_and_tracking():
    assert normalize_url("http://www.radmohajer.ir/fa/?utm_source=x&id=1") == "https://radmohajer.ir/fa?id=1"

def test_trailing_slash():
    assert normalize_url("https://radmohajer.ir/fa/contacts/") == "https://radmohajer.ir/fa/contacts"

def test_fragment_dropped():
    assert normalize_url("https://radmohajer.ir/fa/#top") == "https://radmohajer.ir/fa"

if __name__ == "__main__":
    test_https_and_strip_www_and_tracking()
    test_trailing_slash()
    test_fragment_dropped()
    print("url_normalize OK")
