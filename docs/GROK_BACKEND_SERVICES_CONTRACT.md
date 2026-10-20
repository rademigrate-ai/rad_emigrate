# Grok Backend Services — Integration Contract
**Branch:** feat/rad-backend-services-final
**Base:** 839c749

## Edge Functions (Grok ownership)

| Function | Role |
|----------|------|
| ai-orchestrator | Text-only AI; quota; verified-official grounding |
| research-sync | Allowlisted fetch; SSRF-safe; ingest_research_snapshot |
| official-source-worker | Purpose-scoped official retrieval jobs |
| currency-refresh | Frankfurter primary; Fawazahmed0 fallback |
| notification-dispatch | Sandbox delivery; lease/idempotency |
| visa-content-ingest | Purpose-scoped CMS ingest worker |
| document-intelligence | Owner-bound OCR; human review required |
| payment-sandbox | Synthetic payment events only |

## Antigravity RPC surface (Codex DB + Grok Edge)

| RPC | Consumer |
|-----|----------|
| get_fx_quote | Flutter FxRepository |
| get_visa_article | CanonicalPathwayRepository |
| search_visa_articles | VisaSearchRepository |
| retrieve_verified_official_claims | ai-orchestrator only (service_role) |
| reserve_rad_ai_request / settle_rad_ai_request | ai-orchestrator |
| ingest_research_snapshot | research-sync |

## Hard rules
- No Feed auto-publish from research or AI
- Editorial approval ≠ factual verification
- No Bonbast; rates are provider_reference only
- No microphone/camera/audio/image AI capabilities
- Findings → review candidates via DB RPC, not Edge insert to feed_items
