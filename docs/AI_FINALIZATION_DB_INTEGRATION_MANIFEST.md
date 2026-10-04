# AI Finalization DB Integration Manifest

No migration SQL belongs in this prebuild. AI-01 starts only after migration-lineage reconciliation and must extend the Project 15 production state.

| Feature | Existing object to extend | Future DB requirement | Security | Test |
|---|---|---|---|---|
| Provider scope | `ai_providers` | scope metadata only if not already represented | admin/service only; credentials remain Vault refs | user/admin/both selection |
| Model scope/discovery | `ai_models` | scope, discovery status/last-seen only where absent | admin writes; clients cannot enable discovered models | discovery sync + RLS |
| Provider health | `ai_provider_health` | persist sanitized health/cooldown if absent | no raw provider response/secret | failure classification |
| Runtime fallback | `get_ai_runtime_chain` | extend return shape only if scope/health unavailable | backend-enforced scope | wrong-scope exclusion |
| Provider configuration | `configure_ai_provider` | extend existing RPC; never replace Vault abstraction | admin only; secret value never returned | privilege + redaction |
| User evidence | existing AI/research/knowledge structures | minimal citation/provenance fields if current schema cannot represent them | owner/read boundary | cross-user denial |
| Research source scope | existing research sources | USER/ADMIN/BOTH assignment if absent | admin mutation; user sees USER/BOTH only | scope RLS |
| Review candidates | existing research/review structures | extend state/provenance only where absent | admin-only mutation; no automatic publish | state transition tests |
| Feed handoff | existing Feed/notifications | explicit reviewed/published linkage if absent | human-authorized publish only | research cannot publish |
| Observability | existing Project 15 telemetry | sanitized AI attempt/fallback metadata if absent | privacy/redaction | secret/PII regression |

Before AI-01, inspect the reconciled live schema again and remove every requirement already supported. Never recreate AI, research, document, Feed, observability, Vault or role architecture.