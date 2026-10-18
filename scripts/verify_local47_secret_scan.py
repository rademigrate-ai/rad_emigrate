#!/usr/bin/env python3
"""Scan an immutable tracked snapshot and isolated reachable Git history offline.

Attribution: design and implementation originated in Codex worktree
(uncommitted scripts/verify_local47_secret_scan.py on feat/codex-master-47-execution-20261018).
Copied into Grok worktree for independent execution; Codex worktree left untouched.

Uses a digest-pinned official Gitleaks image. Source/history mounts are read-only,
the scanner has no network, and reports retain locations/rules but no secret or
matched text. No ignore file, source allow-comment or custom config is accepted.
Does not scan ignored working files, deployed assets or external secret stores.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
IMAGE = 'ghcr.io/gitleaks/gitleaks:v8.30.1@sha256:b109bc5f8f76a38196a3e413704fc5b9e3c32360bce4e4b603bd6f45b3721dbb'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--docker', default=shutil.which('docker'))
    parser.add_argument('--report', required=True, type=Path)
    args = parser.parse_args()
    assert args.docker, 'Docker is required'

    def git(*arguments):
        return subprocess.check_output(['git', *arguments], cwd=ROOT, text=True, encoding='utf-8').strip()

    revision = git('rev-parse', 'HEAD')
    branch = git('branch', '--show-current')
    assert branch, 'use an owned named checkout for isolated history scanning'
    runtime = Path(tempfile.mkdtemp(prefix='rad_local47_secret_scan_')).resolve()
    artifact, clone, reports = runtime/'snapshot', runtime/'history', runtime/'reports'
    artifact.mkdir()
    reports.mkdir()
    (runtime/'RAD_SCAN_OWNER.json').write_text(json.dumps({'source':str(ROOT),'revision':revision}), encoding='utf-8')
    archive = runtime/'tracked.zip'
    subprocess.run(['git','archive','--format=zip','--output',str(archive),revision], cwd=ROOT, check=True)
    with zipfile.ZipFile(archive) as bundle:
        for entry in bundle.infolist():
            target = (artifact/entry.filename).resolve()
            assert target.is_relative_to(artifact), 'unsafe tracked archive path'
        bundle.extractall(artifact)
    assert not (artifact/'.gitleaks.toml').exists(), 'review custom scanner policy before use'
    subprocess.run(['git','clone','--quiet','--no-local','--no-checkout','--single-branch','--branch',branch,str(ROOT),str(clone)],
        check=True, capture_output=True, text=True, timeout=90)
    assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=clone,text=True).strip()==revision, 'source branch moved during clone'
    empty_ignore = reports/'empty.ignore'
    empty_ignore.write_text('', encoding='utf-8')
    base = [args.docker,'run','--rm','--network','none','--read-only','--cap-drop','ALL','--security-opt','no-new-privileges',
        '--mount',f'type=bind,source={reports},target=/reports',IMAGE]
    report = {'scope':'immutable_tracked_snapshot_and_single_branch_reachable_history','scan_revision':revision,
        'worktree_dirty':bool(git('status','--porcelain')),'source_branch':branch,'scanner_image':IMAGE,
        'captured_at':datetime.now(timezone.utc).isoformat(),'network':'none','source_mounts':'read_only',
        'custom_config':False,'ignore_file':'empty','allow_comments_honored':False,'scans':{}}
    version = subprocess.run([*base,'version'],capture_output=True,text=True,timeout=30,check=True)
    assert version.stdout.strip()=='v8.30.1', 'unexpected scanner binary version'
    report['scanner_version'] = version.stdout.strip()
    for name, folder, mode in [('snapshot',artifact,'dir'),('history',clone,'git')]:
        # Insert the source mount before the image, keeping Docker flags separate
        # from scanner flags. Everything is passed as an argv array, never a shell.
        command = base[:-1]+['--mount',f'type=bind,source={folder},target=/scan,readonly',IMAGE,mode,'/scan',
            '--no-banner','--no-color','--redact=100','--ignore-gitleaks-allow','--gitleaks-ignore-path','/reports/empty.ignore',
            '--max-archive-depth=2','--max-decode-depth=5','--timeout=180','--report-format=json',f'--report-path=/reports/{name}.json']
        if mode=='git':
            command.append('--log-opts=--all')
        result = subprocess.run(command,capture_output=True,text=True,encoding='utf-8',timeout=210)
        assert result.returncode in (0,1), 'scanner failed; no finding values printed'
        raw_path = reports/(name+'.json')
        assert raw_path.is_relative_to(runtime) and raw_path.exists(), 'scanner did not produce its report'
        findings = json.loads(raw_path.read_text(encoding='utf-8')) or []
        locations = [{key:row[key] for key in ('RuleID','File','StartLine','EndLine','Commit','Fingerprint') if key in row} for row in findings]
        assert (result.returncode==0)==(len(findings)==0), 'scanner status and report disagree'
        report['scans'][name] = {'exit_code':result.returncode,'finding_count':len(findings),'locations':locations,
            'locations_sha256':hashlib.sha256(json.dumps(locations,sort_keys=True).encode()).hexdigest()}
        # The location-only report is sufficient to inspect the original source.
        # Remove the raw finding file; it may contain a secret despite log redaction.
        raw_path.unlink()
        print(f'{name}: {len(findings)} findings (values omitted)',flush=True)
    report['status'] = 'PASS' if all(item['finding_count']==0 for item in report['scans'].values()) else 'FINDINGS_REQUIRE_REVIEW'
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report,indent=2)+'\n', encoding='utf-8')
    print('Secret scan '+report['status']+' at '+revision)


if __name__=='__main__':
    main()
