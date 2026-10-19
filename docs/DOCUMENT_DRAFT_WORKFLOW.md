# RAD E8-04 — Offline CV and SOP draft workflow

**Scope:** user-editable plain-text **draft**, not an AI-generated immigration application or a government-approved document.

## Actual supported journey

1. Sign in and complete the profile. Open **Documents**.
2. Select the **Create CV or statement of purpose** toolbar action; deep link: `/documents/draft` (protected route).
3. Choose CV or Statement of Purpose. Complete the fields with **your own** information.
4. Select **Build editable draft**. The draft renders locally and remains editable in a text input.
5. Explicitly choose **Save as TXT** to export the exact edited draft using the platform save dialog, or **Copy edited text** to use it in a separate editor. Closing this page loses the unsaved draft by design; users are warned before entering data that no draft is automatically stored.

Persian (`fa`) and English (`en`) are supported. The mode uses the app's currently selected locale, not a guessed locale. Email and phone entries are left-to-right under RTL.

## Security, privacy, and claim boundaries

- `DocumentDraftGenerator` performs deterministic string assembly. **No network calls, AI provider, Supabase access, Storage API, logging, encryption key, persistence, or automatic publishing** are involved.
- User facts are **not inferred**. Missing CV sections are omitted; SOP requires an applicant, target program, personally authored motivation, preparation and goals. No invented institution, grades, work history, scholarship, fees, visa eligibility or guaranteed outcomes.
- Control characters, invalid email and unexpectedly long input are rejected with visible errors. The output is editable, and the user is explicitly told to verify every claim and official institutional requirements.
- **Saving TXT** and copying to the clipboard are **user-initiated actions**; they hand the data to the operating system's file picker/clipboard, where privacy and retention depend on the user/device. No automatic export occurs. A canceled save produces no success message.
- `/documents/draft` is an **explicit** protected route. Unknown nested document paths retain NotFound behavior, rather than broadly redirecting.
- This workflow can export UTF-8 TXT when the platform save dialog supports it. It does **not** promise PDF/DOCX export, template styling, cloud backup, digital signature, automatic source checking or live submission. These remain later product scope if approved.

## Reproducible tests

```bash
dart format --output=none --set-exit-if-changed lib/core/routing/auth_redirect.dart \
  lib/core/routing/app_router.dart \
  lib/features/documents/domain/document_draft_generator.dart \
  lib/features/documents/presentation/pages/document_draft_page.dart \
  lib/features/documents/presentation/pages/documents_page.dart \
  test/core/auth_redirect_test.dart test/documents/document_draft_generator_test.dart \
  test/documents/document_draft_widget_test.dart test/documents/document_sop_widget_test.dart

flutter analyze --no-pub

flutter test --no-pub test/core/auth_redirect_test.dart \
  test/documents/document_draft_generator_test.dart \
  test/documents/document_draft_widget_test.dart \
  test/documents/document_sop_widget_test.dart
```

The focused suite exercises generated text provenance, required fields and invalid input, Persian output, editable CV/SOP presentation and protected-route redirects. CI also runs the full Flutter test suite, Android/Web builds and backend schema checks. A local/test build is **not** equivalent to physical-device, browser, client or production acceptance.

**Master #57 E8-04:** partially implemented in source control, not VERIFIED_PASS until full product acceptance requirements (approved export variants, end-user review, accessibility, UAT) are met. **Production remains NO-GO.**
