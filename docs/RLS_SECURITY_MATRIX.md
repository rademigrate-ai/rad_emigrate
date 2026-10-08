# RLS Matrix (representative)
| Table | RLS | Anon | User | Admin |
|-------|-----|------|------|-------|
| profiles | on | limited | own | role path |
| applications | on | deny | own | admin |
| documents | on | deny | own | admin |
| consultation_requests | on | deny | own insert/read | manage |
| notifications | on | deny | own | service write |
| ai_* | on | deny | own/session | service |
| ai_guest_quota | on | deny | deny | service |
| feed_items | on | read published | read | publish RPC |
