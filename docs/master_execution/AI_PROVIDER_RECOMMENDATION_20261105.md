# RAD Research Assistant — AI provider recommendation

**Status: AWAITING OWNER AUTHORIZATION. No credential has been created, requested, stored or
used. No paid AI call has been made. No provider account has been opened.**

Prepared 2026-11-05 against repo commit `f881734`, verified against the pristine self-hosted
clean install (Stack F, 118/118 migrations, `supabase/functions/ai-orchestrator/`).

---

## 1. Recommended provider and model

**Primary recommendation: Google Gemini Developer API, model `gemini-3.5-flash-lite`.**

Rationale, in the order that actually decided it:

1. **It has a real free tier.** Google currently lists `gemini-3.5-flash-lite` as free for both
   input and output on the Developer API. The first integration test can therefore cost nothing,
   which is the constraint you set. Anthropic and OpenAI have no free API tier.
2. **The adapter already exists and needs no code.** `protocol_detect.ts` detects
   `generativelanguage.googleapis.com` as the `gemini` adapter, and `handler_providers.ts`
   already sends `x-goog-api-key`. Provider onboarding is Base URL + API key only.
3. **It is positioned for exactly this workload** — Google describes the Flash-Lite line as
   "cost-efficient for high-volume agentic work", which matches research retrieval and
   evidence extraction rather than long-form reasoning.

**Fallback if quality proves insufficient: Anthropic `claude-haiku-5-5`** at $0.10/MTok input
and $0.50/MTok output — the cheapest paid option across both vendors, and also a
zero-code-change path (the `anthropic` adapter is already implemented).

**Not recommended for the first test:** any Pro/Opus/Fable tier model. At $2–$10/MTok input
they cost 20–100× the Haiku fallback for a capability the Research Assistant does not need yet.

> Caveat worth stating plainly: model availability moved recently. `gemini-2.5-flash`, which
> earlier RAD notes referenced, was retired on 2026-10-20 and is no longer in Google's current
> model list. Re-confirm the exact model ID at authorization time rather than trusting this
> document's ID blindly — the pricing pages are the authority, not this file.

---

## 2. Exact server-side configuration required

Nothing is set via environment variables or files. Configuration goes through one
already-deployed RPC, and the key lands in Supabase Vault — never in a table column, never in
a log, never in the repo.

**Call once, as a `super_admin` user, against the self-hosted stack:**

```sql
select public.configure_ai_provider(
  p_slug         => 'gemini',
  p_display_name => 'Google Gemini Developer API',
  p_adapter      => 'gemini',
  p_base_url     => 'https://generativelanguage.googleapis.com',
  p_api_key      => '<PASTE KEY HERE — never commit, never paste into chat>',
  p_enabled      => true,
  p_priority     => 100
);
```

**Models are then discovered, not hand-registered.** There is no "register this model slug"
call — the `ai-orchestrator` Edge function reads the provider's own model list and feeds it to
`public.ingest_ai_model_catalogue(p_provider_id uuid, p_credential_version bigint, p_models
jsonb)`, which populates `public.ai_models`. So once the provider above is configured and
enabled, trigger the catalogue sync and the available Gemini models appear on their own.

Only *after* a model row exists do you tune it, and it is addressed by uuid, not slug:

```sql
select public.set_ai_model_configuration(
  p_model_id          => '<uuid from public.ai_models>',
  p_enabled           => true,
  p_runtime_scope     => 'both',   -- 'user' | 'admin' | 'both'
  p_priority          => 100,      -- 0..10000
  p_max_output_tokens => 4096      -- 64..32768
);
```

This matters for the authorization decision: a free-tier key is enough to populate the
catalogue, because discovery uses the provider's read-only `/models` endpoint rather than a
billed completion call.

**What the platform enforces for you** (verified in source, not assumed):

| Control | Where | Effect |
| --- | --- | --- |
| `super_admin` role required | `configure_ai_provider` | Ordinary and anonymous callers are refused with `42501` |
| Key stored encrypted | `vault.create_secret` | Round-trip verified working as the function owner on self-hosted |
| HTTPS-only, port 443 only | `normalizeAndValidateBaseUrl` | Blocks `http://`, odd ports, SSRF pivots |
| Credentials in URL forbidden | same | `credentials_in_url_forbidden` |
| Redirects refused | `handler_providers.ts` | `redirect: "error"` |
| Key redacted from provider replies | `provider_response.ts` | API key and service key stripped before any reply is surfaced |
| Audit log records no secret | `configure_ai_provider` | Logs `credential_replaced` as a boolean only |
| Rotation resets health | same | `credential_version` increments; `credential_rejected` cleared |

---

## 3. Minimum estimated test cost

**On the recommended path: $0.00.** `gemini-3.5-flash-lite` is currently free-tier on the
Gemini Developer API, so a first integration test consumes free quota, not money. The real
constraint is rate limits (requests/minute and /day), not spend. Google no longer publishes a
complete free-tier matrix in its public docs — the live limits appear in AI Studio for the
specific project, so read them there at authorization time.

**If you choose the Anthropic fallback instead**, a realistic first integration test — roughly
20 research calls, ~4k input and ~1k output tokens each (80k in, 20k out total):

| | Tokens | Rate | Cost |
| --- | --- | --- | --- |
| Input | 80,000 | $0.10 / MTok | $0.008 |
| Output | 20,000 | $0.50 / MTok | $0.010 |
| **Total** | | | **≈ $0.02** |

Even a 10× larger test run stays under **$0.20**. The honest figure is that first-test cost is
negligible either way; the reason to still set a hard limit is to bound a runaway loop or a
misconfigured retry, not to control the expected spend.

---

## 4. Recommended hard spending limit

**$5.00 / month, set at the provider, before the key is ever used.**

That is ~250× the estimated first test on the paid fallback and $5 more than the free-tier path
needs, so it cannot throttle legitimate testing — but it caps the blast radius of a retry loop
at an amount not worth worrying about. Raise it deliberately, with its own decision, if and
when real usage justifies it.

Set it as a provider-side billing cap (a hard stop), not an alert. An alert notifies you after
the money is gone. Also keep RAD's own `consume_ai_daily_quota` / `reserve_rad_ai_request`
quota path enabled — its atomic reservation was verified on the clean install at 16 accepted /
50 rejected, so it already bounds per-user call volume independently of the provider cap.

---

## 5. Safe procedure for configuring the credential privately

**Never paste the key into this conversation, a commit, a file in the repo, a CI variable, an
issue, or a screenshot.** I do not need to see it to finish the integration, and asking for it
would be the wrong request.

1. **Create the key** in Google AI Studio under a project dedicated to RAD testing — not a
   project shared with anything else, so revocation has no collateral damage.
2. **Set the hard billing cap first**, before the key exists or at least before it is used.
   A cap added later does not retroactively bound anything.
3. **Scope and restrict** the key as far as the provider allows (API restrictions; IP
   restriction to the self-hosted host if you are testing from a fixed address).
4. **Enter it exactly once**, into the `configure_ai_provider` call above, run from the
   self-hosted stack's own `psql` or Studio session over loopback. Not over email, chat or a
   shared document. If you paste it into a terminal, clear that shell's history afterwards.
5. **Verify storage, not the value**: confirm `select count(*) from vault.secrets where
   name = 'ai_provider_gemini'` returns 1, and that `public.ai_providers` holds only a
   `secret_id` reference. Never `select decrypted_secret` outside a momentary check, and never
   into a file or log.
6. **Confirm it works without printing it**: the provider health row
   (`public.ai_provider_health`) moves off `status='unknown'`, and `credential_rejected` stays
   false. That is sufficient evidence of a good key.
7. **Rotate by re-running** the same RPC with a new key — `credential_version` increments and
   health state resets automatically. **Revoke** by deleting the key in the provider console;
   the stored secret alone then grants nothing.
8. **Keep it out of the self-hosted bundle.** `self_host_stack.py` already refuses a bundle
   containing a live `.env`, and install secrets live outside Git by design. Do not add the AI
   key to any `.env` — it belongs in Vault only.

---

## What this document does **not** establish

- No live provider call has been made, so **AI integration remains unverified**. Deterministic
  fixtures exercised the error-handling and provider-independent paths; they are fixtures and
  are not represented as live AI results.
- Ledger items 11, 12, 14 and 15 (provider health, model eligibility, grounded-answer and
  citation evaluation, AI observability/cost) stay **BLOCKED** until a real call is authorized.
- Model IDs and prices here were read from vendor pricing pages on 2026-11-05 and will drift.
  Re-confirm at authorization time.
