# Branch, integration and ownership inventory

`git fetch origin --prune` completed before this inventory. 33 local worktrees were inspected; 22 had changes at capture. See `evidence/inventory.json` for exact paths, statuses, upstream/ahead-behind, commit timestamps and every dirty file. Other agents' changes were read only.

| Branch | Local HEAD | Fetched origin HEAD | Reference commits present by ancestry |
| --- | --- | --- | --- |
| feat/rad-core-security-final | a24f4921926667877c10095e073f87f585b1bde5 | a24f4921926667877c10095e073f87f585b1bde5 | 9736540, 24b3f6b, a24f492, 2e0d089, a9969c1, c710893, 843ea7c, b97c8f0 |
| feat/rad-backend-services-final | c57b56d0c5f51547f29beea0ca6148598c3b8128 | c57b56d0c5f51547f29beea0ca6148598c3b8128 | c57b56d, 2e0d089, a9969c1, c710893, 843ea7c, b97c8f0 |
| feat/rad-unified-release-candidate | 1fe44f63d179263c5e719578bf7ebad0e17868d1 | 1fe44f63d179263c5e719578bf7ebad0e17868d1 | c57b56d, b485c0c, e80f106, 2e0d089, a9969c1, c710893, 843ea7c, b97c8f0 |
| integration/antigravity-grok-a003-unified | b485c0cb513875b3833a2aa29ea89a1509102138 | b485c0cb513875b3833a2aa29ea89a1509102138 | b485c0c, e80f106, 2e0d089, a9969c1, c710893, 843ea7c, b97c8f0 |
| feat/rad-new-features-ui | 2e0d089781ef3de582143421a59817094e57ca78 | not published under this origin ref | 2e0d089 |
| feat/antigravity-a003-flutter-implementation | e80f10680a872fba5cd363f2e943b1742127b0a2 | e80f10680a872fba5cd363f2e943b1742127b0a2 | e80f106, 2e0d089, a9969c1, c710893, 843ea7c, b97c8f0 |
| integration/grok-final-unified-rc | 02cff0602e07e5fdea11765539f5c16a529f339a | not published under this origin ref | 2e0d089, a9969c1, c710893, 843ea7c, b97c8f0 |
| feat/antigravity-flutter-e2e-completion | 843ea7c2b715380a17e566eaf0bccdb7bb31029f | f616078a56eb8159030911d38b66b1e961504dba | 2e0d089, 843ea7c |
| feat/grok-independent-feature-completion | b97c8f03a7618046e54f98a25685bc6f0ce85560 | not published under this origin ref | b97c8f0 |
| main / deployed Render | 95e1fdaac74d36ca1c91f2d9d897ff7686dc3ffb | 95e1fdaac74d36ca1c91f2d9d897ff7686dc3ffb | Candidate is 20 commits ahead by rev-list; no main commits missing from candidate |

Owner attribution follows explicit project roles and worktree/branch names: Codex backend/security; Antigravity Flutter/contracts and unified candidate; Grok services and Grok integration worktrees; Freebuff newer feature UI; Gemini CI/review. Worktree names do not prove a live agent lease. No direct agent session exists, so no assertion is made that an agent is currently idle or actively editing a specific file.

Candidate `1fe44f6` includes Grok `c57b56d`, Antigravity adapter `e80f106`, prior domain/Flutter work (`c710893`, `843ea7c`, `b97c8f0`) and case identity fix `a9969c1`. The newer origin Flutter E2E commit `f616078a56eb8159030911d38b66b1e961504dba` is also an ancestor despite the older local worktree HEAD. Candidate does **not** include Codex `9736540` or `24b3f6b`; all seven 20261020 SQL files and corrected wire/security regressions are absent.

Read-only Render verification in previously authorized workspace Rad confirms static service `srv-db0p4e9srm7s738jam10` is live at `95e1fdaac74d36ca1c91f2d9d897ff7686dc3ffb`, matching fetched origin/main. Auto-deploy is off; configured branch is main; build is `bash scripts/build_web_render.sh`, publish directory `build/web`. The tested candidate is not deployed. Five deployment metadata rows were inspected; no environment values, deployments or settings were read/changed. See `render_readonly.json`. Hosted Supabase lists only research-sync v4 (gateway JWT off, handler authorization required), ai-orchestrator v11 and document-intelligence v3 (gateway JWT on); new candidate workers are not deployed there.

Freebuff's current booking/interview files are untracked in its own worktree. Read-only comparison shows booking implementation and interview tests agree with the candidate; `interviews_page.dart` differs: the candidate adds a future quarter-hour seed and replaces one Wrap with a Column. Therefore substantial Freebuff recovery was incorporated, but its files cannot be represented as a new published Freebuff commit. The independent mobile overflow test still fails. Nothing was copied or cherry-picked from those dirty directories.

Preserved unresolved work includes the `UU` timezone engine in `rad_pr49_time_review_20261018`, staged UI changes in `rad_integrate68_readonly_20261018`, untracked migrations in `rad_c002_c003_local` and `rad_grok_final_recovery`, and dirty routing tests in `rad_integration_a003_unified`. Their exact statuses remain in the inventory. Do not reset, move, stage or publish them through this audit.

The audit branch began at exact candidate SHA before all verification. Only this new checkout and its two marked local runtimes were written. Generated Flutter plugin files in the audit checkout are tracked separately from actual source changes and checked for line-ending-only effects before report commit.
