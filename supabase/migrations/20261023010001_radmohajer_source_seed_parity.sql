-- Preserve the three established RAD Mohajer primary-source records on clean installs.
-- These metadata records already exist in Production; this migration does not add
-- snapshots or assert that page contents have been verified.
begin;

insert into public.source_documents(
  canonical_url, source_authority, title, language_code, jurisdiction
)
values
  ('https://radmohajer.ir/fa/contacts', 'rad_official', 'تماس با ما', 'fa', 'IR'),
  ('https://radmohajer.ir/en/contact-us', 'rad_official', 'Contact us', 'en', 'IR'),
  ('https://radmohajer.ir/en/about-us', 'rad_official', 'About us', 'en', 'IR')
on conflict (canonical_url) do nothing;

commit;
