-- Stage 2: structured visa_program_steps from RAD first-party process guidance.
-- Only high-level application process steps confirmed on RAD/DigiVisa content.
-- No fabricated fees, processing times, or legal eligibility guarantees.
begin;

-- study-canada steps (source digivisa.ir study-in-canada / RAD services)
insert into public.visa_program_steps (
  program_id, locale, title, description, display_order, source_id
)
select p.id, x.locale, x.title, x.description, x.ord,
  '10000000-0000-4000-8000-000000000005'::uuid
from public.visa_programs p
cross join (values
  ('fa','مشاوره و ارزیابی پرونده','بررسی شرایط متقاضی و انتخاب مسیر تحصیلی مناسب با راهنمایی راد.',10),
  ('fa','دریافت پذیرش تحصیلی','دریافت نامه پذیرش رسمی از مؤسسه آموزشی معتبر کانادا.',20),
  ('fa','آماده‌سازی مدارک','گردآوری مدارک تحصیلی، زبان، تمکن مالی و سایر اسناد موردنیاز پرونده.',30),
  ('fa','درخواست مجوز تحصیل','ثبت درخواست Study Permit و پیگیری وضعیت پرونده.',40),
  ('fa','پیگیری پس از تصمیم','هماهنگی برای سفر، ثبت‌نام و گام‌های پس از اخذ مجوز در صورت تأیید.',50),
  ('en','Consultation and profile review','Review the applicant profile and select an appropriate study pathway with RAD guidance.',10),
  ('en','Obtain an offer of admission','Receive a formal letter of acceptance from a designated learning institution in Canada.',20),
  ('en','Prepare supporting documents','Assemble academic, language, financial and other application documents.',30),
  ('en','Apply for a study permit','Submit the study permit application and track the case status.',40),
  ('en','Post-decision follow-up','Coordinate travel, enrolment and next steps if the permit is approved.',50)
) x(locale, title, description, ord)
where p.slug = 'study-canada'
  and not exists (
    select 1 from public.visa_program_steps s
    where s.program_id = p.id and s.locale = x.locale and s.display_order = x.ord
  );

-- work-germany high-level steps (RAD digivisa work-in-germany coverage)
insert into public.visa_program_steps (
  program_id, locale, title, description, display_order, source_id
)
select p.id, x.locale, x.title, x.description, x.ord,
  '10000000-0000-4000-8000-000000000006'::uuid
from public.visa_programs p
cross join (values
  ('fa','ارزیابی مسیر کاری','بررسی سابقه، مدرک و مسیرهای کاری منتشرشده برای آلمان.',10),
  ('fa','تکمیل مدارک حرفه‌ای','آماده‌سازی مدارک شغلی، تحصیلی و ترجمه موردنیاز پرونده.',20),
  ('fa','پیگیری پیشنهاد یا معادل‌سازی','هماهنگی پیشنهاد شغلی یا مراحل معادل‌سازی در صورت نیاز مسیر.',30),
  ('fa','درخواست ویزای کاری','ثبت درخواست ویزا و پیگیری مراحل اداری.',40),
  ('en','Assess the work pathway','Review experience, credentials and published work pathways for Germany.',10),
  ('en','Prepare professional documents','Assemble employment, education and certified translations as required.',20),
  ('en','Job offer or recognition steps','Coordinate a job offer or recognition steps when the route requires them.',30),
  ('en','Apply for a work visa','Submit the visa application and follow administrative progress.',40)
) x(locale, title, description, ord)
where p.slug = 'work-germany'
  and not exists (
    select 1 from public.visa_program_steps s
    where s.program_id = p.id and s.locale = x.locale and s.display_order = x.ord
  );

-- study-australia / study-united-kingdom generic study service steps (RAD study visa content)
insert into public.visa_program_steps (
  program_id, locale, title, description, display_order, source_id
)
select p.id, x.locale, x.title, x.description, x.ord,
  '10000000-0000-4000-8000-000000000001'::uuid
from public.visa_programs p
cross join (values
  ('fa','مشاوره مسیر تحصیلی','بررسی هدف تحصیلی و انتخاب کشور و مقطع مناسب.',10),
  ('fa','پذیرش آموزشی','پیگیری پذیرش از مرکز آموزشی مرتبط.',20),
  ('fa','مدارک پرونده','آماده‌سازی مدارک تحصیلی، زبان و مالی متناسب با مسیر.',30),
  ('fa','درخواست ویزای تحصیلی','ثبت درخواست ویزا و پیگیری نتیجه.',40),
  ('en','Study pathway consultation','Review study goals and select an appropriate country and level.',10),
  ('en','Educational admission','Pursue admission from a relevant educational institution.',20),
  ('en','Case documents','Prepare academic, language and financial documents for the route.',30),
  ('en','Study visa application','Submit the visa application and track the outcome.',40)
) x(locale, title, description, ord)
where p.slug in ('study-australia', 'study-united-kingdom')
  and not exists (
    select 1 from public.visa_program_steps s
    where s.program_id = p.id and s.locale = x.locale and s.display_order = x.ord
  );

-- medical-study-germany
insert into public.visa_program_steps (
  program_id, locale, title, description, display_order, source_id
)
select p.id, x.locale, x.title, x.description, x.ord,
  '10000000-0000-4000-8000-000000000008'::uuid
from public.visa_programs p
cross join (values
  ('fa','مشاوره تحصیل پزشکی','بررسی شرایط ورود به مسیرهای تحصیل پزشکی منتشرشده توسط راد.',10),
  ('fa','پذیرش و پیش‌نیازها','پیگیری پذیرش و پیش‌نیازهای زبانی یا علمی مسیر انتخابی.',20),
  ('fa','مدارک و درخواست','آماده‌سازی مدارک و ثبت درخواست مرتبط با مسیر.',30),
  ('en','Medical study consultation','Review published RAD medical study pathways and entry conditions.',10),
  ('en','Admission and prerequisites','Pursue admission and language or academic prerequisites for the route.',20),
  ('en','Documents and application','Prepare documents and submit the related application.',30)
) x(locale, title, description, ord)
where p.slug = 'medical-study-germany'
  and not exists (
    select 1 from public.visa_program_steps s
    where s.program_id = p.id and s.locale = x.locale and s.display_order = x.ord
  );

-- Expand requirements for remaining published programs where missing (high-level only)
insert into public.visa_program_requirements (
  program_id, locale, requirement, is_mandatory, display_order, source_id
)
select p.id, x.locale, x.requirement, x.is_mandatory, x.ord, p.primary_source_id
from public.visa_programs p
cross join (values
  ('fa','مدارک هویتی و گذرنامه معتبر',true,10),
  ('fa','مدارک پشتیبان متناسب با مسیر انتخابی',null,20),
  ('fa','بررسی الزامات جاری مرجع رسمی کشور مقصد',true,30),
  ('en','Valid identity documents and passport',true,10),
  ('en','Supporting documents appropriate to the selected pathway',null,20),
  ('en','Verify current requirements with the destination authority',true,30)
) x(locale, requirement, is_mandatory, ord)
where p.status = 'published'
  and not exists (
    select 1 from public.visa_program_requirements r
    where r.program_id = p.id and r.locale = x.locale
  );

commit;
