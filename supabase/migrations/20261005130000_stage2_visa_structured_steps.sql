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

-- Other published programmes intentionally remain summary-only until their
-- programme-specific process and requirements are reviewed against a current
-- RAD primary source and the relevant destination authority. Do not populate
-- generic requirements: a plausible-sounding checklist is not evidence.

commit;
