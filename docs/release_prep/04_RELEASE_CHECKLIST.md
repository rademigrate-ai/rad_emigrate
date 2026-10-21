# Final release checklist (operational — not authorization)

## Automated (must pass on one SHA)

- [ ] `dart format --set-exit-if-changed lib test`
- [ ] `flutter analyze --no-pub`
- [ ] `flutter test --no-pub`
- [ ] Deno tests in `supabase/functions/tests`
- [ ] clean-schema + local auth isolation
- [ ] migration-reconstruction + fingerprint NO-GO audit stays honest
- [ ] repository keyword / secret scan
- [ ] web build with non-prod dart-defines
- [ ] android debug APK build
- [ ] Android release gate still rejects placeholder ID/signing in CI

## Owner-supplied (not inventable)

- [ ] Permanent Android applicationId
- [ ] Release keystore + `RAD_RELEASE_*` secrets in secure store (not git)
- [ ] Permanent iOS bundle ID + Apple team
- [ ] Hosting CSP / headers / rollback plan
- [ ] Supabase production migration reconciliation authorization
- [ ] Explicit Staging deploy authorization
- [ ] Explicit Production deploy authorization
- [ ] Store listing / privacy policy / data-safety disclosures

## Product invariants (must remain true)

- [ ] Human-only Feed publishing
- [ ] Immutable evidence snapshots
- [ ] AI text-only + quota reservation/settlement
- [ ] No fabricated FX / visa / fee data
- [ ] Private booking/appointment state bound to auth identity

## Gates

| Gate | Current |
|------|---------|
| Integration review | Pending final agent merge |
| Staging | **NO-GO** |
| Production | **NO-GO** |
