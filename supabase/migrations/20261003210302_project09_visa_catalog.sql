-- Project 09: source-backed visa and RAD service catalogue.
-- Regulatory facts intentionally remain reviewable; this seed contains only
-- service categories and claims present on RAD-owned sites at retrieval time.

begin;

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to anon, authenticated, service_role;

alter table public.profiles
  add column if not exists role text not null default 'user'
  check (role in ('user', 'admin', 'super_admin'));

revoke update on table public.profiles from authenticated;
grant update (full_name, email, phone, country, updated_at)
  on table public.profiles to authenticated;

create or replace function private.has_role(required_roles text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role = any(required_roles)
  );
$function$;

alter function private.has_role(text[]) owner to postgres;
revoke all on function private.has_role(text[]) from public;
grant execute on function private.has_role(text[]) to anon, authenticated, service_role;

create table public.content_sources (
  id uuid primary key default gen_random_uuid(),
  publisher text not null,
  source_type text not null check (
    source_type in ('rad_official', 'government', 'embassy', 'institution', 'other')
  ),
  title text not null,
  url text not null unique,
  language_code text not null default 'fa' check (language_code in ('fa', 'en')),
  published_at timestamptz,
  retrieved_at timestamptz not null default now(),
  content_hash text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.destinations (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[A-Z]{2}$'),
  slug text not null unique check (slug ~ '^[a-z0-9-]+$'),
  flag_emoji text,
  status text not null default 'draft'
    check (status in ('draft', 'review', 'published', 'archived')),
  display_order integer not null default 0,
  created_by uuid references auth.users(id) on delete set null,
  reviewed_by uuid references auth.users(id) on delete set null,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.destination_localizations (
  destination_id uuid not null references public.destinations(id) on delete cascade,
  locale text not null check (locale in ('fa', 'en')),
  name text not null,
  summary text,
  primary key (destination_id, locale)
);

create table public.program_categories (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9-]+$'),
  status text not null default 'draft'
    check (status in ('draft', 'review', 'published', 'archived')),
  display_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.program_category_localizations (
  category_id uuid not null references public.program_categories(id) on delete cascade,
  locale text not null check (locale in ('fa', 'en')),
  name text not null,
  description text,
  primary key (category_id, locale)
);

create table public.visa_programs (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9-]+$'),
  destination_id uuid not null references public.destinations(id),
  category_id uuid not null references public.program_categories(id),
  primary_source_id uuid not null references public.content_sources(id),
  status text not null default 'draft'
    check (status in ('draft', 'review', 'published', 'archived')),
  processing_time_text text,
  fees_text text,
  effective_date date,
  revision integer not null default 1 check (revision > 0),
  created_by uuid references auth.users(id) on delete set null,
  reviewed_by uuid references auth.users(id) on delete set null,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (destination_id, category_id, slug)
);

create table public.visa_program_localizations (
  program_id uuid not null references public.visa_programs(id) on delete cascade,
  locale text not null check (locale in ('fa', 'en')),
  title text not null,
  summary text not null,
  description text,
  primary key (program_id, locale)
);

create table public.visa_program_requirements (
  id uuid primary key default gen_random_uuid(),
  program_id uuid not null references public.visa_programs(id) on delete cascade,
  locale text not null check (locale in ('fa', 'en')),
  requirement text not null,
  is_mandatory boolean,
  display_order integer not null default 0,
  source_id uuid not null references public.content_sources(id),
  created_at timestamptz not null default now()
);

create table public.visa_program_steps (
  id uuid primary key default gen_random_uuid(),
  program_id uuid not null references public.visa_programs(id) on delete cascade,
  locale text not null check (locale in ('fa', 'en')),
  title text not null,
  description text,
  display_order integer not null default 0,
  source_id uuid not null references public.content_sources(id),
  created_at timestamptz not null default now()
);

create table public.admin_audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  resource_type text not null,
  resource_id text,
  safe_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index destinations_status_order_idx
  on public.destinations (status, display_order);
create index program_categories_status_order_idx
  on public.program_categories (status, display_order);
create index visa_programs_public_filter_idx
  on public.visa_programs (status, destination_id, category_id, published_at desc);
create index visa_program_requirements_program_locale_idx
  on public.visa_program_requirements (program_id, locale, display_order);
create index visa_program_steps_program_locale_idx
  on public.visa_program_steps (program_id, locale, display_order);
create index admin_audit_logs_resource_idx
  on public.admin_audit_logs (resource_type, resource_id, created_at desc);

alter table public.content_sources enable row level security;
alter table public.destinations enable row level security;
alter table public.destination_localizations enable row level security;
alter table public.program_categories enable row level security;
alter table public.program_category_localizations enable row level security;
alter table public.visa_programs enable row level security;
alter table public.visa_program_localizations enable row level security;
alter table public.visa_program_requirements enable row level security;
alter table public.visa_program_steps enable row level security;
alter table public.admin_audit_logs enable row level security;

revoke all on table
  public.content_sources,
  public.destinations,
  public.destination_localizations,
  public.program_categories,
  public.program_category_localizations,
  public.visa_programs,
  public.visa_program_localizations,
  public.visa_program_requirements,
  public.visa_program_steps,
  public.admin_audit_logs
from anon, authenticated;

grant select on table
  public.content_sources,
  public.destinations,
  public.destination_localizations,
  public.program_categories,
  public.program_category_localizations,
  public.visa_programs,
  public.visa_program_localizations,
  public.visa_program_requirements,
  public.visa_program_steps
to anon, authenticated;

grant insert, update, delete on table
  public.content_sources,
  public.destinations,
  public.destination_localizations,
  public.program_categories,
  public.program_category_localizations,
  public.visa_programs,
  public.visa_program_localizations,
  public.visa_program_requirements,
  public.visa_program_steps
to authenticated;

grant select on table public.admin_audit_logs to authenticated;
grant usage, select on sequence public.admin_audit_logs_id_seq to service_role;
grant all privileges on table
  public.content_sources,
  public.destinations,
  public.destination_localizations,
  public.program_categories,
  public.program_category_localizations,
  public.visa_programs,
  public.visa_program_localizations,
  public.visa_program_requirements,
  public.visa_program_steps,
  public.admin_audit_logs
to service_role;

create policy "destinations published read" on public.destinations
  for select to anon, authenticated
  using (status = 'published' or (select private.has_role(array['admin','super_admin'])));
create policy "destination localizations published read" on public.destination_localizations
  for select to anon, authenticated
  using (exists (
    select 1 from public.destinations d
    where d.id = destination_id
      and (d.status = 'published' or (select private.has_role(array['admin','super_admin'])))
  ));
create policy "categories published read" on public.program_categories
  for select to anon, authenticated
  using (status = 'published' or (select private.has_role(array['admin','super_admin'])));
create policy "category localizations published read" on public.program_category_localizations
  for select to anon, authenticated
  using (exists (
    select 1 from public.program_categories c
    where c.id = category_id
      and (c.status = 'published' or (select private.has_role(array['admin','super_admin'])))
  ));
create policy "programs published read" on public.visa_programs
  for select to anon, authenticated
  using (status = 'published' or (select private.has_role(array['admin','super_admin'])));
create policy "program localizations published read" on public.visa_program_localizations
  for select to anon, authenticated
  using (exists (
    select 1 from public.visa_programs p
    where p.id = program_id
      and (p.status = 'published' or (select private.has_role(array['admin','super_admin'])))
  ));
create policy "requirements published read" on public.visa_program_requirements
  for select to anon, authenticated
  using (exists (
    select 1 from public.visa_programs p
    where p.id = program_id
      and (p.status = 'published' or (select private.has_role(array['admin','super_admin'])))
  ));
create policy "steps published read" on public.visa_program_steps
  for select to anon, authenticated
  using (exists (
    select 1 from public.visa_programs p
    where p.id = program_id
      and (p.status = 'published' or (select private.has_role(array['admin','super_admin'])))
  ));
create policy "sources referenced by published content" on public.content_sources
  for select to anon, authenticated
  using (
    (select private.has_role(array['admin','super_admin']))
    or exists (
      select 1 from public.visa_programs p
      where p.primary_source_id = content_sources.id and p.status = 'published'
    )
    or exists (
      select 1 from public.visa_program_requirements r
      join public.visa_programs p on p.id = r.program_id
      where r.source_id = content_sources.id and p.status = 'published'
    )
  );

create policy "admins manage destinations" on public.destinations
  for all to authenticated
  using ((select private.has_role(array['admin','super_admin'])))
  with check ((select private.has_role(array['admin','super_admin'])));
create policy "admins manage destination localizations" on public.destination_localizations
  for all to authenticated
  using ((select private.has_role(array['admin','super_admin'])))
  with check ((select private.has_role(array['admin','super_admin'])));
create policy "admins manage categories" on public.program_categories
  for all to authenticated
  using ((select private.has_role(array['admin','super_admin'])))
  with check ((select private.has_role(array['admin','super_admin'])));
create policy "admins manage category localizations" on public.program_category_localizations
  for all to authenticated
  using ((select private.has_role(array['admin','super_admin'])))
  with check ((select private.has_role(array['admin','super_admin'])));
create policy "admins manage programs" on public.visa_programs
  for all to authenticated
  using ((select private.has_role(array['admin','super_admin'])))
  with check ((select private.has_role(array['admin','super_admin'])));
create policy "admins manage program localizations" on public.visa_program_localizations
  for all to authenticated
  using ((select private.has_role(array['admin','super_admin'])))
  with check ((select private.has_role(array['admin','super_admin'])));
create policy "admins manage requirements" on public.visa_program_requirements
  for all to authenticated
  using ((select private.has_role(array['admin','super_admin'])))
  with check ((select private.has_role(array['admin','super_admin'])));
create policy "admins manage steps" on public.visa_program_steps
  for all to authenticated
  using ((select private.has_role(array['admin','super_admin'])))
  with check ((select private.has_role(array['admin','super_admin'])));
create policy "admins manage sources" on public.content_sources
  for all to authenticated
  using ((select private.has_role(array['admin','super_admin'])))
  with check ((select private.has_role(array['admin','super_admin'])));
create policy "super admins read audit" on public.admin_audit_logs
  for select to authenticated
  using ((select private.has_role(array['super_admin'])));

insert into public.content_sources (id, publisher, source_type, title, url, language_code, retrieved_at)
values
  ('10000000-0000-4000-8000-000000000001', 'RAD International Institute', 'rad_official', 'ویزای تحصیلی', 'https://radvisa.com/content/%D9%88%DB%8C%D8%B2%D8%A7%DB%8C-%D8%AA%D8%AD%D8%B5%DB%8C%D9%84%DB%8C', 'fa', '2026-10-03T19:30:00Z'),
  ('10000000-0000-4000-8000-000000000002', 'RAD International Institute', 'rad_official', 'ویزای کاری', 'https://radvisa.com/content/%D9%88%DB%8C%D8%B2%D8%A7%DB%8C-%DA%A9%D8%A7%D8%B1%DB%8C', 'fa', '2026-10-03T19:30:00Z'),
  ('10000000-0000-4000-8000-000000000003', 'RAD International Institute', 'rad_official', 'ویزای سرمایه گذاری', 'https://radvisa.com/content/%D9%88%DB%8C%D8%B2%D8%A7%DB%8C-%D8%B3%D8%B1%D9%85%D8%A7%DB%8C%D9%87-%DA%AF%D8%B0%D8%A7%D8%B1%DB%8C', 'fa', '2026-10-03T19:30:00Z'),
  ('10000000-0000-4000-8000-000000000004', 'RAD International Institute', 'rad_official', 'معادل سازی مدارک پزشکی در خارج از کشور', 'https://radvisa.com/content/%D9%85%D8%B9%D8%A7%D8%AF%D9%84-%D8%B3%D8%A7%D8%B2%DB%8C-%D9%85%D8%AF%D8%A7%D8%B1%DA%A9-%D9%BE%D8%B2%D8%B4%DA%A9%DB%8C', 'fa', '2026-10-03T19:30:00Z'),
  ('10000000-0000-4000-8000-000000000005', 'RAD International Institute', 'rad_official', 'شرایط تحصیل در کانادا 2025', 'https://digivisa.ir/content/%D8%AA%D8%AD%D8%B5%DB%8C%D9%84-%D8%AF%D8%B1-%DA%A9%D8%A7%D9%86%D8%A7%D8%AF%D8%A7', 'fa', '2026-10-03T19:30:00Z'),
  ('10000000-0000-4000-8000-000000000006', 'RAD International Institute', 'rad_official', 'کار در آلمان در سال 2025', 'https://digivisa.ir/content/%DA%A9%D8%A7%D8%B1-%D8%AF%D8%B1-%D8%A2%D9%84%D9%85%D8%A7%D9%86', 'fa', '2026-10-03T19:30:00Z'),
  ('10000000-0000-4000-8000-000000000007', 'RAD International Institute', 'rad_official', 'سرمایه گذاری در کانادا 2025', 'https://digivisa.ir/content/%D8%B3%D8%B1%D9%85%D8%A7%DB%8C%D9%87-%DA%AF%D8%B0%D8%A7%D8%B1%DB%8C-%D8%AF%D8%B1-%DA%A9%D8%A7%D9%86%D8%A7%D8%AF%D8%A7', 'fa', '2026-10-03T19:30:00Z'),
  ('10000000-0000-4000-8000-000000000008', 'RAD International Institute', 'rad_official', 'روش های مهاجرت و فهرست کشورها', 'https://radmohajer.ir/fa/', 'fa', '2026-10-03T19:30:00Z')
on conflict (url) do nothing;

with rows(code, slug, flag, fa_name, en_name, ord) as (values
  ('AT','austria','🇦🇹','اتریش','Austria',10), ('AU','australia','🇦🇺','استرالیا','Australia',20),
  ('BE','belgium','🇧🇪','بلژیک','Belgium',30), ('CA','canada','🇨🇦','کانادا','Canada',40),
  ('CH','switzerland','🇨🇭','سوئیس','Switzerland',50), ('DE','germany','🇩🇪','آلمان','Germany',60),
  ('DK','denmark','🇩🇰','دانمارک','Denmark',70), ('ES','spain','🇪🇸','اسپانیا','Spain',80),
  ('FI','finland','🇫🇮','فنلاند','Finland',90), ('FR','france','🇫🇷','فرانسه','France',100),
  ('GB','united-kingdom','🇬🇧','انگلستان','United Kingdom',110), ('IT','italy','🇮🇹','ایتالیا','Italy',120),
  ('JP','japan','🇯🇵','ژاپن','Japan',130), ('MY','malaysia','🇲🇾','مالزی','Malaysia',140),
  ('NL','netherlands','🇳🇱','هلند','Netherlands',150), ('NO','norway','🇳🇴','نروژ','Norway',160),
  ('NZ','new-zealand','🇳🇿','نیوزیلند','New Zealand',170), ('OM','oman','🇴🇲','عمان','Oman',180),
  ('SE','sweden','🇸🇪','سوئد','Sweden',190), ('TR','turkey','🇹🇷','ترکیه','Turkey',200),
  ('US','united-states','🇺🇸','آمریکا','United States',210), ('AE','united-arab-emirates','🇦🇪','امارات','United Arab Emirates',220)
), inserted as (
  insert into public.destinations (code, slug, flag_emoji, status, display_order, published_at)
  select code, slug, flag, 'published', ord, now() from rows
  on conflict (code) do update set slug = excluded.slug
  returning id, code
)
insert into public.destination_localizations (destination_id, locale, name)
select i.id, l.locale, case when l.locale = 'fa' then r.fa_name else r.en_name end
from inserted i join rows r using (code)
cross join (values ('fa'),('en')) l(locale)
on conflict (destination_id, locale) do nothing;

with rows(slug, fa_name, en_name, fa_desc, en_desc, ord) as (values
  ('study','ویزای تحصیلی','Study visa','پذیرش تحصیلی و مسیر ویزای مرتبط','Educational admission and the related visa pathway',10),
  ('work','ویزای کاری','Work visa','مسیرهای کاری منتشرشده توسط راد','Work pathways published by RAD',20),
  ('investment','سرمایه‌گذاری','Investment','مسیرهای سرمایه‌گذاری نیازمند بررسی به‌روز','Investment pathways requiring current review',30),
  ('tourist','ویزای توریستی','Visitor visa','راهنمای سفر و ویزای توریستی','Visitor and tourist visa guidance',40),
  ('marriage','ازدواج','Marriage','اطلاعات عمومی مسیرهای مبتنی بر ازدواج','General information about marriage-based pathways',50),
  ('medical-study','تحصیل پزشکی','Medical study','خدمات تحصیل پزشکی، دندانپزشکی و رشته‌های وابسته','Medical, dental and related study services',60),
  ('medical-work','کار کادر درمان','Healthcare work','مهاجرت کاری پزشکان، دندانپزشکان و پیراپزشکان','Work migration for doctors, dentists and allied health professionals',70),
  ('credential-recognition','معادل‌سازی مدارک','Credential recognition','فرایندهای معادل‌سازی مدارک پزشکی','Medical credential recognition pathways',80)
), inserted as (
  insert into public.program_categories (slug, status, display_order)
  select slug, 'published', ord from rows
  on conflict (slug) do update set display_order = excluded.display_order
  returning id, slug
)
insert into public.program_category_localizations (category_id, locale, name, description)
select i.id, l.locale,
  case when l.locale = 'fa' then r.fa_name else r.en_name end,
  case when l.locale = 'fa' then r.fa_desc else r.en_desc end
from inserted i join rows r using (slug)
cross join (values ('fa'),('en')) l(locale)
on conflict (category_id, locale) do nothing;

with rows(slug, destination_slug, category_slug, source_id, fa_title, en_title, fa_summary, en_summary, ord) as (values
  ('study-canada','canada','study','10000000-0000-4000-8000-000000000005'::uuid,'تحصیل در کانادا','Study in Canada','راد درباره پذیرش و مسیر تحصیل در کانادا محتوای تخصصی منتشر کرده است. جزئیات باید پیش از اقدام با منابع رسمی به‌روز تطبیق داده شود.','RAD publishes guidance on admission and study pathways in Canada. Details must be checked against current official sources before action.',10),
  ('work-germany','germany','work','10000000-0000-4000-8000-000000000006'::uuid,'کار در آلمان','Work in Germany','راد درباره مسیرهای کار در آلمان محتوا منتشر کرده است. شرایط هر مسیر وابسته به سابقه و مقررات جاری است.','RAD publishes information about work pathways in Germany. Eligibility depends on the applicant and current rules.',20),
  ('investment-canada','canada','investment','10000000-0000-4000-8000-000000000007'::uuid,'سرمایه‌گذاری در کانادا','Investment in Canada','این موضوع در دیجی‌ویزا منتشر شده و به دلیل تغییرپذیری برنامه‌ها نیازمند بازبینی رسمی پیش از استفاده است.','This topic is published by DigiVisa and requires official review because programs change.',30),
  ('study-australia','australia','study','10000000-0000-4000-8000-000000000001'::uuid,'تحصیل در استرالیا','Study in Australia','راد استرالیا را در خدمات ویزای تحصیلی و تحصیل پزشکی پوشش می‌دهد.','RAD covers Australia in its study visa and medical education services.',40),
  ('study-united-kingdom','united-kingdom','study','10000000-0000-4000-8000-000000000001'::uuid,'تحصیل در انگلستان','Study in the United Kingdom','راد انگلستان را در خدمات تحصیلی و تحصیل پزشکی پوشش می‌دهد.','RAD covers the United Kingdom in its study and medical education services.',50),
  ('medical-study-germany','germany','medical-study','10000000-0000-4000-8000-000000000008'::uuid,'تحصیل پزشکی در آلمان','Medical study in Germany','تحصیل پزشکی در آلمان یکی از موضوعات منتشرشده در وب‌سایت‌های راد است.','Medical study in Germany is a published RAD topic.',60),
  ('medical-work-united-kingdom','united-kingdom','medical-work','10000000-0000-4000-8000-000000000008'::uuid,'کار پزشکان در انگلستان','Medical work in the United Kingdom','راد خدمات محتوایی مرتبط با کار پزشکان در انگلستان را منتشر کرده است.','RAD publishes services and guidance related to doctors working in the United Kingdom.',70),
  ('credential-recognition-germany','germany','credential-recognition','10000000-0000-4000-8000-000000000004'::uuid,'معادل‌سازی مدارک پزشکی در آلمان','Medical credential recognition in Germany','معادل‌سازی مدارک پزشکی در آلمان در محتوای تخصصی راد پوشش داده شده است.','Medical credential recognition in Germany is covered in RAD specialist content.',80),
  ('medical-work-sweden','sweden','medical-work','10000000-0000-4000-8000-000000000008'::uuid,'کار پزشکان در سوئد','Medical work in Sweden','راد مهاجرت کاری پزشکان و معادل‌سازی مدارک در سوئد را پوشش می‌دهد.','RAD covers medical work migration and credential recognition in Sweden.',90),
  ('tourist-canada','canada','tourist','10000000-0000-4000-8000-000000000008'::uuid,'ویزای توریستی کانادا','Canada visitor visa','ویزای توریستی کانادا در فهرست خدمات و محتوای راد مهاجر قرار دارد.','Canada visitor visas appear in RAD Mohajer services and content.',100)
), inserted as (
  insert into public.visa_programs (
    slug, destination_id, category_id, primary_source_id, status, published_at
  )
  select r.slug, d.id, c.id, r.source_id, 'published', now()
  from rows r
  join public.destinations d on d.slug = r.destination_slug
  join public.program_categories c on c.slug = r.category_slug
  on conflict (slug) do update set primary_source_id = excluded.primary_source_id
  returning id, slug
)
insert into public.visa_program_localizations (program_id, locale, title, summary)
select i.id, l.locale,
  case when l.locale = 'fa' then r.fa_title else r.en_title end,
  case when l.locale = 'fa' then r.fa_summary else r.en_summary end
from inserted i join rows r using (slug)
cross join (values ('fa'),('en')) l(locale)
on conflict (program_id, locale) do nothing;

insert into public.visa_program_requirements (
  program_id, locale, requirement, is_mandatory, display_order, source_id
)
select p.id, x.locale, x.requirement, x.is_mandatory, x.ord,
  '10000000-0000-4000-8000-000000000001'::uuid
from public.visa_programs p
cross join (values
  ('fa','پذیرش از دانشگاه یا مرکز آموزشی مرتبط',true,10),
  ('fa','مدارک تحصیلی و ریزنمرات متناسب با پرونده',null,20),
  ('fa','مدرک زبان یا مسیر جایگزین مورد قبول مؤسسه آموزشی',null,30),
  ('fa','مدارک تمکن مالی متناسب با الزامات جاری',null,40),
  ('en','Admission from the relevant educational institution',true,10),
  ('en','Academic records appropriate to the application',null,20),
  ('en','Language evidence or an accepted alternative pathway',null,30),
  ('en','Financial evidence required under current rules',null,40)
) x(locale, requirement, is_mandatory, ord)
where p.slug = 'study-canada';

create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  new.updated_at = now();
  return new;
end;
$function$;

create or replace function private.audit_content_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  resource text;
begin
  resource := case when tg_op = 'DELETE' then old.id::text else new.id::text end;
  insert into public.admin_audit_logs (
    actor_id, action, resource_type, resource_id, safe_metadata
  ) values (
    (select auth.uid()), lower(tg_op), tg_table_name, resource,
    jsonb_build_object(
      'status_before', case when tg_op in ('UPDATE','DELETE') then to_jsonb(old)->>'status' end,
      'status_after', case when tg_op in ('INSERT','UPDATE') then to_jsonb(new)->>'status' end
    )
  );
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$function$;

alter function private.audit_content_change() owner to postgres;
revoke all on function private.audit_content_change() from public, anon, authenticated;

create trigger content_sources_updated_at before update on public.content_sources
  for each row execute function private.set_updated_at();
create trigger destinations_updated_at before update on public.destinations
  for each row execute function private.set_updated_at();
create trigger categories_updated_at before update on public.program_categories
  for each row execute function private.set_updated_at();
create trigger programs_updated_at before update on public.visa_programs
  for each row execute function private.set_updated_at();

create trigger destinations_audit after insert or update or delete on public.destinations
  for each row execute function private.audit_content_change();
create trigger categories_audit after insert or update or delete on public.program_categories
  for each row execute function private.audit_content_change();
create trigger programs_audit after insert or update or delete on public.visa_programs
  for each row execute function private.audit_content_change();
create trigger sources_audit after insert or update or delete on public.content_sources
  for each row execute function private.audit_content_change();

