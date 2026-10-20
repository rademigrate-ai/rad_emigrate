"""Invoke the reviewed local-only harness against the immutable audit candidate.
The harness source is external to candidate and its digest is recorded.
"""
import hashlib, importlib.util, json, pathlib, subprocess, sys
BASE=pathlib.Path(r'C:\Users\Mehrshad\Desktop\RAD - Emigrate')
SOURCE=BASE/'rad_core_security_final/scripts/rad_local_rehearsal.py'
ROOT=BASE/'rad_final_independent_audit'
OUT=BASE/'_final_independent_evidence_20261020'
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()=='1fe44f63d179263c5e719578bf7ebad0e17868d1'
(OUT/'external_rehearsal_harness.json').write_text(json.dumps({'path':str(SOURCE),'sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'reason':'Candidate helper is hardcoded to a pre-existing runtime owned by a different checkout; do not modify that stack. Reuse configurable loopback + ownership + Docker-port guarded runner without altering candidate SQL.'},indent=2),encoding='utf-8')
spec=importlib.util.spec_from_file_location('rad_audit_harness',SOURCE)
mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
mod.ROOT=ROOT
sys.argv=[str(SOURCE),*sys.argv[1:]]
mod.main()
