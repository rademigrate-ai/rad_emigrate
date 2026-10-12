# RC validation defect/fix list

| Finding | Evidence | Disposition |
|---|---|---|
| Browser harness final sentence claimed consultation submission in form-only mode | First-run log disagreed with its `PARTIAL` manifest | **FIXED:** conditional output; final 41-capture run repeated and accurately labelled |
| Local browser stack lacks consultation RPC | Read-only latest migration `20261010070000`; `to_regprocedure(...) = false` | **BLOCKED:** form/navigation tested; submission not run; no migration applied |
| Google Flutter engine artifact endpoint returns 403 | Direct versioned POM HEAD 403 and prior Gradle failure | **RESOLVED FOR DEBUG BUILD:** documented mirror POM 200; APK built and hashed; no security checks disabled |
| Wide full-page mobile PNG on Consultation/AI | 656/809px PNG widths; document viewport and scroll width both 390px | **FOLLOW-UP, not a confirmed visible app defect:** Flutter semantics/input overlay expands body bounds; accessibility impact unverified |
| Flutter application defects | 41 route captures, zero unexpected console/page errors, visual samples and 325 passing widget/unit tests | **NONE CONFIRMED** in tested scope; consultation submission and device install remain unverified |
