# 06 — DATA INTEGRITY AND SECURITY

## 1. Authentication & Session Assertion

Administrative operations in `SupabaseAdminCmsRepository` enforce multi-layer session assertion:
1. **Repository Identity Lock:**
   Upon instantiation, the repository records `_owner = _service.client.auth.currentUser?.id`.
2. **Pre-flight & Post-flight Checks:**
   Before making an RPC call and immediately upon receiving a response, `_assertSession()` executes:
   ```dart
   void _assertSession() {
     if (!_service.isInitialized) throw const CmsException('unavailable');
     if (_owner == null || _service.client.auth.currentUser?.id != _owner) {
       throw const CmsException('unauthorized');
     }
   }
   ```
3. **Session Switching & Logout Defense:**
   If the authenticated user logs out, switches accounts, or if a background token expires while an HTTP request is in-flight, the late response is rejected with `CmsException('unauthorized')`. Stale data is never committed to client memory.

---

## 2. SSRF and Egress Security

The official source monitoring engine crawler is protected against Server-Side Request Forgery (SSRF) and untrusted egress:
1. **Private Subnet Denial:** Crawlers cannot connect to `127.0.0.1`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, cloud metadata services (`169.254.169.254`), or link-local addresses.
2. **Domain Whitelisting:** Crawlers only follow addresses whose hostnames match the approved `official_domains` array of a verified `Authority` record.
3. **HTTP Protocol Strictness:** Insecure plaintext `http://` protocols are explicitly rejected by URL parsers (`parseResearchSourceUrl`), requiring TLS 1.3 `https://`.

---

## 3. Cryptographic Verification & Auditability

1. **SHA-256 Content Hashing:**
   Every published revision, section change, and source snapshot is fingerprinted using a SHA-256 hash. Any manual database tampering breaks the hash chain, rendering the revision invalid upon audit.
2. **Immutable Revisions Table:**
   Edits do not overwrite existing rows in PostgreSQL. Every change appends a new row to `article_revisions`, preserving complete legal history for compliance, disputes, and regulatory auditing.
