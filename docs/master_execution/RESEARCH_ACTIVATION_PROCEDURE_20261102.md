# Research activation operations — prepared, no hosted execution

Target `inshddthftkhcdosoqcn`. The final bundle is **`sealed-final/activation-package.json`**, logical SHA256 `f220cedfba811522f06ffbc31cdc3509d324a41f5540cc588a2f7cab91df43ed`; it seals 70 source/contract/config/gateway files. Earlier outputs are retained history; the final SQL files use pinned LF bytes and their manifest hashes match the actual files. Both worker and discovery flags default false. `sealed-final/SCHEDULER_REVIEW_ONLY.sql` and`sealed-final/STOP_REVIEW_ONLY.sql` unconditionally refuse execution. No paid search/AI call, deployment, Vault write, registry approval, scheduler change or hosted negative test has been run by this package.

## R1: disabled deployment only

After a current checkpoint/real isolated restore and exact forward-schema approval, authorize **only** the package SHA in `activation-package.json`, source hashes, and disabled deployment operation. First set both flags false with a private env file using the manifest's exact `secrets set --project-ref ... --env-file ...` command. Add a newly generated purpose token of 32–512 characters privately; use an approved secret store, not shell arguments/logs. Do not add search credentials. Confirm disabled configuration before deployment.

Deploy sealed source using the manifest's `functions deploy official-source-worker --project-ref inshddthftkhcdosoqcn --no-verify-jwt --use-api` command. This function authenticates server-to-server requests with `x-rad-official-source-token`; the handler checks it before any queue/database operation. `verify_jwt=false` is intentional so cron does not fail at the gateway before reaching the purpose-token check. It is not authorization for a public/user API. Other function authentication settings are unchanged.

Verify hosted disabled POST503 on both direct and `?dispatch=1` paths, GET405 and zero queue/lease mutations, using pre/post read-only observations. Source entrypoint tests locally prove default-disabled and wrong-token rejection, but do not prove the hosted gateway. Retain actual deployed hash/version and config proof. Leave flags false after R1.

## R2: bounded refresh activation

This is a separate owner authorization, naming exact registry identities/domain proofs/trust roots, approved source bindings, vetted pinned egress endpoint/build and secret references. The last observed Production registry had zero authority entities/proofs/roots, so 3 legacy research-source rows cannot satisfy these prerequisites. No trust identity/proof is auto-approved by a search result.

`authority-binding-review.template.json` lists the exact12 existing binding-RPC parameters and required authority/head/snapshot/marker receipts. `egress-acceptance.template.json` lists the endpoint, allowed hosts and infrastructure acceptance evidence. Both are deliberately blank and grant no RPC, deployment or fetch permission. Use current IDs and actual Admin authentication; a detached draft does not silently advance the head to make a binding possible.

After actual human approvals and egress/private-network denial acceptance, set `RAD_OFFICIAL_SOURCE_WORKER_ENABLED=true` while keeping `RAD_OFFICIAL_SOURCE_DISCOVERY_ENABLED=false`. Verify missing/wrong purpose token403 **before** queue access. Through an actual Admin account, enqueue one explicitly approved refresh job. Invoke one bounded dispatch, verify claim/lease, chunk continuation or safe failure, saved source snapshot/evidence and unverified draft output, with no publication. Record pre/post job states, failures and actual RPC/deployment hashes. No fabricated JWT/profile or direct approval shortcut is permitted.

Discovery remains disabled even if search keys already exist in the project. A queued discovery job closes with safe `discovery_unavailable`, verified0 and no provider request. Enabling discovery or spending on providers requires a new explicit budget authorization; “No paid calls” remains active.

## R3: scheduler and legacy jobs

Choose one proposed cadence:15min, 30min or hourly. The generated package currently proposes15min, **pending owner approval**. Bind the exact `SCHEDULER_REVIEW_ONLY.sql` hash. Store the matching purpose token privately in Vault as `rad_official_worker_purpose` through an approved parameter-bound operation, never literal token text in an audit SQL file. Require exactly one matching secret of valid length.

After R1/R2 acceptance, an approved operator reviews the unconditional guard and exact target before scheduling the single new job `rad-official-source-dispatch-v1`. It invokes only `?dispatch=1`, one bounded lease per run. It **does not enqueue recurring requests**; Admin remains responsible for explicitly enqueueing approved refresh work. Scheduling an empty queue is a no-op, not evidence of completed Research.

Inventory and retain `rad-daily-research-enqueue` and `rad-daily-research-worker`. They target the older public research queue/research-sync function. This package neither replaces nor disables them. A future migration of those jobs needs an explicit job-id/command-hash plan; do not invent compatibility or double-schedule the same workload. Do not log decrypted cron headers.

## R4: stop and recovery

Set the worker flag false first; keep discovery false. `sealed-final/STOP_REVIEW_ONLY.sql` supplies the separate refusing stop specification. For the **new** job only, it requires the recorded job ID/name/exact command hash/cadence and unschedules that exact ID in a transaction after a separately reviewed stop authorization. Abort on mismatch or an unknown pre-existing job. Verify disabled503/no new claims and retain queued jobs, leases, failures, captures, snapshots and unverified drafts. Do not truncate queues, reset databases, revoke unrelated tokens or delete legacy evidence. Retry follows database lease expiry and bound source/authority checks; it never fabricates success.

## Local checks completed by this task

Default-off discovery and safe lease closure are exercised with network denied. The actual entrypoint is loaded with absent/true activation flag and rejects invalid purpose tokens before database access; method/default-disabled paths are checked. The reviewed scheduler refuses before any hosted mutation, rejects unapproved cadence/SQL interpolation and refuses replacement of an existing named job. Source fingerprints detect drift. Hosted gateway, real authority approvals, approved egress/bindings and live operational acceptance remain separate owner-authorized operations.

References: [per-function gateway configuration](https://supabase.com/docs/guides/functions/function-configuration), [Vault-backed scheduling](https://supabase.com/docs/guides/functions/schedule-functions).
