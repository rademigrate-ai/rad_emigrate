# Reproducible release gates

| Gate | Verdict | Basis |
| --- | --- | --- |
| Integration Review | GO | Evidence and existing completed branch deltas are reviewable; unresolved defects remain |
| Candidate integrated acceptance | NO-GO | Missing Codex deltas, four failed CI jobs and confirmed source/UI/integration defects |
| Staging | NO-GO | Mandatory gates do not pass on the same final candidate; staging procedure approval still required |
| Production | NO-GO | Migration reconciliation/initialization, operations and release authorization absent |
| Android debug build | See test evidence | Build output is a development artifact, never signed-release approval |
| Android signed release | NO-GO | Permanent application identity and owner-supplied signing absent; guard intentionally blocks packaging |

Checklist for the integration owner, in dependency order:

- [ ] Agree one immutable combined source commit, actual agent ownership and a complete manifest. Do not merge this report as a substitute for integrating backend code.
- [ ] Reconcile existing Codex `9736540` and `24b3f6b` effects with Antigravity/Grok. Avoid recreating their seven SQL files. Keep extra Grok lifecycle coverage and address scoped-read CI requirements explicitly.
- [ ] Fix human-only publication, immutable official evidence, NULL validation and intended definer ACLs; rerun positive and negative real-role tests. Never weaken RLS or make private routines public to satisfy a test.
- [ ] Correct currency fabrication and unsourced cost/comparison output. Use approved evidence models or unavailable states.
- [ ] Resolve AI v1 request/version/consent wiring and booking actual-ID/history semantics with Antigravity; add account-switch and route-return regressions.
- [ ] Resolve interview mobile overflow and test fa/en, long timezones, narrow widths, 200% text and loading/error/empty states.
- [ ] Approve hosted effects mapping, required component manifest and additive-only migration plan. Rehearse on clean and fresh production-shaped disposable databases. Confirm migration bytes and no hosted drift.
- [ ] All format/analyze/full Flutter, Deno lint/typecheck/tests, real Edge/Auth/RPC security, quota races, research-to-draft and no-auto-publication, SQL security, clean/additive rehearsals, secret review, web/Android builds and GitHub CI pass on the **same combined source commit**.
- [ ] Validate approved source corpus, authority roots, pinned egress, provider credentials/limits, notification transport, operational monitoring, rollback/restore and disabled-capability initialization in staging.
- [ ] Obtain explicit staging procedure approval before deployment. This audit did not deploy.
- [ ] Obtain permanent Android application ID, protected signing, device testing and release distribution review. Debug build is insufficient.
- [ ] Repeat pre-production drift/initialization verification, approve operational readiness and obtain final production release authorization.

Existing successful Codex branch CI at `24b3f6b` is historical supporting evidence only; it is not the unified candidate's CI and does not override this run's failure. No gate is implicitly approved by an elapsed wait, successful build or report publication.
