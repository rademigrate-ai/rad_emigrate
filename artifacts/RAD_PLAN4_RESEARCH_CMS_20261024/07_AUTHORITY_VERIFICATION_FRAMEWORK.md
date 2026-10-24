# 07 — AUTHORITY VERIFICATION FRAMEWORK

## 1. Official Authority Registry

The Authority Verification Framework establishes an immutable, legally certified directory of institutions competent to issue official immigration regulations, educational recognitions, occupational accreditations, and visa requirements.

### Authority Entity Schema
```dart
class Authority {
  final String id;                    // UUID
  final String name;                  // Official legal name
  final String authorityType;         // See Authority Types below
  final String? countryCode;          // ISO 3166-1 alpha-2 (e.g. CA, DE, AU)
  final String jurisdiction;          // Federal, Provincial/State, Municipal
  final List<String> competenceTopics;// ['immigration', 'student_visa', 'points_test']
  final List<String> officialDomains; // Whitelisted egress domains (['canada.ca'])
  final String verificationState;     // verified, provisional, expired, blacklisted
  final int verificationRevision;     // Optimistic counter
  final DateTime? verifiedAt;         // Legal compliance signoff date
  final DateTime? expiresAt;          // Re-certification expiry
}
```

---

## 2. Standardized Authority Types

Only explicitly recognized entity types defined in `supabase/contracts/rad_v1.json` are permitted:

1. `government`: Sovereign ministries and departments (e.g., IRCC, Department of Home Affairs).
2. `embassy`: Diplomatic missions and consular sections abroad.
3. `university`: Designated learning institutions (DLIs) and accredited higher-education bodies.
4. `regulator`: Professional governing councils (e.g., Engineers Australia, Medical Council of Canada).
5. `accreditor`: National qualifications recognition frameworks (e.g., ZAB in Germany, WES in Canada).
6. `licensing_body`: Provincial/territorial professional licensing boards.
7. `credential_evaluator`: Officially designated educational credential assessment organizations.
8. `other_competent_body`: Recognized statutory immigration appeal tribunals.

---

## 3. Lifecycle & Refresh Mechanisms

1. **Discovery (`discover_official_authorities`):**
   Administrators can trigger automated authority discovery by specifying a target `country_code` and `topic`. The backend worker queries sovereign registries, validates domain ownership via WHOIS/DNSSEC records, and stages provisional authority records for administrative vetting.
2. **On-Demand Crawl Refresh (`enqueue_research_refresh`):**
   Administrators can select specific authorities in `AdminSourceMonitorPage` and dispatch immediate refresh tasks. The system utilizes idempotency keys (`request_key`) to deduplicate simultaneous requests, preventing denial-of-service against official government portals.
3. **Expiry & Invalidation:**
   If `DateTime.now()` exceeds `expiresAt`, the client UI automatically flags the authority as `منقضی‌شده` (Expired) and raises a review alert in the admin console.
