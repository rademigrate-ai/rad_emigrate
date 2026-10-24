# Plan 3 content pipeline

Python 3.11+; install `requirements-plan3.txt` in an owned virtual environment.
This tool captures the three owner-authorized RAD sites, preserves source text,
builds a deterministic canonical library, and prepares **unapproved drafts**.
It has no hosted import or publication mode.

The checked-in delivery is `artifacts/RAD_PLAN3_VISA_CONTENT_20261024/`.
Validate it offline:

```powershell
python -m tools.plan3_content.cli library --directory artifacts/RAD_PLAN3_VISA_CONTENT_20261024
python -m unittest discover -s scripts/tests -v
```

Inspect an original canonical body, not only its summary:

```powershell
python -m tools.plan3_content.cli inspect --directory artifacts/RAD_PLAN3_VISA_CONTENT_20261024 --canonical-id <uuid> --output <owned-file.json>
```

Rebuild from committed, parsed evidence without network access:

```powershell
python -m tools.plan3_content.build --collected artifacts/RAD_PLAN3_VISA_CONTENT_20261024/data/capture.jsonl.gz --production-metadata artifacts/RAD_PLAN3_VISA_CONTENT_20261024/data/production_content_baseline.json --structured-metadata artifacts/RAD_PLAN3_VISA_CONTENT_20261024/data/production_structured_baseline.json --schema-gate artifacts/RAD_PLAN3_VISA_CONTENT_20261024/data/production_canonical_schema_gate.json --discovery artifacts/RAD_PLAN3_VISA_CONTENT_20261024/data/discovery.json --output <owned-output-directory>
```

Keep `data/canonical_identity_registry.json` in the output directory on recapture
to retain identities when additional exact duplicates are discovered. Existing
different canonical identities and changed revisions require human resolution.
Per-source originals, exact duplicates, near matches, numeric disagreement
candidates, and original dates remain separate evidence. Classification is an
inference and must be reviewed. Persian normalization affects search keys only.

Fresh collection is explicit network work; run `python -m
tools.plan3_content.crawl --help`. The crawler respects robots, scopes redirects,
uses HTTPS, rate/size/redirect/frontier bounds and verified local cache. It does
not submit forms or authenticate. Failed fetches remain errors on resume;
`--retry-failures` explicitly requests another bounded attempt. Legacy Joomla
demo routes and stateful pages have recorded exclusions. Attachments retain
references and dispositions; no attachment extraction is claimed. Raw HTML stays
in an external owned cache, outside Git.

See delivery documents 11–16 for rehearsal, CMS v1 adaptation limits and frontend/
backend owner handoffs. PostgreSQL rehearsal requires a matching owned Docker
runtime/port marker, explicit disposable-write flag and a loopback database with
no connection-string overrides. Every import transaction rolls back. It tests
real create/save RPCs, exact retry, draft/unverified state, ordinary-user denial,
draft search isolation and unchanged publication/Feed state. SQLite is a separate
journal test and is never presented as proof of Supabase/RLS behavior.

Source extraction, closed-schema validity, official legal verification, human
approval and publication are distinct gates. This library has no verified legal
claims or approvals. All `publication_allowed` flags are false. Historical 812
records were not recovered; the reconciliation records missing historical
evidence rather than fabricating membership. Production schema/migration
alignment, recovery evidence and separately authorized human import/publication
remain prerequisites owned outside this tooling.
