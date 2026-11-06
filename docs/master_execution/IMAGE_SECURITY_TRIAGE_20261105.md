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

**Original Docker Scout gap (supplemented):** Docker Scout could not
scan imgproxy, Realtime or Storage API because of authentication/SSO; this
historical limitation is retained. On the same locked local image digests,
portable **Trivy 0.76.1** (official Windows release SHA256 verified before
execution) downloaded its vulnerability DB and completed all three scans.
`scripts/verify_trivy_image_gap.py` verified all three source digests,
Trivy schema, dated JSON evidence and individual findings, writing
`D:/RAD - Emigrate/_audit/RAD_INDEPENDENT_TRIVY_GAP_RECEIPT_20261105.json`.

| Supplemental image (independent Trivy scanner) | Critical | High |
| --- | ---: | ---: |
| imgproxy | 0 | 33 |
| Realtime | 4 | 161 |
| Storage API | 1 | 69 |
| **Supplemental totals** | **5** | **263** |

The five new Critical package matches requiring urgent upstream/vendor review
(no reachability or compatible fix verified):

| Image | Advisory | Reported component | Upstream package fix hint |
| --- | --- | --- | --- |
| Realtime | CVE-2026-111497 | libbrotli1 1.1.0-2+b7 | 1.1.0-2+deb13u1 |
| Realtime | CVE-2026-13221 | perl-base 5.40.1-6 | 5.40.1-6+deb13u1 |
| Realtime | CVE-2026-42496 | perl-base 5.40.1-6 | 5.40.1-6+deb13u1 |
| Realtime | CVE-2026-8376 | perl-base 5.40.1-6 | 5.40.1-6+deb13u1 |
| Storage API | CVE-2026-59873 | tar 7.5.11 | 7.5.19 |

These are a different scanner's package findings and **must not be summed
with the 375 Docker Scout matches**. All 12 pinned images now have at least
one validated local scanner receipt, but they were not all scanned using the
same engine.

**Additional same-engine sweep:** All **11 locally cached pinned images** were
scanned and their exact immutable digests, Trivy JSON reports and file hashes
verified on the same Trivy 0.76.1 vulnerability database. Those 11 reports
contain **29 Critical** and **784 High** package-advisory matches. The
verification receipt is
`D:/RAD - Emigrate/_audit/RAD_TRIVY_11_DIGEST_RECEIPT_20261105.json`.
Supavisor 2.9.13 was not present locally, and an attempt to retrieve its
precisely pinned digest did not complete. The download was stopped without
changing running containers. Supavisor **is covered by the original Docker
Scout report**, but is missing from the uniform Trivy sweep. The 11-image
Trivy counts are not additive to the earlier nine-image Docker Scout counts,
nor directly representative of exploitable vulnerabilities. A uniform 12/12
comparison remains an explicit gap.

Critical/High remediation, live reachability and compatible
image upgrade verification remain incomplete. **NO-GO remains unchanged.**

## Required remediation in order

1. Retain the digest-specific receipts now present for all 12 images
   (nine Docker Scout, three independent Trivy). Preserve scanner version,
   advisory DB provenance/timestamp, digest, full findings and report hashes.
   Obtain a same-engine rescan of all 12 before making quantitative comparisons
   or clearing the release gate.
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
