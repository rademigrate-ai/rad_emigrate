# PR82 E2E evidence register

Historical integration evidence is preserved, never relabeled as fresh acceptance:

| Evidence set | Result | Limits |
|---|---|---|
| Historical 36-case suite, 2026-10-24 | 31 weak; 5 failed | URL-only checks, unconditional screenshot passes, Node REST in place of UI lifecycle, invalid public reader/editor outcomes |
| Independent audit browser replay at baseline 1f0a1733 | 5 UI passes | Guest/login password visibility, real locale toggles, mobile overflow and CMS guest fence only |
| Authenticated browser scenarios | 8 blocked | Docker/WSL unavailable; no fake JWT, backend mock or fabricated PASS substitutes |
| New native clean/additive rehearsals | SQL component evidence | SQL claims are fixtures, not GoTrue authentication or safeupdate/full-lineage acceptance |
| New `verify_pr82_appointment_e2e.py` | Must run on exact integrated CI SHA | Actual GoTrue password login, PostgREST named arguments, concurrency, receipts and A/B boundaries; explicitly not a browser UI test |

The original 36-case forensic matrix remains in the independent audit artifact
`10_E2E_36_TEST_FORENSIC_MATRIX.csv`. Its classifications are not overwritten by
unrelated unit tests or later backend acceptance checks. The final external audit
continuation records actual run SHA, timestamps, logs and CI conclusions.

Eight browser blockers: synthetic Admin login; CMS review using the actual server
hash; Admin approval/publication; User A publication denial; A/B private-resource
isolation; published search; draft exclusion; forward rollback. A future replay
must use real authorized disposable users, valid server sessions and actual UI
actions, then assert persisted database receipts/state and public/private visibility.
Route navigation and screenshots alone cannot satisfy those assertions. Fixtures
must say SYNTHETIC/NOT ADVICE and must never be treated as verified legal claims.

No local runtime restart is authorized. A fresh non-disruptive Docker check found
the Linux-engine named pipe absent. The native audit cluster is independently
owned and loopback-only; the shared running PostgreSQL Windows service is not
adopted or reset. Local full GoTrue/PostgREST/safeupdate/browser acceptance remains
blocked even if independently owned GitHub CI can run the full disposable stack.
