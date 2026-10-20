# Database migration report

READ-ONLY remote boundary: production `inshddthftkhcdosoqcn` and staging were not modified. Local writes were confined to marked, allocated Docker projects `rad_core_upgrade` (60322) and `rad_core_canonical` (61322), with matching container port and checkout ownership checks.

R00 reconstructed the captured schema/function/RLS/grant/Storage metadata without real application rows or Vault values, installed 54 synthetic ledger identities, and compared tables, columns, constraints, indexes, policies, table grants, column grants, functions/body/search path/effective ACL, triggers and bucket metadata. There were no differences in these ten dimensions; the local CLI dry-run showed zero historical migrations pending before upgrade.

This is a metadata rehearsal, not a production restore. Extension patch versions, newer local Storage objects, platform-owned auth/storage internals, inactive no-op cron commands, omitted Vault values and omitted business data are explicit exceptions. Schema/default-ACL and live cron command parity are not claimed. The baseline capture must be refreshed before release.

Clean replay uses the existing authoritative repository lineage only in the disposable environment. Historical files that open BEGIN without COMMIT are wrapped with the same effective boundary supplied by the CLI. The first runner attempt exposed this issue, was discarded in its owned environment, and was corrected. The production-shaped path never executes historical SQL. Cron schedules in the metadata reconstruction are inactive; clean-replay schedules are disabled as migration files are applied.

The previous `pg_cron` permission problem was resolved using `cron.alter_job(..., active := false)`, not direct writes/grants to `cron.job`.

New corrections preserve historical files. Runtime tests caught a later legacy publisher replacement removing its human marker/grants, and schema-local default revokes failing to remove global PUBLIC execute. Both have additive fixes. The global default revoke requires explicit grants for temporary test helpers as well. R05 adds consultation history without fabricating past events; R06 adds only the reviewed privacy effect, without telemetry scrub or alert activation.

| Forward file | SHA-256 |
|---|---|
| `20261019204906_rad_security_contract_foundation.sql` | `e804131bff73bf462b44dc22c2a8bfad7a286f771f5e095dc076ae3354faa384` |
| `20261019205040_rad_visa_cms_official_evidence.sql` | `a6f37b7cea2deffe2c2d32086f6d3c5ec23e428cff9e6a24ad2a2d89f289d9fe` |
| `20261019205454_rad_currency_cache_alerts.sql` | `c9bd5845613f14b62fb77886de65cb4159a63eb363ff969ade42fc5cef4505f1` |
| `20261019205459_rad_feed_notifications_search.sql` | `6008db3e4bf4ca44b55bc1f5b77a80adb5fadce4f6cd52d2bff7716ff65dc261` |
| `20261019205502_rad_copilot_scoped_reservations.sql` | `e3aa6007137551086a327cb09b183502471a678a6ebb00f17124c322b8eb2d2c` |
| `20261019210000_g002_content_architecture_scaffolding.sql` | `3569bd48d5710afd8edac0e99886d545dde4edf88d4a39cc2d1d96a206061d3f` |
| `20261019210423_rad_content_workflows.sql` | `ee9d66a758c2cc13ed029a8b4add8ea27b361627a48796955363a397a4748335` |
| `20261019211000_security_quota_owner_and_publish_approved.sql` | `ac786582876d3163a4310b485466752300b8ccfe0a900ef13e99300084b57c86` |
| `20261019211908_rad_feed_delivery_contracts.sql` | `9d60a1e46bd2927f39f47f5ddf5b769ef95ab1bc0585c9040757fddc51740601` |
| `20261019212615_rad_source_jobs_merge_enforcement.sql` | `6a45d929f8f446eac9d02a0900b33a33fbe89ee1f456be6c7817ad44e05fe3f5` |
| `20261019213129_rad_contract_finalization.sql` | `3e57e1d21b72e5c781654c8aad252c8a386f789c92c4e67aaf2f76a31c1133c8` |
| `20261019214411_rad_legacy_quota_budget_compatibility.sql` | `033dda87c1b2eac871e6ae08824a5114ce3a0c74918c2e533798fe1476c001ae` |
| `20261020103648_rad_backend_integrity_completion.sql` | `6d420bb1137217184a20f34e56b08872a746e428c6139bef1d3294db10ed6a69` |
| `20261020105854_rad_search_aliases_currency_history.sql` | `ba2f8a9afa96b38c17750c35f552bdb1ce07c2022859bdfdfb7691928bccc5c9` |
| `20261020111217_rad_restore_legacy_publish_privileges.sql` | `acd2d113fd47c9cd353f00b14e41d46e79e7c07e2e185117cef2b37bc0fdfbc8` |
| `20261020112300_rad_crm_search_integration_hardening.sql` | `2c2234751a73178fc5ab6a1955258caec9a5f65f7387f8269c1e2c2371b2ebe7` |
| `20261020114612_rad_transport_contract_registry_alignment.sql` | `c403adf1c1dfc44e49968d6d71e0013068494e6751ea3c4786b86bf4626d007f` |
| `20261020115539_rad_leased_research_base_contract.sql` | `8c13fa85d06a6f57d28c90bc676a5cab57ad6da3e7f19fcad50c054973238129` |
| `20261020123523_rad_explicit_service_profile_bootstrap.sql` | `569ac10dc29dc1cec17b45b3ab885f4d728fc202c99b165f394aaa228d4344d4` |

Canonical and upgrade reports include the verified 76-file clean prefix and two appended files, and the verified 16-file production-shaped upgrade followed by its two explicit additive appends. The consolidated manifest covers all files. Raw sha256 values describe Windows rehearsal bytes; git_lf_sha256 values describe Git-published LF bytes. CRLF-to-LF equivalence was checked; no historical migration contents were edited. These conventions matter when verifying the manifest on Linux. Final remote migration authorization, fresh drift reconciliation, preimage/dependency checks, lock assessment, backup/recovery rehearsal and frontend contract acceptance remain release gates. Never replay or repair the production historical ledger to match the repository count.
