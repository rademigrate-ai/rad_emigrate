# Security matrix

Read `docs/SECURITY_ACCEPTANCE_20261012.md` for requirement-by-requirement HEAD/production evidence. Local SQL scenarios S13–S17 pass. Production security is **FAIL**: migration `20261010010000` is absent; non-owner AI RPCs, `admin_note` confidentiality and human-only Feed publication are not yet protected live. The new consultation/Storage migration is also repository-only. Admin document downloading is not an implemented workflow; no broad Admin Storage grant was added. No production writes were made.
