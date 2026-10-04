# AI Finalization Edge Integration Manifest

No Edge Function is deployed by this branch.

## ai-orchestrator
Authenticate the caller server-side. Resolve User/Admin scope from trusted backend identity, never request JSON. Use existing `get_ai_runtime_chain` and provider/Vault abstractions. Enforce model scope before invocation. Bound attempts/timeouts; classify 429, timeout, network and 5xx; return sanitized failures. Record redacted Project 15 observability. Retrieved text is untrusted data and must remain separated from system/trusted context.

## research-sync
Require the existing worker/admin boundary. Read configured sources only. Enforce SSRF controls: allow HTTP(S), reject loopback/private/link-local/metadata destinations after DNS resolution, bound redirects/body size/time. Normalize snapshots, detect changes, collect evidence and create review candidates. Never publish Feed content.

## provider test / model discovery
Admin-only. Credentials remain in Vault and are dereferenced server-side. Never return credential values or raw sensitive provider responses. Discovery is provider-specific and optional; malformed/unsupported discovery is explicit. Newly discovered models default to disabled unless a later verified product policy says otherwise.

## Web Search
Use the existing `search_providers` abstraction when configured; do not hard-code a commercial provider. Keep provider credentials server-side. Persist/return URL, title, snippet, trust classification, published/updated time when available and retrieval time. Treat result text as untrusted.

## Required harness
Use fakes for provider generation, discovery, Web Search, knowledge retrieval, source fetch and clock. Test authentication/role denial, USER/ADMIN/BOTH scope, bounded fallback, timeout/429/5xx, SSRF destinations and redirects, prompt-boundary attacks, sanitized logging, no auto-publish and no secret material in responses.