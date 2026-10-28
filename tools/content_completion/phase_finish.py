"""Bind final receipts and transport package to the tested immutable commit."""

import argparse
import json
import re
import subprocess
import zipfile
from pathlib import Path

from tools.content_completion.phase_bundle import save_json, sha
from tools.content_completion.phase_verify import artifact_files


def finish(directory):
    git = ["git", "-c", "safe.directory=" + Path.cwd().as_posix()]
    head = subprocess.check_output([*git, "rev-parse", "HEAD"], text=True).strip()
    branch = subprocess.check_output(
        [*git, "branch", "--show-current"], text=True
    ).strip()
    if subprocess.check_output(
        [*git, "diff", "--name-only", "HEAD"], text=True
    ).strip():
        raise ValueError("final_tracked_files_do_not_match_HEAD")
    verification = directory / "verification"
    manifests = {}
    for group, expected in [("core", 10), ("flutter", 5), ("sql", 6)]:
        receipt = json.loads(
            (verification / group / "receipt.json").read_text(encoding="utf-8")
        )
        if (
            receipt["head"] != head
            or not receipt["all_passed"]
            or receipt["completed_checks"] != expected
            or receipt["artifact_manifest_sha256"]
            != sha((directory / "final-manifest.json").read_bytes())
        ):
            raise ValueError("missing_or_different_HEAD_acceptance:" + group)
        for check in receipt["checks"]:
            if sha((directory / check["log"]).read_bytes()) != check["log_sha256"]:
                raise ValueError("acceptance_log_changed")
        manifests[group] = receipt
    ci = json.loads((verification / "ci.json").read_text(encoding="utf-8"))
    if (
        ci["head_sha"] != head
        or ci["conclusion"] != "success"
        or len(ci["jobs"]) != 8
        or any(j["conclusion"] != "success" for j in ci["jobs"])
    ):
        raise ValueError("final_HEAD_CI_not_eight_successful_jobs")
    source = json.loads(
        (directory / "source-integrity-summary.json").read_text(encoding="utf-8")
    )
    delivery = json.loads(
        (directory / "delivery-integrity-summary.json").read_text(encoding="utf-8")
    )
    python_log = (verification / "core/06.log").read_text(encoding="utf-8")
    deno_log = (verification / "core/07.log").read_text(encoding="utf-8")
    flutter_log = (verification / "flutter/03.log").read_text(encoding="utf-8")
    python_count = int(re.search(r"Ran (\d+) tests", python_log)[1])
    deno_count = int(re.findall(r"ok \| (\d+) passed \| 0 failed", deno_log)[-1])
    flutter_count = max(map(int, re.findall(r"\+(\d+):", flutter_log)))
    phases = {
        "phase1": "PASS",
        "phase2": "BLOCKED_COMPLETE_SOURCE_COVERAGE; recovered corpus and accounting delivered",
        "phase3": "BLOCKED_EXHAUSTIVE_PLACEMENT_AND_EDITORIAL_DECISIONS; technical draft package PASS",
        "phase4": "PASS_LOCAL_AND_CI; hosted authenticated acceptance reserved for phases5-8",
    }
    record = {
        "title": "RAD EMIGRATE — CODEX PHASES 1–4 FINAL IMPLEMENTATION HANDOFF",
        "starting_head": "2484537ce05c11bf7463d62b043851dc04a35057",
        "final_head": head,
        "branch": branch,
        "source_summary": source,
        "delivery_summary": delivery,
        "phases": phases,
        "local_checks": {
            g: {"passed": r["completed_checks"], "head": r["head"]}
            for g, r in manifests.items()
        },
        "test_counts": {
            "python": python_count,
            "deno": deno_count,
            "flutter": flutter_count,
        },
        "ci": ci,
        "overall": "VERIFIED_ENGINEERING_AND_DRAFT_HANDOFF; COMPLETE_CONTENT_ACCEPTANCE_BLOCKED_BY_ITEMIZED_SOURCE_AND_HUMAN_INPUTS",
        "hosted_writes": 0,
        "production_accessed": False,
        "PR85_must_remain_draft_unmerged": True,
        "backup_restore_gate_passed": False,
    }
    save_json(verification / "final-acceptance.json", record)
    body = f"""# {record["title"]}

Final branch: `{branch}`
Final verified commit: `{head}`
Starting integration commit: `{record["starting_head"]}`
Handoff PR: {ci["pull_request_url"]}
Exact-head CI: {ci["url"]} — 8/8 successful jobs.

## Outcome

Engineering and deterministic draft delivery are verified. Complete source coverage and exhaustive editorial placement remain BLOCKED by the itemized source and human-review inputs. This is not unconditional completion or hosted Staging acceptance.

The complete implementation, changes, source provenance, architecture and integration order are documented in `../README.md`. No migration was added. The handoff is one additive commit on the existing integration lineage. Integrate the entire commit with ordinary conflict review; preserve Antigravity's worktrees and `_scratch`. Keep PR #85 Draft and unmerged.

## Content delivered

- 2,055 source identities; 1,385 have a full owned body and verified raw HTML. 214 retain raw/incomplete evidence, 50 unavailable leads, 406 deliberate noneditorial exclusions. There is no claim that these are all substantive articles.
- {source["capture_versions"]:,} verified raw capture versions; {delivery["all_capture_blocks_preserved"]:,} original structured blocks retained. Unknown capture times remain explicitly unknown.
- All 259 Antigravity raws, all 33 local refetch pairs, all 100 historical frontier bodies/raws and all 146 primary intake bodies/raws verified. Original Grok transfer ZIP and all 355 files are independently verified; 146 primary exports and all 100 owned Mohajer bodies match existing preserved content, adding no import operations.
- 126 targeted public article requests: 125 complete owned bodies and one thin body. Robots policy, rate limit and original response evidence retained.
- 369 new drafts, 91 protected revisions, 20 guarded duplicate-reader hides; 148 canonical locales and 944 independent Other Titles locales in the resulting plan. Mohajer content stays standalone.
- 446 source snapshots and 460 maps; all 2,617 prior excluded blocks retained and reconciled, including 2,487 primary listing blocks that still require full-article/placement review.
- 434 human-review items; 264 non-excluded incomplete/unavailable source records, many listing/placeholder pages. Exact and near overlap ledgers retain unique substance without automatic semantic merges.

## Verified implementation and tests

The source parser preserves Persian Unicode, heading levels, table cells/spans, nested lists and source links; listing excerpts cannot be promoted to full articles by length. Country inference no longer matches India inside engineering or UK inside Ukraine. Reconciliation import has no filesystem side effects. Snapshot pre-registration preserves NULL unknown HTTP metadata. Every full reader and public draft denial is verified in the same transaction. Research evidence exceeding the contract fails visibly instead of silently truncating. The existing atomic findings-to-review-candidate path and human Feed publication boundary remain intact.

All {sum(r["completed_checks"] for r in manifests.values())} local checks ran at `{head}`: **{flutter_count} Flutter, {python_count} Python and {deno_count} Deno tests**, core lint/regressions and source reproduction, Dart formatting, Flutter analysis, Web release build, Android debug build, corrective Research transition, editorial security/legacy, Stage 7/7.1 SQL and the combined import/retry/rollback rehearsal. Exact commands, counts, exit codes and hashed logs are in `core/receipt.json`, `flutter/receipt.json`, `sql/receipt.json`. CI independently passed all eight jobs, including clean-schema verification and migration reconstruction, at the same exact checked-out head. `ci.json` records each job.

The rollback-only rehearsal checked all 460 full Admin bodies and public draft rejection, exact retry without duplicates, changed-input rejection, human-reviewed relation protection, honest unknown capture metadata, restored original heads/catalog and retained immutable history. This synthetic local fixture is not a hosted-data backup restore.

## Phase states

| Phase | Result |
| --- | --- |
| 1 — verified baseline | PASS |
| 2 — complete source recovery/accounting | Recovery/accounting delivered; complete coverage BLOCKED by listed source/editorial gaps and source/editorial gaps (original Grok transfer is verified) |
| 3 — complete content placement | Technical draft package PASS; exhaustive placement/approval BLOCKED by the review queue and incomplete sources |
| 4 — implementation and automated verification | PASS for authorized local and CI scope; hosted authenticated UI acceptance belongs to phases 5–8 |

## Antigravity inputs and operational blockers

Consume this entire package and exact code commit, `final-manifest.json`, `prepared/`, source/capture/block/exclusion/duplicate/review ledgers, `destination-proposals.json`, and `import-review/import-plan.json`. Re-run `python -m tools.content_completion.phase_verify --directory _audit/RAD_CODEX_PHASES_1_TO_4_FINAL_20261028 --reproduce` after integration.

Only the generated review-only combined SQL preserves the pre-registered historical metadata; do not import unknown historical captures through the legacy RPC alone. The proposed transaction is not permission to execute it. A real approved read-only Staging backup connection, encrypted actual hosted backup, validated isolated local restore, explicit exact-operation Owner authorization, and fresh matching Staging preflight are still required before any hosted content write. No approved backup path or validated hosted restore is established here.

Editors must resolve outdated/conflicting legal claims, uncertain country scope, near duplicates, partial listing gaps and media rights. Antigravity must then verify actual authenticated Admin/Research and complete reader behavior in authorized Staging. Nothing in this task auto-approves or publishes content.

No hosted writes, hosted migrations/history repair, Auth/RLS/grant/Vault/secret changes, deployment, purchase, publication or merge occurred. Production was not accessed. The computer remains running.
"""
    (verification / "FINAL_IMPLEMENTATION_HANDOFF.md").write_text(
        body, encoding="utf-8", newline="\n"
    )
    runtime = sorted(
        p
        for p in verification.rglob("*")
        if p.is_file()
        and "preliminary" not in p.relative_to(verification).parts
        and p.name != "runtime-manifest.json"
    )
    save_json(
        verification / "runtime-manifest.json",
        {
            "head": head,
            "files": [
                {
                    "path": p.relative_to(directory).as_posix(),
                    "sha256": sha(p.read_bytes()),
                    "bytes": p.stat().st_size,
                }
                for p in runtime
            ],
            "self_digest_excluded": True,
            "preliminary_diagnostics_excluded": True,
        },
    )
    files = (
        artifact_files(directory)
        + [directory / "final-manifest.json"]
        + runtime
        + [verification / "runtime-manifest.json"]
    )
    transport = directory / "RAD_CODEX_PHASES_1_TO_4_FINAL_20261028.zip"
    with zipfile.ZipFile(
        transport, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6
    ) as bundle:
        for path in sorted(set(files)):
            name = directory.name + "/" + path.relative_to(directory).as_posix()
            info = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0))
            info.compress_type = (
                zipfile.ZIP_STORED if path.suffix == ".gz" else zipfile.ZIP_DEFLATED
            )
            bundle.writestr(info, path.read_bytes())
    save_json(
        verification / "transport-receipt.json",
        {
            "head": head,
            "path": transport.name,
            "bytes": transport.stat().st_size,
            "sha256": sha(transport.read_bytes()),
            "scope": "envelope checksum kept outside the ZIP to avoid a recursive digest",
        },
    )
    print(
        json.dumps(
            {
                "head": head,
                "zip": str(transport),
                "zip_sha256": sha(transport.read_bytes()),
                "phases": phases,
            }
        )
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True)
    finish(parser.parse_args().directory)
