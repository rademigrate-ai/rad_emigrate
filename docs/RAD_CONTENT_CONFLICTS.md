# RAD Content Conflicts (Stage 3)

No new `knowledge_conflicts` rows were created in Stage 3.

Reason: regulatory claims were **not** promoted to approved Knowledge, so there was no approved claim to mark conflicting against official sources.

When operators promote a regulatory claim later, they must:
1. Attach official evidence snapshots where available
2. Call `register_knowledge_conflict` if RAD text and official text disagree materially
3. Leave both evidence rows intact
