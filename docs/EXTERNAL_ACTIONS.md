# External actions (owner)

These items are intentionally outside the engineering gate.

1. **Production host & DNS** — choose domain, TLS, CDN; do not deploy from this gate.
2. **Auth redirect URLs** — configure Supabase Auth site URL and redirects for the chosen host.
3. **Super Admin / Admin bootstrap** — after Auth users exist for `mehrshad.evol.b@gmail.com` (Super Admin) and `B.rad14@yahoo.com` (Admin), elevate via server-side role RPC only.
4. **Provider credentials** — AI/OCR/search keys in Vault only; never client-visible.
5. **App signing** — Android/iOS release keystores when mobile release is authorized.
6. **Legal copy** — Terms/Privacy final text from counsel.
7. **Optional APM** — external monitoring product if desired beyond Project 15 tables.
