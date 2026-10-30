# Protected Research transport and queue operations

31 October 2026. Code and isolated acceptance evidence only; not hosted activation.

The existing Research pipeline and human publication boundary are retained. `research-sync` uses `createResearchEgressFetch`; it returns HTTP 503 when secure transport is absent rather than fetching arbitrary sources directly. `official-source-worker?dispatch=1` claims one bounded chunk per invocation through the existing service-only lease RPC. Discovery uses configured Brave/Serper search and stores candidates only. A candidate is not a verified authority or approved evidence. Search failures close their lease as failed; an explicit new request is required. The exhausted-lease migration closes abandoned final attempts without blocking other queue workers.

Official refresh requires an Admin-created binding between an existing validated source document, current verified authority/domain proof, article/locale, rich block and unique source markers. No mappings are inferred or seeded automatically. The job freezes its target URLs, snapshot/revision IDs and verified prefixes. Each invocation handles one source, renews its live token-bound lease, preserves complete bounded raw captures and immutable normalized snapshots, and records durable progress even for no-op observations. A successful partial chunk yields HTTP 202/status queued; it is not counted as job success. Only the fully completed nonempty manifest may finish successfully. The additive `rad_worker_v2.json` chunk response describes queued progress; the sealed `rad_v1.json` registry is unchanged. Only the internal dispatcher uses this chunked worker; the legacy per-job endpoint retains its prior behavior.

Navigation-only changes retain evidence without a legal-change proposal. A changed bound fragment creates a verbatim, cited structured proposal in the existing Visa Research tables. Admin sees source and article languages, old/new fragments, snapshot IDs and hashes; the text is never silently translated. Accept/Edit/Reject uses the existing Stage7 review RPC. Acceptance creates an unverified draft and cannot publish it.

## Operator configuration

Run `python -m scripts.research_egress` on an operator-controlled host with Python 3.11 or later. It binds HTTP to `127.0.0.1:64980` only. Configure an approved HTTPS reverse proxy with authenticated access, request-size/rate limits and no response/body/header logging. Review the deployed host and proxy before activation; local unit tests cannot attest remote infrastructure.

Gateway environment:

- `RAD_RESEARCH_EGRESS_TOKEN`: dedicated random token, at least 32 characters; supply through the secret manager. Never use a Supabase service key or user JWT.
- `RAD_RESEARCH_EGRESS_HOSTS`: comma-separated exact hostnames approved for monitoring, after source-access/terms review. No wildcards, IP literals or implicit subdomains.
- `RAD_RESEARCH_EGRESS_PORT`: optional loopback port, default 64980.
- `RAD_RESEARCH_EGRESS_INTERVAL`: per-host interval, 1–30 seconds. Sources with larger robots crawl delays require a separate reviewed schedule/transport; do not bypass the refusal.

`research-sync` Edge environment: set the same dedicated token and `RAD_RESEARCH_EGRESS_URL=https://<approved-gateway>/fetch`. HTTPS configuration is mandatory. Caller credentials, cookies, database keys and user documents are never forwarded to source sites. The gateway permits public IPv4 only, checks all DNS answers, connects a numeric address, verifies TLS against the original hostname, enforces robots policy, and returns redirects for caller revalidation. A 15-second socket deadline follows bounded DNS resolution; response bodies are limited to 1 MB. PDFs, unsupported compression and unsupported media fail explicitly. The legacy snapshot contract also rejects normalized text above 100,000 characters; it does not truncate it.

Official worker environment: `RAD_OFFICIAL_SOURCE_WORKER_ENABLED=true`, dedicated `RAD_OFFICIAL_SOURCE_WORKER_TOKEN`, and the existing server-only Supabase connection credentials. Search needs `BRAVE_SEARCH_API_KEY` or `SERPER_API_KEY`; no free fallback is silently substituted. The owner has authorized **no paid calls**, so no provider acceptance purchase or paid request was performed.

Configure the existing scheduler to POST to `/functions/v1/official-source-worker?dispatch=1` with `x-rad-official-source-token` read from the operator secret store. Do not place tokens in SQL source, URLs or checked-in configuration. The handler's disabled/authentication checks precede queue access. No scheduler mutation or hosted worker deployment has been performed here.

## Required activation gates

1. Verify actual Production project ID, current backup/restore and reviewed forward schema; Production currently lacks required official queue/review RPCs.
2. Reconcile function/table dependencies and exact ACLs; new functions must not inherit public execution unintentionally.
3. Deploy the reviewed gateway and prove public-only routing, certificate verification, redirect/robots behavior, deadline and size limits against controlled fixtures.
4. Deploy the matching Edge source and set purpose secrets without exposing values. Verify unauthorized invocation denial and real scheduled consumption; queued jobs alone do not prove operation.
5. Verify authority identity, jurisdiction and evidence proof independently. Register explicit source/article/locale/section impact mappings with create_official_refresh_binding using a real authorized Admin session and an actual baseline snapshot. The binding RPC checks current proof/root expiry, country/topic, path scope, exact markers and rich anchor. Unconfigured transport or missing/unverified bindings fail closed. No real authority or mapping has been approved or created in Production by this execution.
6. Exercise highlighted Admin Accept/Edit/Reject, concurrency conflicts and new draft creation. Publishing remains separate human authorization. Research, search, AI and importers never publish Visa or Feed automatically.

## Evidence and limitations

Local transport and malformed HTTP header tests use no external source traffic. A bounded free live transport check fetched the [official Canada study-permit page](https://www.canada.ca/en/immigration-refugees-citizenship/services/study-canada/study-permit/eligibility.html) with HTTP 200, 29,734 bytes, SHA256 `a68a5c80f0e2de09672abad0df3f09fc75399e82c337fd6de02f843300330689`, respecting robots and pinning. The [Oxford course-fee page](https://www.ox.ac.uk/admissions/graduate/fees-and-funding/fees-and-other-charges/course-fees-and-fee-liability) check stopped at `robots_unavailable`; it was not bypassed. Raw evidence and timestamped receipts remain in the local `_audit/RAD_MASTER_EXECUTION_20261029/research-live/` folder. No legal claims were promoted, approved or published from these checks.

Do not describe this as continuously operational official research until configured hosted source refresh, impact mapping, proposal review, real scheduling and provider evidence all pass.
