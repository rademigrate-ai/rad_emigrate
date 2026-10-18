# User AI Citation Contract

Response `sources[]`: title, url, authority, optional retrieved_at, excerpt, claim_label.

UI maps sources to AiSource (title/url/authority). URLs not translated. No internal DB ids or secrets.

Citations come only from explicitly approved, current claims under explicitly approved, query-matched Knowledge items. Source URLs must parse as absolute HTTP(S) URLs without embedded username/password; other schemes and malformed URLs are omitted. URLs are normalized for deduplication, with at most 12 returned sources. This validation does not independently establish source authority, freshness or factual accuracy.
