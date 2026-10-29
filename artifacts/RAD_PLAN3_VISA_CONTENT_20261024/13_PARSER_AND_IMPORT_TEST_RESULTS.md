# Parser and import verification

Evidence recorded at package generation:

```json
{
  "android_debug_build": {
    "apk_sha256": "5260d9860060918b68bdca76ee3bc3267d27dca595ad83a274484d0f61cd343e",
    "local_log": "D:\\RAD_PLAN3_20261024\\hardening_android_build.log",
    "log_sha256": "d59e4c39ffe7d2c5c99d5e9df11394285a33c6c961461b254f46f1578bdc4d3b",
    "release_verified": false,
    "status": "PASS",
    "variant": "debug arm64"
  },
  "baseline_sha": "18900fecda36ff0ca23e7b204a4ecae20340879a",
  "dart_format": {
    "local_log": "D:\\RAD_PLAN3_20261024\\hardening_dart_format.log",
    "log_sha256": "0f35e3af70441a5b22e7772ccc504d4e71f7f0ddd49d86c1774df770983b081f",
    "status": "PASS"
  },
  "deno_lint": {
    "local_log": "D:\\RAD_PLAN3_20261024\\hardening_deno_lint.log",
    "log_sha256": "2386a8b18ff4f9496aedc9bf46bcbdeb097fa85c052bc183632613fcf767ba66",
    "status": "PASS"
  },
  "deno_tests": {
    "ci_version": "2.5.4",
    "local_log": "D:\\RAD_PLAN3_20261024\\hardening_deno_tests.log",
    "local_version": "2.9.7",
    "log_sha256": "950d78f390059be6a227b46f0fc845ee9bcb5b4bb67e53da17b1a6fcaa94bfd7",
    "status": "PASS",
    "test_count": 158
  },
  "disposable_migrations": {
    "at": "2026-10-24T18:08:26.474946+00:00",
    "count": 83,
    "local_only": true,
    "migration_exit_code": 0,
    "port": 62622,
    "project": "rad_plan3_hardening_20261024"
  },
  "final_head_ci": {
    "passed": false,
    "status": "PRE_COMMIT_RECORD_SEE_PR80_FINAL_SHA_CHECKS"
  },
  "flutter_analyze": {
    "local_log": "D:\\RAD_PLAN3_20261024\\hardening_flutter_analyze.log",
    "log_sha256": "26f4ccdb7e338e7e4a182adc63cfba02caaf99067ccbdad5a3bd53e9c8b09ba7",
    "status": "PASS"
  },
  "flutter_tests": {
    "local_log": "D:\\RAD_PLAN3_20261024\\hardening_flutter_test.log",
    "log_sha256": "cbb8ec9776747ea528574a0dec377f55eef2d7b954c551543bdd9b126b09bc73",
    "status": "PASS",
    "test_count": 1019
  },
  "hosted_mutations": false,
  "observed_at": "2026-10-24T18:38:41.492068+00:00",
  "owned_disposable_cleanup": {
    "other_projects_not_targeted": true,
    "project": "rad_plan3_hardening_20261024",
    "stopped": true
  },
  "phase": "Plan 3 final hardening continuation of PR80",
  "pipeline_file_sha256": {
    "tools/plan3_content/__init__.py": "ebe3b32fb93bdacbf7b3572df6feda55ac89e431d5c92eeae4aded6829549470",
    "tools/plan3_content/build.py": "8f8dadf6a75be789018c9952a2410644a97145bb39e142c5e7a600a491dedfa9",
    "tools/plan3_content/cli.py": "2e6a0289a3f1f52ff94a1fac1c4d015f390d21430fd02c620447fbfe4e10edc7",
    "tools/plan3_content/crawl.py": "a6292b94079cabf91deee0da69c7723aeea2886c6888f214ca6a2051a6794e4d",
    "tools/plan3_content/dataset.py": "47d5b627b1952eac37bb5d2a15c6661236735d558bbeaff9b1528a6465b89699",
    "tools/plan3_content/importer.py": "ebc5e56a5c48419c68d474a6763c75b4e8c119cac5d8eb0fd135af8b5e1132b7",
    "tools/plan3_content/parser.py": "0a07bc4443c3f32367334c754d7a9de40ea5a341ad84ccdfac5ce169e7daacb3",
    "tools/plan3_content/quality.py": "fe33901c5c6e13fd8a08d2cf47f0eaf35a1cfa5e923b1f491048f3b60ebaf721",
    "tools/plan3_content/reports.py": "a2e1b706dc5a4fcdc6bb2b7071d042e8d46250b1bb4381a84af995402b9b99c9",
    "tools/plan3_content/retry.py": "ce68179645e5a57634a48667f63daf425e823129351ca3c304766a7da0a26f8b",
    "tools/plan3_content/taxonomy.py": "dcd8680bdbf48c1c478e342968045b30fce6da62b3c7ae05e47448cdc4f64f82",
    "tools/plan3_content/traceability.py": "cf250f34475b8d40bf4a46f9a58490748ecca40cb7ab9f22283e18bc9fae6a90"
  },
  "post_rollback_readonly_proof": {
    "baseline_seed_evidence": "supabase/migrations/20261023010001_radmohajer_source_seed_parity.sql:6",
    "baseline_seed_urls": [
      "https://radmohajer.ir/en/about-us",
      "https://radmohajer.ir/en/contact-us",
      "https://radmohajer.ir/fa/contacts"
    ],
    "rehearsal_articles": 0,
    "rehearsal_source_documents": 0,
    "source_origins": 0,
    "source_snapshots": 0,
    "synthetic_auth_users": 0
  },
  "postgres_full_package": {
    "ai_grounding_unchanged": true,
    "backend": "owned Supabase/PostgreSQL",
    "feed_and_publication_unchanged": true,
    "first_party_origins_classified": true,
    "hosted_mutations": false,
    "ordinary_user_denied": true,
    "placeholder_review_hash_rejected": true,
    "public_search_draft_isolation": true,
    "result": {
      "all_draft": true,
      "articles": 581,
      "replayed_equal": true
    },
    "runtime": {
      "owner_checkout": "D:\\RAD_PLAN3_20261024\\source",
      "port": 62622,
      "project": "rad_plan3_hardening_20261024"
    },
    "source_documents_rehearsed": 728,
    "transaction_rolled_back": true
  },
  "postgres_mapping_receipt_sha256": "e78cbcb415427cbc4568749797a9ef11157c231f22f5df06f710f8480a28bcc2",
  "python_regressions": {
    "local_log": "D:\\RAD_PLAN3_20261024\\hardening_python_final.log",
    "log_sha256": "ed4af9c020e75e6dbab65bc22ecaa74ec8b343e952472b50649ddd4c0d2d77c3",
    "status": "PASS",
    "test_count": 126
  },
  "recovery_comparison": {
    "all_original_1083_bodies_unchanged": true,
    "all_original_830_canonical_ids_retained": true,
    "all_original_830_wire_payloads_unchanged": true,
    "baseline_sha": "18900fecda36ff0ca23e7b204a4ecae20340879a",
    "decompressed_credential_scan": {
      "files": 4,
      "high_risk_pattern_files": []
    },
    "fetch_history_records": 9,
    "final_counts": {
      "blocked_drafts": 256,
      "canonical_drafts": 837,
      "complete_bodies": 1090,
      "fetch_failures": 302,
      "retrieved_html": 1214,
      "source_records": 1922,
      "technical_drafts": 581
    },
    "hosted_mutations": false,
    "human_approved_articles": 0,
    "new_canonical_ids": [
      "03306261-f8a2-5c5a-8a37-ee30919b389e",
      "19402c32-29b0-5842-8eb5-abc2f93a1544",
      "baff309d-2168-5f0c-8862-6701764eaa2c",
      "bdf4f6bd-9946-5a0b-89e9-f09a9eaef789",
      "c18191de-0758-5c2d-b2de-8e4583d5ea05",
      "c7a10080-f559-5d68-b759-856525b25bf3",
      "cdb457cd-eff7-58d2-ae67-dffe22d550d4"
    ],
    "new_complete_bodies": 7,
    "new_html_hashes_and_bodies_independently_reextracted": 8,
    "observed_at": "2026-10-24T18:31:13.859442+00:00",
    "original_575_remain_technically_valid": true,
    "verified_legal_claims": 0
  },
  "rehearsed_payload_sha256": "e1df87724e69ac24d4257837208b828a7ac573fcd6a266517f068069a67552af",
  "rehearsed_source_sha256": "4ba20e982357d211f5b5d7f05fa766560b6236841c26b2c111cbbdc04c0f9e3f",
  "scope": "Flutter/backend/migrations unchanged; Flutter and Deno results bind that unchanged application tree. Current content code/data have 126 Python tests, full final-package PostgreSQL/journal rehearsals and independent raw/Git comparison. Final exact-SHA CI is reported separately after push.",
  "sql_regressions": {
    "checks": [
      {
        "exit_code": 0,
        "file": "supabase/tests/rad_content_security.sql"
      },
      {
        "exit_code": 0,
        "file": "supabase/tests/rad_merge_provenance.sql"
      },
      {
        "exit_code": 0,
        "file": "supabase/tests/rad_official_evidence.sql"
      },
      {
        "exit_code": 0,
        "file": "supabase/tests/rad_client_table_privileges.sql"
      },
      {
        "exit_code": 0,
        "file": "supabase/tests/rad_privacy_security.sql"
      }
    ],
    "local_only": true,
    "observed_at": "2026-10-24T18:10:34.592969+00:00",
    "runtime": "rad_plan3_hardening_20261024"
  },
  "sqlite_full_package": {
    "backend": "SQLite journal only",
    "first": {
      "blocked": 256,
      "created": 581,
      "replayed": 0
    },
    "publication_writes": 0,
    "row_counts_unchanged_on_retry": true,
    "rows": {
      "plan3_articles": 581,
      "plan3_documents": 728,
      "plan3_requests": 1162,
      "plan3_snapshots": 728
    },
    "second": {
      "blocked": 256,
      "created": 0,
      "replayed": 581
    },
    "supabase_semantics_verified": false
  },
  "web_build": {
    "local_log": "D:\\RAD_PLAN3_20261024\\hardening_web_build.log",
    "log_sha256": "93589dc4f0b0d19439025d903d385034da7d8cecd6a377323477fcc7c6b9e053",
    "status": "PASS"
  }
}
```

Required checks: URL/manifest identities, real and synthetic parser fixtures, exact/near canonical grouping, source/citation mapping, source text preservation, draft-only gates, non-destructive idempotent journal retry, closed canonical request schemas, and actual owned PostgreSQL CMS import/retry/authorization/search isolation. Synthetic fixtures contain no purported factual immigration advice. Full tests run with `python -m unittest discover -s scripts/tests -v` after installing requirements-plan3.txt. No unavailable check is labeled passed.

The Draft PR must have successful required workflows on its exact final HEAD. CI status generated later is linked from GitHub and the final delivery receipt; this file does not turn a pending/older-head run into final-head evidence. Flutter/backend code was not changed by this content-only implementation; existing required repository CI still exercises its integration.
