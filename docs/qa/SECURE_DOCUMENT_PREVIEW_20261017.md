# Private document preview — security design and release acceptance

Parent: RAD ONE MASTER TASK [#57](https://github.com/rademigrate-ai/rad_emigrate/issues/57), component E4-03.

## What changed (review branch only)
- The Documents detail sheet offers a localized **Open file / مشاهده فایل** action for an uploaded file.
- On explicit user tap, the current Auth session, document ownership and the exact three-segment private Storage path are checked before requesting a **new 300-second signed URL**. Supabase Storage RLS remains the final authorization boundary.
- No preview URL is built from a user-provided arbitrary URL, from a cached remote fileUrl, or from a Storage path with traversal, percent-encoded separators, hash/query components or a different user folder.
- The signed URL is handed only to the device's external viewer on user action; the UI never logs or shows it.
- **Privacy remediation:** old document-list mapping generated signed URLs eagerly and `DocumentLocalDataSource` persisted the `fileUrl` in `SharedPreferences`. Listing no longer generates signed URLs. New cache writes redact `fileUrl`; legacy cache entries are scrubbed upon next local cache read.
- No bucket made public, no service-role credentials, no Storage policy relaxation, no migrations, no production writes.

## Verification performed locally
- `flutter analyze --no-pub`: 0 issues.
- `flutter test --no-pub test/core/document_private_preview_path_test.dart test/documents/document_signed_url_cache_test.dart`: 5 tests pass (owned path, cross-user denial, path traversal/URL rejection, no persisted new token, legacy token scrub).
- Existing workflow full suite, Web/Android compilation and real private Storage owner/nonowner browser tests remain required before release.

## Manual acceptance / negative cases before E4-03 can be Done
- Sign in as controlled user A, upload PDF/JPEG/PNG to private documents bucket, tap Open file, verify it opens once and expires in about 5 minutes; relaunch produces a fresh URL.
- User B cannot list, sign or view user A's private files, even with forged storage path/document ID.
- Direct anonymous access to the bucket, tampered owner prefix, path traversal, and expired URLs remain denied by RLS and signing.
- Reload/sign out and verify preview bearer tokens are not saved in browser preferences, logs, local files, analytics or URL error messages.
- Web popup restrictions, Android external viewer and iOS device opening, cancellation and network error states all verified.
- Ensure no document processing/OCR claim is made: that processor is currently disabled in Production.

**Production acceptance:** NOT VERIFIED. PR must remain review-only pending full CI and live controlled-user tests.
