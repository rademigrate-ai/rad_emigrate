# Self-hosted image security — verified advisory triage (NO-GO)

Scope: immutable `deploy/self-hosted/images.lock.json` and the original
`RAD_IMAGE_SECURITY_EVIDENCE_20261105.zip` from the 2026-11-05 independent
delivery attestation. This is not a security certification, reachability
determination or production rollout approval.

## Evidence-validated findings

`scripts/triage_image_security.py` verifies the lock digest, every included
SARIF file hash, per-image severity totals and unique advisory totals.
It also emits **one unresolved record per advisory/package match**, including
the affected package URL and advertised fixed-version hint; all records
explicitly remain reachability NOT_ASSESSED and security acceptance NOT_GRANTED.
The generated local review receipt is
`D:/RAD - Emigrate/_audit/RAD_IMAGE_SECURITY_TRIAGE_375_DETAIL_20261105.json`
(375 individual records, not a code or image upgrade).
A tampered scan or lock fails closed; it does not silently discard findings.

| Image | Critical | High | Critical matches with a fixed-version hint | High with hint |
| --- | ---: | ---: | ---: | ---: |
| Postgres | 24 | 77 | 24 | 77 |
| Supavisor | 11 | 78 | 8 | 32 |
| Postgres Meta | 9 | 46 | 9 | 39 |
| Edge Runtime | 6 | 18 | 6 | 11 |
| Studio | 6 | 46 | 6 | 33 |
| Auth / GoTrue | 5 | 28 | 5 | 27 |
| Mailpit (disposable testing only) | 3 | 16 | 3 | 15 |
| Envoy gateway | 0 | 2 | 0 | 2 |
| PostgREST | 0 | 0 | 0 | 0 |
| **Totals** | **64** | **311** | **61** | **236** |

Matches overlap across images and packages; there are 244 distinct advisory
IDs. Fixed-version **hints on packages** do not establish an available,
compatible, patched and tested Docker image. No CVE is automatically waived
based only on a package being internal or the fix hint. Unknown reachability
remains **NOT_ASSESSED**.

**Incomplete:** imgproxy, Realtime and Storage API have no accepted image
scan report. Attempting Docker Scout against their locally cached immutable
images returned authentication/SSO-required without a SARIF report, not a
clean result. A second independent scanner with verified advisory database,
or authorized Docker Scout authentication, is needed before release.

## Required remediation in order

1. Obtain complete digest-specific scans for all 12 images, including the
   three missing ones. Record scanner version, advisory DB timestamp, source
   image digest, the exact findings and immutable result hashes.
2. For Critical and High findings, determine actual component exposure and
   vulnerable-code reachability using vendor advisories, package use, exploit
   prerequisites, deployment configuration and tested mitigations. Record a
   defensible decision *per advisory*, not a blanket severity exception.
3. Select compatible patched upstream image releases where available.
   Supabase recommends updating **coordinated self-hosted snapshots**;
   overriding an individual image tag can break schema or service contracts.
   Do not replace a digest with a tag or claim compatibility from a version
   number alone.
4. Re-pin the validated immutable digests, then rerun complete Docker scan,
   all migration/auth/storage/edge/RLS/integration tests, backup/restore and
   operator package hash binding on the exact revised image lock.
5. If unavoidable vulnerabilities have no compatible fix, require recorded
   owner/security acceptance backed by a *specific* non-exploitability or
   compensating-control assessment. Do not create a global allowlist.
6. Keep the release **NO-GO** while the missing scans or untriaged Critical/
   High findings remain. The test-only Mailpit image must not be mistaken
   for an approved production SMTP component.

No paid scanner subscription was provisioned. No image was upgraded or
deployed as part of this triage. See the original `image-security-review.json`
for the still-applicable NO-GO verdict and report SHA256 values.
