"""Deterministic Stage 4 provider fallback fixture (no live credential mutation)."""
class ProviderError(Exception):
    def __init__(self, code: str):
        self.code = code

RETRYABLE = {
    "provider_unauthorized", "unsafe_base_url", "provider_rate_limited",
    "provider_unavailable", "provider_timeout", "provider_model_unavailable",
}

def run_chain(chain, call_fn, grounding_sources):
    attempt_log = []
    last_code = "provider_unreachable"
    messages_out = []
    quota_consumptions = 1
    for index, runtime in enumerate(chain):
        try:
            text = call_fn(runtime)
            attempt_log.append({"attempt": index + 1, "provider": runtime["slug"], "result": "success"})
            messages_out.append(text)
            return {
                "ok": True, "provider": runtime["slug"], "failover": len(attempt_log) > 1,
                "attempt_log": attempt_log, "sources": grounding_sources,
                "quota_consumptions": quota_consumptions, "assistant_messages": len(messages_out),
            }
        except ProviderError as e:
            last_code = e.code
            attempt_log.append({"attempt": index + 1, "provider": runtime["slug"], "result": "failure", "code": e.code})
            if e.code in RETRYABLE:
                continue
            break
    return {
        "ok": False, "code": last_code, "attempt_log": attempt_log, "sources": grounding_sources,
        "quota_consumptions": quota_consumptions, "assistant_messages": len(messages_out),
    }

def test_fallback():
    chain = [c for c in [
        {"slug": "provider_a", "enabled": True},
        {"slug": "provider_b", "enabled": True},
        {"slug": "provider_disabled", "enabled": False},
    ] if c["enabled"]]
    grounding = [{"url": "https://radmohajer.ir/", "title": "RAD"}]
    def call_fn(runtime):
        if runtime["slug"] == "provider_a":
            raise ProviderError("provider_timeout")
        return "ok from B"
    res = run_chain(chain, call_fn, grounding)
    assert res["ok"] and res["provider"] == "provider_b" and res["failover"]
    assert res["quota_consumptions"] == 1 and res["assistant_messages"] == 1
    assert res["sources"] == grounding
    res2 = run_chain(chain, lambda r: (_ for _ in ()).throw(ProviderError("provider_timeout")), grounding)
    assert not res2["ok"] and len(res2["attempt_log"]) == 2
    print("PASS stage4_provider_fallback_fixture")

if __name__ == "__main__":
    test_fallback()
