# Final Handoff

## For Codex (independent re-audit)
- SHA: `024e7b29f51f6227f5f9d8dee292d1f8097ee3ca`
- PR: https://github.com/rademigrate-ai/rad_emigrate/pull/74 (draft)
- CI: https://github.com/rademigrate-ai/rad_emigrate/actions/runs/39665799156 (7/7 success)

## Next authorized actions (owner only)
1. Request Codex re-audit of `024e7b2`
2. After audit P0/P1 clear: consider marking PR ready for review (still not merge without auth)
3. Hosted migration rehearsal package + backup before any staging write
4. Explicit authorization required for: merge to main, staging deploy, production migrate/deploy, Edge deploy, store submit

## Do not
- Merge to main without authorization
- Apply hosted migrations
- Deploy Edge Functions or production
- Publish Feed content automatically
