# Maral Host sizing and independent delivery update - 2026-11-05

Current procedure: [SELF_HOSTED_OPERATOR_RUNBOOK.md](SELF_HOSTED_OPERATOR_RUNBOOK.md).
Build the commit-bound operator review package with `scripts/build_self_host_delivery.py`.
It contains pinned official Compose sources, all 120 RAD migrations (the original 119 plus conversation history), nine Edge Functions,
operator scripts, configuration/proxy templates and a file-hash manifest. No deployment,
hosting purchase, DNS change, merge or Production action is performed.

The [official FR-VPS-M2 plan page](https://maralhost.com/vps/ovh), checked 2026-11-05,
lists 6 CPU cores, 12 GiB RAM and 60 GiB NVMe storage, with customizable resources.
This is a published specification, not a reserved quote or a capacity guarantee.

Current package-based Stack Q independently installed 120/120 migrations and passed
53/53 SQL and 9/9 real API suites. Its encrypted 120-migration restore to an empty
independent target passed normal Auth, private-byte/CMS/receipt integrity and full
restart checks (backup90.002s; restore/start82.233s; ciphertext133,408,477 bytes).
The later resource snapshot measured935,558,382 bytes across11 containers, summed
reported CPU30.29%, database130,642,292 bytes, configuration66,968 and Storage41,099.
These are bounded synthetic Windows-host samples, not Linux capacity certification.
See FINAL_ENGINEERING_ACCEPTANCE_20261105.md and the final attestation for exact
source/CI/package binding and current NO-GO security/acceptance gates.

The historical current-task baseline on Stack J applied 119/119 migrations with matching hashes and passed 52/52 SQL
suites and all six real Auth/Storage/worker/Research-CMS API suites. It runs official
self-hosted/v0.8.3, revision `bc27d2661edd09a5d0b8d76ce33da6d4071a756e`,
with PostgreSQL 17.6 and digest-pinned amd64 images. Its small synthetic workload
sample measured 1,085,569,761 bytes of container memory (about 1.01 GiB), a summed
8.76% container CPU at the sample instant, 130,390,332 bytes in database data,
66,968 bytes in database configuration and 36,968 bytes in Storage data. These are
fixture footprints on a shared Windows Docker host; Linux production load is unmeasured.

Five password logins had median 263.379 ms and maximum 309.201 ms. Twenty owner-profile
reads with concurrency four had median 204.136 ms and p95 388.865 ms. Single tiny-PDF
upload/download samples were 141.389/77.739 ms; one actual Edge deletion/finalization
was 602.657 ms. Samples do not establish sustained throughput, an SLO or AI latency.
The private measurement receipts are `RAD_FINAL_ACCEPTANCE_J_20261105/performance.json`
and `resource_summary.json` outside Git.

**Provisional recommendation:** M2's memory/CPU specification is reasonable for an
operator UAT starting point, conditional on a Linux load test and an agreed SLO.
Prefer 100 GiB disk (80 GiB minimum planning allowance) and separate encrypted offsite
backups. The 60 GiB base disk must cover OS, images, WAL, growth and maintenance
headroom, not just the tiny fixture data measured here. The recommendation is a planning
judgment, not a measured production capacity requirement. Do not purchase a larger plan
without owner authorization.

Read the current operator runbook for secret setup, SMTP, TLS/DNS/firewall review,
first-admin bootstrap, dispatcher activation, backup/restore and employer UAT.
A snapshot drill is distinct from PITR, offsite delivery, an RPO/RTO commitment and
production-host restore acceptance. The final evidence report records the current
120-migration final drill separately from the earlier 118-migration drill below.

---

## Historical 118-migration baseline (superseded instructions)

The original report is retained below for provenance. Its counts, missing-feature
statements and source SHA are historical; use the update and current runbook above.

# RAD — Maral Host FR-VPS-M2 deployment package (DRAFT)

**Status: DOCUMENTATION ONLY. Hosting is NOT purchased. Nothing is deployed. No DNS, TLS,
account, or payment action has been taken. PR #89 remains unmerged.**

Prepared 2026-11-05 at repo commit `03b2067`. Target host FR-VPS-M2 is **provisional** per the
owner's own constraint and is not accepted as a final quote.

This package exists so that a deploy, when authorized, is a reviewed procedure rather than an
improvisation. It is deliberately not a one-click script.

---

## 1. What is actually proven to work

Established on a disposable, loopback-only self-hosted stack built from the pinned official
bundle (Stack F, repo commit `f881734` onward):

| Verified | Evidence |
| --- | --- |
| All 118 migrations apply to an empty PostgreSQL 17 database | `MIGRATION_RECEIPT.json`, ledger byte-identical to repo |
| Two-user Auth, login/logout, RLS across profile/application/document/OCR/consultation/entitlement | `scripts/verify_local_auth_isolation.py` |
| Storage ownership, cross-owner denial, failed cross-user delete | same |
| Atomic AI quota reservation under concurrency (16 accepted / 50 rejected) | same |
| Mailbox-verified password recovery with a real credential change | `scripts/verify_self_host_password_recovery.py` |
| Signed-URL expiry, no replay after expiry, MIME and size gate refusals, anonymous read denial | `scripts/verify_self_host_storage_gates.py` |
| Research proposal → persisted review → CMS draft → logout/login/reopen recovery | `scripts/verify_research_cms_persistence.py` |
| Vault credential encrypt/decrypt round-trip as the function owner | probe recorded in `AI_PROVIDER_RECOMMENDATION_20261105.md` |

**Not proven, and therefore not deployable as "done":** live AI provider integration (no paid
call authorized), Flutter client journeys against a self-hosted backend, OTP and deep-links,
document retention (the feature does not exist), PITR restore, load/SLO, iOS signing, payments.
See `docs/RAD_47_TASK_MASTER_LEDGER.md` — 19 of 47 items remain BLOCKED.

---

## 2. Sizing, from measurement rather than estimate

Measured on the migrated Stack F with 11 services running idle:

| | Measured | Configured limit |
| --- | --- | --- |
| Total resident memory | **~1.03 GiB** | ~5.2 GiB |
| Largest single service | realtime, 245 MiB | 512 MiB |
| PostgreSQL | 189 MiB | 1.17 GiB |

Reading this honestly: **idle footprint is ~1 GiB, but idle is not the number to size on.**
Concurrent users, Edge Function execution, Storage transfer, and PostgreSQL cache under real
query load all scale above this, and the configured limits (~5.2 GiB) reflect what the services
may legitimately claim under pressure.

- **FR-VPS-M2 at 12 GiB RAM is adequate** with meaningful headroom. RAM is not the risk.
- **Disk is the risk.** The earlier 60 GiB NVMe figure is tight once PostgreSQL data, WAL,
  Storage objects (documents bucket allows 10 MiB/file), container images (~15 GiB observed
  locally), and backups coexist. Carry forward the existing recommendation: **at least 80 GiB,
  prefer 100 GiB.** Verify at checkout; do not assume the quote.
- Studio (214 MiB) and the Mailpit test sink are **development conveniences**. Both should be
  omitted or firewalled in production — see §4.

---

## 3. Deployment prerequisites (owner actions, none performed)

1. **Decide and purchase hosting** — owner only. Confirm the disk size above before checkout.
2. **Domain and DNS** — a dedicated hostname for the API. Not yet chosen or registered.
3. **TLS** — the pinned bundle terminates HTTP on the gateway. Production needs real TLS in
   front of it (the bundle ships a Caddy compose overlay; a reverse proxy with automatic
   certificates is the lower-risk option). **Not configured.**
4. **Secrets** — generated per install, outside Git. `self_host_stack.py` refuses a bundle
   containing a live `.env` by design. Production secrets must be newly generated, never the
   disposable test values from any Stack A–F.
5. **SMTP** — a real transactional provider. The Mailpit sink is a test fixture and must not
   receive production mail.
6. **Backups** — see §5. This is the largest unresolved gap and gates the release.

---

## 4. Production hardening deltas from the test stack

The test stacks are deliberately *not* production-shaped. These differences are required, not
optional:

| Test stack | Production requirement |
| --- | --- |
| API bound to `127.0.0.1:<port>` | Bind behind a TLS reverse proxy; never expose the gateway port directly |
| `SITE_URL` / redirects on loopback | Real hostnames; `ADDITIONAL_REDIRECT_URLS` tightened to real client origins only |
| Studio exposed | Remove, or restrict to an administrative network/VPN — it is a full database UI |
| Mailpit sink | Replaced by real SMTP; sink removed entirely |
| `DISABLE_SIGNUP=false` | Reassess against the release's intended enrolment policy |
| `ENABLE_EMAIL_AUTOCONFIRM=false` | Keep false — recovery and confirmation flows depend on real mail |
| Disposable generated secrets | Freshly generated production secrets, stored in a secret manager |
| `supavisor` under a `pooler` profile | Enable connection pooling before real concurrency |
| No TLS, no WAF, no fail2ban | Add transport security and abuse controls at the edge |

Carry forward, do **not** remove when self-hosting: RLS, SECURITY DEFINER authorization, audit
logging, immutable content holds, human-only publication, and the no-Restore safety policy.
Those were application-level decisions, not managed-platform workarounds.

---

## 5. Backup and restore — drill passed, policy still missing

**A restore drill has now passed** — see
`SELF_HOSTED_RESTORE_DRILL_20261105.json`. An encrypted cold snapshot of a populated stack was
restored onto a *separate* empty target; the migration ledger md5, table and user counts and a
deliberately seeded marker row all came back identical, and all three verification suites
(Auth/RLS/Storage, Storage gates, mailbox recovery) pass against the restored instance. The
drill also surfaced and fixed a real defect: the tool handed Windows-style paths to a POSIX gpg
build, which failed — and the tool correctly refused the incomplete archive rather than
accepting it.

That materially de-risks recovery, but it is **not yet a production backup policy**. Two
constraints from the tool's own contract remain load-bearing for production planning:

- Snapshots are **physical** PostgreSQL copies, so a restore requires the *exact same image
  digest and CPU architecture*. Pin and record the image digest alongside every snapshot, or
  the backup may be unrestorable on a rebuilt host.
- The tool deliberately implements no scheduling, rotation, or offsite copy. Those need a
  separately reviewed operator wrapper — a snapshot command that only ever runs by hand is not
  a backup policy.

Still required before a production deploy is accepted, none of which the drill covered:

1. **An operator wrapper** providing scheduling, retention/rotation and an encrypted offsite
   copy, with the passphrase stored separately from the snapshots (the drill kept it outside
   both the install and snapshot directories; production needs a secret manager).
2. **A restore rehearsal on the production host itself**, since the drill ran on one machine —
   cross-hardware restore is untested.
3. **A decision on PITR.** Physical snapshots give recovery to the snapshot instant only. If
   the release needs point-in-time recovery, that is WAL archiving and a separate design, not
   this tool.
4. **Repeat the drill against the production image digest** whenever it changes; a snapshot is
   only restorable onto the same digest.

Until an operator wrapper and an on-host rehearsal exist, treat the deployment as having a
**proven mechanism but no operational recovery guarantee**, and do not migrate real user data
onto it.

---

## 6. Suggested deploy sequence (for review, not execution)

1. Provision the VPS; patch the OS; create a non-root deploy user; enable a host firewall
   allowing only SSH and 80/443.
2. Install Docker; do **not** run the stack as root.
3. Transfer the pinned bundle and `deploy/self-hosted/images.lock.json`; pin every image by
   digest (`self_host_stack.py pin --image-lock`). Digest pinning is why the stack is
   reproducible — keep it.
4. Generate production secrets; store them in a secret manager; set file permissions to `600`.
5. Start PostgreSQL, Auth and Storage **first** — `migrate` refuses to run before Auth and
   Storage schemas exist, by design.
6. Apply the 118 migrations; confirm the receipt reports `118` and the ledger hashes match the
   release commit byte-for-byte.
7. Bring up the remaining services; remove Studio and the mail sink.
8. Front with TLS; verify certificates and that the raw gateway port is unreachable externally.
9. Run the verification suites against the deployed instance (they take
   `RAD_SELF_HOST_TEST_ROOT`; adapt for a remote target — **they currently assume a loopback
   install and will need work for a remote host**).
10. Rehearse snapshot and restore **on this host**, against its own image digest, **before** any
    real data is loaded — the §5 drill proves the mechanism, not this machine.
11. Configure the AI provider per `AI_PROVIDER_RECOMMENDATION_20261105.md`, with its hard
    spending cap set first.

---

## 7. Explicit non-goals of this document

- It does not authorize a purchase, a deploy, a DNS change, or a merge.
- It does not certify the application as release-ready; 19 ledger items are still BLOCKED.
- It does not replace the restore drill, the live AI verification, or client UAT.
- Sizing figures are measured on an idle stack and are a floor, not a capacity plan.
