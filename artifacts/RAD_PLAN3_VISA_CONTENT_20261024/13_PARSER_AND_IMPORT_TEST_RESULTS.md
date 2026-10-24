# Parser and import verification

Evidence recorded at package generation:

```json
{
  "android_debug_build": {
    "apk_sha256": "5260d9860060918b68bdca76ee3bc3267d27dca595ad83a274484d0f61cd343e",
    "local_log": "D:\\RAD_PLAN3_20261024\\android_build.log",
    "log_sha256": "dc235a42ec89e407b9ab45c6404d9a241ca57f717f0022f5d357b9438f2eabad",
    "release_verified": false,
    "status": "PASS",
    "variant": "debug arm64",
    "warnings": [
      "file_picker KGP future compatibility warning",
      "local SDK XML version warning",
      "Java native access warning"
    ]
  },
  "client_task_date": "2026-10-24",
  "dart_format": {
    "local_log": "D:\\RAD_PLAN3_20261024\\dart_format.log",
    "log_sha256": "46e984564bf2f7ff73262e384986a17a3578545c73b7ce5e818518dc730adec3",
    "status": "PASS"
  },
  "deno_lint": {
    "local_log": "D:\\RAD_PLAN3_20261024\\deno_lint.log",
    "log_sha256": "e35d68df5eca46f00bb5e232c2199ff7a2a2c18d0d5036c02d1c853233f45c46",
    "status": "PASS"
  },
  "deno_tests": {
    "ci_pinned_version": "2.5.4",
    "local_log": "D:\\RAD_PLAN3_20261024\\deno_tests.log",
    "local_version": "2.9.7",
    "log_sha256": "46b7f7e071494c965767150b3ea6c526c33e4f831d64c24f553cf0b16c064aec",
    "status": "PASS",
    "test_count": 158
  },
  "disposable_migrations": {
    "at": "2026-10-24T13:37:34.825972+00:00",
    "count": 83,
    "local_only": true,
    "migration_exit_code": 0,
    "port": 62522,
    "project": "rad_plan3_20261024"
  },
  "final_head_ci": {
    "passed": false,
    "status": "PENDING_GITHUB_DELIVERY"
  },
  "flutter_analyze": {
    "local_log": "D:\\RAD_PLAN3_20261024\\flutter_analyze.log",
    "log_sha256": "4cfe57a367a78abf0bb7c19c6abb300d8777360be9b8221d8fbae34be100c651",
    "status": "PASS"
  },
  "flutter_tests": {
    "local_log": "D:\\RAD_PLAN3_20261024\\flutter_test.log",
    "log_sha256": "29390e88a1925f36fd91e663cee3bb130b04c745c5f9f4ef4233c69903f766df",
    "status": "PASS",
    "test_count": 1019
  },
  "hosted_mutations": false,
  "import_package_index_sha256": "3e3b3a381e223b193db2fa007352b4c34caee1cbbebc1dcf4f807a9ff25117a7",
  "library_validation": {
    "counts": {
      "canonical_drafts": 830,
      "complete_article_bodies": 1083,
      "discovered_urls": 1922,
      "structurally_valid_draft_payloads": 575,
      "successfully_retrieved_pages": 1206
    },
    "hosted_mutations": false,
    "publication_ready": 0,
    "status": "PASS"
  },
  "observed_at": "2026-10-24T15:18:05.585773+00:00",
  "owned_disposable_cleanup": {
    "other_projects_not_targeted": true,
    "project": "rad_plan3_20261024",
    "stopped": true
  },
  "post_rollback_readonly_proof": {
    "rehearsal_articles_remaining": 0,
    "synthetic_auth_users_remaining": 0
  },
  "postgres_full_package": {
    "backend": "owned Supabase/PostgreSQL",
    "feed_and_publication_unchanged": true,
    "hosted_mutations": false,
    "ordinary_user_denied": true,
    "public_search_draft_isolation": true,
    "result": {
      "all_draft": true,
      "articles": 575,
      "replayed_equal": true
    },
    "runtime": {
      "owner_checkout": "D:\\RAD_PLAN3_20261024\\source",
      "port": 62522,
      "project": "rad_plan3_20261024"
    },
    "transaction_rolled_back": true
  },
  "python_regressions": {
    "local_log": "D:\\RAD_PLAN3_20261024\\python_all.log",
    "log_sha256": "bf63ea7a3fe1a0cc487a44acd893a2abd086450343ab99dc5bcecc42bbc784a7",
    "status": "PASS",
    "test_count": 105
  },
  "rehearsed_payload_sha256": "238dcc2561504fc46e50008b5b9078b294c781dfe0c1654c4cae7a5e5a9159b2",
  "rehearsed_source_sha256": "91ccc28ebdc41410434a132728fcb814488136b783ced26f8e741e1a43b3ec50",
  "scope": "Owned content tools, tests, CI and delivery data only; no Flutter/backend/migration edits.",
  "sql_regressions": {
    "checks": [
      {
        "exit_code": 0,
        "file": "supabase/tests/rad_content_security.sql",
        "status": "PASS"
      },
      {
        "exit_code": 0,
        "file": "supabase/tests/rad_merge_provenance.sql",
        "status": "PASS"
      },
      {
        "exit_code": 0,
        "file": "supabase/tests/rad_official_evidence.sql",
        "status": "PASS"
      },
      {
        "exit_code": 0,
        "file": "supabase/tests/rad_client_table_privileges.sql",
        "status": "PASS"
      },
      {
        "exit_code": 0,
        "file": "supabase/tests/rad_privacy_security.sql",
        "status": "PASS"
      }
    ],
    "hosted_mutations": false,
    "observed_at": "2026-10-24T14:17:15.349221+00:00",
    "runtime_project": "rad_plan3_20261024"
  },
  "sqlite_full_package": {
    "backend": "SQLite journal only",
    "first": {
      "blocked": 255,
      "created": 575,
      "replayed": 0
    },
    "publication_writes": 0,
    "row_counts_unchanged_on_retry": true,
    "rows": {
      "plan3_articles": 575,
      "plan3_documents": 575,
      "plan3_requests": 1150,
      "plan3_snapshots": 575
    },
    "second": {
      "blocked": 255,
      "created": 0,
      "replayed": 575
    },
    "supabase_semantics_verified": false
  },
  "web_build": {
    "local_log": "D:\\RAD_PLAN3_20261024\\web_build.log",
    "log_sha256": "e032f1cf509bff867971146ddbd66e342bc860f3fddfcf3ea95919dbfeda10e4",
    "status": "PASS"
  }
}
```

Required checks: URL/manifest identities, real and synthetic parser fixtures, exact/near canonical grouping, source/citation mapping, source text preservation, draft-only gates, non-destructive idempotent journal retry, closed canonical request schemas, and actual owned PostgreSQL CMS import/retry/authorization/search isolation. Synthetic fixtures contain no purported factual immigration advice. Full tests run with `python -m unittest discover -s scripts/tests -v` after installing requirements-plan3.txt. No unavailable check is labeled passed.

The Draft PR must have successful required workflows on its exact final HEAD. CI status generated later is linked from GitHub and the final delivery receipt; this file does not turn a pending/older-head run into final-head evidence. Flutter/backend code was not changed by this content-only implementation; existing required repository CI still exercises its integration.
