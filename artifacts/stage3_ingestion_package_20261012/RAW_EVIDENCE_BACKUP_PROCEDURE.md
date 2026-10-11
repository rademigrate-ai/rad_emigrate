# Raw-Evidence Backup & Recovery Procedure (247 MB local store)

Status: **procedure prepared — NOT executed (no external upload authorized).**

## What is being protected

- Location: `artifacts/stage3_acquisition_20261011/raw/` (1,627 files,
  254,301,584 bytes)
- Integrity anchor:
  `artifacts/stage3_acquisition_20261011/manifests/RAW_EVIDENCE_SHA256_MANIFEST.json`
- Verification result (2026-10-12): **complete — 0 missing, 0 hash mismatches,
  0 unlisted extras** (`RAW_EVIDENCE_VERIFICATION.json`)
- Git policy: intentionally local-only (repository-suitability rule);
  committed derived datasets are rebuildable from these bodies.

## Pre-backup check (any machine)

```bash
python - <<'PY'
import hashlib, json, pathlib
root = pathlib.Path('artifacts/stage3_acquisition_20261011')
man = json.loads((root/'manifests/RAW_EVIDENCE_SHA256_MANIFEST.json').read_text('utf-8'))
bad = [e['path'] for e in man['files']
       if not (root/e['path']).exists()
       or hashlib.sha256((root/e['path']).read_bytes()).hexdigest() != e['sha256']]
print('files', len(man['files']), 'failures', len(bad))
assert not bad, bad[:5]
PY
```

## Backup (owner chooses destination; none selected yet)

Preferred order:

1. **Offline removable media** (external SSD/USB): simplest, no third party.
   ```bash
   tar -czf rad-raw-evidence-20261012.tar.gz \
       artifacts/stage3_acquisition_20261011/raw \
       artifacts/stage3_acquisition_20261011/manifests/RAW_EVIDENCE_SHA256_MANIFEST.json
   sha256sum rad-raw-evidence-20261012.tar.gz > rad-raw-evidence-20261012.tar.gz.sha256
   # copy both files to the removable device, then verify on the device:
   sha256sum -c rad-raw-evidence-20261012.tar.gz.sha256
   ```
2. **Second local machine** over an encrypted channel (scp/rsync over SSH).
3. **Encrypted cloud bucket** (e.g. provider of owner's choice) — requires
   explicit owner authorization; upload ONLY the tarball above plus its
   `.sha256`, never raw files individually.

Expected archive size: ~247 MB compressed (HTML compresses ~2-3x smaller,
expect 90-150 MB `.tar.gz`).

## Recovery / restore procedure

1. Place the archive (and `.sha256`) on the target machine.
2. `sha256sum -c rad-raw-evidence-20261012.tar.gz.sha256` — abort on mismatch.
3. Extract to the repository root:
   `tar -xzf rad-raw-evidence-20261012.tar.gz`
4. Run the pre-backup check above — all 1,627 files must verify.
5. Rebuild all derived artifacts from raw (proves restorability end-to-end):
   ```bash
   python tools/stage3_content_migration/extract.py --root artifacts/stage3_acquisition_20261011
   python tools/stage3_content_migration/build_canonical_dataset.py \
       --root artifacts/stage3_acquisition_20261011 \
       --out artifacts/stage3_canonical_dataset_20261011
   ```
   The rebuilt dataset must hash to the committed `DATASET_MANIFEST.json`
   `dataset_sha256` (deterministic pipeline).

## Cadence recommendation

Take a fresh backup after any acquisition re-run (the manifest changes),
and after each release that commits new derived datasets. Keep at least two
copies, one off-site.
