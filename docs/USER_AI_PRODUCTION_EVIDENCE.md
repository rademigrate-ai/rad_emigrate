# User AI Production Evidence — Stage 4 Final Acceptance

## Edge
- ai-orchestrator **version 8 ACTIVE**
- feed_items = 0 after authenticated smoke

## Authenticated production (not guest)
- Authenticated JWT → Edge v8 → identity → daily quota path → grounding → chain → provider
- EN: HTTP 200, inference, approved evidence, citations, request_id
- FA: HTTP 200, Persian reply, approved evidence, citations, request_id
- ai_requests: status=succeeded, user-bound, capability=chat
- RLS: users read own ai requests; service writes requests
- session_id FK guard + safe_error_code fix on branch (redeploy recommended)

## Guest (prior)
Q1-Q5 allow; Q6 anonymous_quota_exceeded

## Fallback fixture
supabase/tests/stage4_provider_fallback_fixture.py — executed PASS

## LIMIT 8 parity
Migration 20261007212000_stage4_limit_ai_runtime_chain.sql — repo and production both LIMIT 8

## Health audit
kiroai healthy after real success; openrouter offline+credential_rejected legitimate; no false healthy invalid credential

## Stage 3
OPEN / INCOMPLETE
