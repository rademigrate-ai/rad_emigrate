# Independent self-hosted operator runbook

This is a review and rehearsal procedure. PR #89 stays Draft; no purchase, external
deployment, merge, live publication, Production migration or paid AI call is authorized.
The operator package is not a declaration of employer acceptance.

## Reproduce the package

Use Python 3.11+, Docker Compose v2, Git and the exact reviewed RAD commit. Check out
the official Supabase `self-hosted/v0.8.3` revision
`bc27d2661edd09a5d0b8d76ce33da6d4071a756e` separately. Run:

```text
python scripts/build_self_host_delivery.py --upstream <official-checkout> --output <new-external-directory>
```

The builder refuses a dirty checkout, an existing output and output inside the
repository. `DELIVERY_MANIFEST.json` binds every packaged file to SHA-256 and the
RAD commit. Verify these hashes after transfer. `backend/docker-compose.pinned.json`
pins each upstream service to the reviewed amd64 image digest. Keep the upstream
release files together; bind mounts are relative to that directory. No live `.env`,
database, private media, Auth account, provider credential or snapshot is included.

## Rehearse on an isolated Linux machine

The supported automated installer deliberately creates only disposable, loopback
installations. Run it from the exact RAD checkout, with a new directory/project and
unused API port. It refuses an existing directory and refuses migration replay
onto an existing RAD schema. Never reuse a real data directory or project name.

```text
python scripts/self_host_stack.py prepare --root <new-root> --bundle <package>/backend --project rad-selfhost-uat-<unique> --port 58900
python scripts/self_host_stack.py pin --root <new-root> --image-lock <package>/deploy/self-hosted/images.lock.json
python scripts/self_host_stack.py start --root <new-root>
python scripts/self_host_stack.py migrate --root <new-root>
python scripts/self_host_stack.py status --root <new-root>
```

Require 120 applied migration entries (the original 119 plus owner conversation history) with matching file hashes, healthy services,
private `documents` bucket (10 MiB; PDF/JPEG/PNG), RLS and the real API suites.
Auth and Storage initialize their official schemas before RAD migrations run.
Preparation also applies the reviewed Storage response no-store header and writes
`STORAGE_GATEWAY_PRIVACY.json`. Confirm its template hash and the real signed-GET
header; upload metadata alone was insufficient on the pinned release. This policy
currently covers every Storage response. Gateway access logs retain status/timing
only, with no URLs, query strings, client addresses or freeform request headers.
The pinned Storage logger exposes private paths and signed query tokens even on
errors, so preparation sets its LOG_LEVEL=silent and disables external Logflare
and tracing. This sacrifices raw Storage request diagnostics; retain the sanitized
gateway counters, service health and persistent classified worker queue instead.
Do not re-enable raw request logging for real private traffic. Run
verify_self_host_log_privacy.py for actual success/error log evidence.
Review any future public-media caching
exception separately; keep private document responses no-store.
Do not substitute an empty PostgreSQL instance without those foundations.
Execute all `supabase/tests/*.sql` before adding runtime fixtures. Tests roll back;
several assert clean fixture counts. Then set `RAD_SELF_HOST_TEST_ROOT` privately
and run Auth isolation, document deletion (with `RAD_SELF_HOST_TEST_DISPATCHER=1`),
Storage gates, mailbox recovery, OTP sessions, natural token expiry, named appointment RPC acceptance and Research/CMS persistence scripts.
These scripts intentionally refuse hosted targets. Do not relax their checks to
test a deployed Production service.

## Production configuration review, before any deployment authorization

Choose the API and web hostnames, release scope, signup policy, operator, capacity,
SMTP provider, backup RPO/RTO, alert destination and first administrator. Review
upstream `.env.example` as a variable inventory; replace every example secret.
Generate independent passwords/JWT/Vault keys on the destination and store them in
a secret manager and a mode-0600 file outside source control. Realtime's pinned
encryption key is exactly 16 bytes. Preserve matching credentials with each backup.
Never reuse a disposable installation's keys or copy its users/data into Production.

Use a non-root operator account. Docker access itself grants host-level authority;
restrict membership accordingly. Publish only HTTPS through a reviewed reverse
proxy. Keep PostgreSQL, Storage, PostgREST, Edge runtime, metadata, pooler and
gateway internals on the private Docker network. Bind the gateway to loopback.
Allow SSH only from the operator network and public TCP 80/443; allow no database
or Docker daemon port. Remove Studio and Mailpit from the production model.

Configure real SMTP with TLS and provider-approved sender, credentials and limits.
Keep email auto-confirm disabled. Set `SITE_URL`, `SUPABASE_PUBLIC_URL`,
`API_EXTERNAL_URL` and a narrow redirect allowlist to the approved HTTPS origins;
verify the pinned Auth release's recovery callback paths through an actual mailbox.
Do not use wildcard redirects or the test mail sink for real people.

The included Caddyfile is a template. Validate the reviewed proxy configuration,
DNS A/AAAA records, certificate renewal and WebSocket forwarding in operator UAT.
Do not put authenticated Storage responses or signed URLs behind a shared cache.
Test preview expiry, pending replay, physical deletion and cache behavior through
the actual proxy; loopback acceptance does not certify a future CDN.

## First administrator and worker activation

Create the named initial administrator through normal Auth signup/confirmation.
Verify that identity out of band, then use a restricted database operator session
to promote only that exact profile UUID. Check `current_user`, UUID/email and role
before the transaction; record an approval and audit receipt without credentials.
The existing audited role trigger requires the trusted service bootstrap role;
an ordinary client or an unclassified SQL session cannot promote a profile. Use
the approved restricted server bootstrap path, then verify normal admin login.
Never promote all users, infer privilege from editable Auth metadata or ship a
bootstrap account/password. Verify an ordinary user cannot open `/admin` or invoke
admin RPCs, then log in normally as the administrator.

See `DOCUMENT_WORKER_OPERATIONS.md`. The bounded dispatcher is opt-in and server
only. Health reporting is the default; `--execute` processes individually
authorized requests. Service credentials stay in the operator environment, never
Flutter, command arguments, reverse-proxy logs or client error text. Route queue
age, exhausted retries, HTTP failures and dispatcher exit 2 to the chosen alert
channel. Test a stopped Storage service and recovery before unattended activation.
No automatic retention purge is shipped or enabled. A lawful duration/clock,
preservation precedence and policy authority still need explicit decisions.

## Persistence, backup and restore

Persist PostgreSQL data/config and Storage volumes. Keep encrypted backups off
the host, with separately escrowed keys and image digests. The cold snapshot tool
stops only the explicitly owned disposable source, encrypts all three volumes and
configuration, then restores source service health in `finally`. It does not
provide PITR, scheduling, retention rotation or offsite delivery.

```text
python scripts/self_host_snapshot.py backup --root <source> --snapshot <new-external-snapshot> --key-file <independent-secret-file> --gpg <gpg-binary>
python scripts/self_host_stack.py prepare --root <new-restore-root> --bundle <package>/backend --project rad-selfhost-restore-<unique> --port 58800
python scripts/self_host_stack.py pin --root <new-restore-root> --image-lock <package>/deploy/self-hosted/images.lock.json
python scripts/self_host_snapshot.py restore --root <new-restore-root> --snapshot <snapshot> --key-file <independent-secret-file> --gpg <gpg-binary>
python scripts/self_host_stack.py start --root <new-restore-root>
```

Restore refuses any existing target containers/volumes, the source project and a
different PostgreSQL image. Do not migrate the restored target again. Verify the
ledger hashes, normal login, private object byte hash, persisted CMS draft and
immutable deletion receipt. Repeat after a complete restart. Physical restore
requires the same image and architecture. Production backup scheduling, encrypted
offsite copy, retention, restore privileges and on-host rehearsal remain operator
acceptance gates; these tools do not mutate managed Production.

## Web, Android and employer UAT

Flutter 3.47.6 is pinned. Set public `SUPABASE_URL`, the public anon key and
`APP_ENV` through a private build-input file; include no service/provider key.
Run `scripts/public_web_build.py --scope environment` with `BACKEND_KIND=self_hosted`
and `EXPECTED_SELF_HOST_ORIGIN`. Production requires HTTPS. Build with
`flutter build web --release --dart-define-from-file=<public-inputs>`, write
`version.json` with the full Git SHA and Flutter version, and make `404.html`
byte-identical to `index.html`. Run the artifact verifier before transfer. Serve
SPA deep links with index fallback. Treat a loopback test build as a test artifact.

Android debug build is a CI check. A signed store release requires the approved
application identity, signing key and authorized store account; placeholder
identity checks deliberately refuse release packaging. iOS also requires Xcode,
signing and a physical-device run. No signing credential is created here.

UAT uses synthetic accounts and explicitly authorized synthetic publication only:
signup/login/recovery, profile, consultation/admin visibility, applications,
documents including failure/retry, cross-user denials, AI session history,
Research evidence/proposal/human review/unpublished draft, logout/login recovery,
and explicit editorial publication. Record EN/FA, 390/768/1440 viewports, keyboard,
errors, deep links, refresh and device evidence against the exact artifact SHA.
No external AI output or employer content approval may be inferred from fixtures.

For upgrades, test a new pinned package on a restored disposable clone first;
compare schema/history and API behavior. Never run an unreviewed cluster dump or
blind migration push. Retain the previous web artifact for client rollback.
Database rollback means a separately rehearsed recovery/forward-compensation
procedure; do not run reverse DDL or silently revert migration history.
