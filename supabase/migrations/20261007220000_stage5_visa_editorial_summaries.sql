-- Stage 5: evidence-safe destination summaries + program descriptions (idempotent)
-- Only fills empty/null text; never invents fees, scores, processing times, or eligibility guarantees.

UPDATE destination_localizations dl
SET summary = CASE dl.locale
  WHEN 'en' THEN d.name_en || ' appears in the RAD destination catalog for immigration and international-education consultation. Availability of specific visa routes and eligibility rules must be confirmed against current official government sources before any application.'
  WHEN 'fa' THEN d.name_fa || ' در فهرست مقاصد راد برای مشاوره مهاجرت و تحصیل بین‌المللی قرار دارد. وجود مسیرهای ویزا و شرایط واجدشرایط بودن باید پیش از هر اقدام با منابع رسمی دولتی جاری تأیید شود.'
  ELSE dl.summary
END
FROM (
  SELECT destination_id,
    max(CASE WHEN locale='en' THEN name END) AS name_en,
    max(CASE WHEN locale='fa' THEN name END) AS name_fa
  FROM destination_localizations GROUP BY destination_id
) d
WHERE dl.destination_id = d.destination_id
  AND (dl.summary IS NULL OR length(trim(dl.summary)) = 0);

UPDATE visa_program_localizations l
SET description = CASE
  WHEN p.slug = 'study-canada' AND l.locale = 'en' THEN
    'This RAD catalog entry covers study pathways in Canada. RAD provides consultation and guidance based on published service content. Study permit eligibility, designated learning institutions, financial requirements, and processing rules are set by Immigration, Refugees and Citizenship Canada (IRCC) and change over time. Always verify current official rules before applying.'
  WHEN p.slug = 'study-canada' AND l.locale = 'fa' THEN
    'این ورودی فهرست راد مسیرهای تحصیل در کانادا را پوشش می‌دهد. راد بر اساس محتوای خدماتی منتشرشده مشاوره و راهنمایی ارائه می‌کند. شرایط مجوز تحصیل، مؤسسات آموزشی تعیین‌شده، الزامات مالی و قواعد رسیدگی توسط اداره مهاجرت کانادا (IRCC) تعیین می‌شود و ممکن است تغییر کند. پیش از اقدام، قواعد رسمی جاری را بررسی کنید.'
  WHEN p.slug = 'tourist-canada' AND l.locale = 'en' THEN
    'This entry covers Canada visitor (temporary resident) visa topics as listed in RAD service content. Visitor eligibility, biometrics, and supporting documents are governed by IRCC. RAD does not guarantee outcomes; confirm current official requirements before applying.'
  WHEN p.slug = 'tourist-canada' AND l.locale = 'fa' THEN
    'این ورودی موضوعات ویزای بازدیدکننده (اقامت موقت) کانادا را مطابق محتوای خدماتی راد پوشش می‌دهد. شرایط واجدشرایط بودن، بیومتریک و مدارک پشتیبان تحت نظارت IRCC است. راد نتیجه‌ای را تضمین نمی‌کند؛ پیش از اقدام الزامات رسمی جاری را تأیید کنید.'
  WHEN p.slug = 'investment-canada' AND l.locale = 'en' THEN
    'This entry refers to Canada investment-related immigration topics published in RAD/DigiVisa content. Investment and business immigration pathways change frequently and require case-specific official assessment. Do not treat this catalog summary as current eligibility advice.'
  WHEN p.slug = 'investment-canada' AND l.locale = 'fa' THEN
    'این ورودی به موضوعات مهاجرت سرمایه‌گذاری کانادا در محتوای راد/دیجی‌ویزا اشاره دارد. مسیرهای سرمایه‌گذاری و کسب‌وکار به‌طور مکرر تغییر می‌کنند و نیازمند ارزیابی رسمی موردی هستند. این خلاصه را به‌عنوان مشاوره واجدشرایط بودن جاری تلقی نکنید.'
  WHEN p.slug = 'work-germany' AND l.locale = 'en' THEN
    'This entry covers work pathways in Germany as discussed in RAD published content. Work visa categories, recognition of qualifications, and employment conditions are set by German federal authorities and can change. Verify current official guidance before applying.'
  WHEN p.slug = 'work-germany' AND l.locale = 'fa' THEN
    'این ورودی مسیرهای کار در آلمان را مطابق محتوای منتشرشده راد پوشش می‌دهد. انواع ویزای کار، معادل‌سازی مدارک و شرایط اشتغال توسط مراجع فدرال آلمان تعیین می‌شود و ممکن است تغییر کند. پیش از اقدام راهنمایی رسمی جاری را بررسی کنید.'
  WHEN p.slug = 'medical-study-germany' AND l.locale = 'en' THEN
    'This entry covers medical study topics in Germany based on RAD specialist content. University admission, language requirements, and residence rules for study are set by German institutions and authorities. Confirm current official criteria with the target university and competent authorities.'
  WHEN p.slug = 'medical-study-germany' AND l.locale = 'fa' THEN
    'این ورودی موضوعات تحصیل پزشکی در آلمان را بر اساس محتوای تخصصی راد پوشش می‌دهد. پذیرش دانشگاه، الزامات زبان و قواعد اقامت تحصیلی توسط مؤسسات و مراجع آلمانی تعیین می‌شود. معیارهای رسمی جاری را با دانشگاه مقصد و مراجع صالح تأیید کنید.'
  WHEN p.slug = 'credential-recognition-germany' AND l.locale = 'en' THEN
    'This entry covers medical credential recognition in Germany as described in RAD specialist content. Recognition procedures are administered by competent German authorities and vary by profession and state. This is not a substitute for official recognition guidance.'
  WHEN p.slug = 'credential-recognition-germany' AND l.locale = 'fa' THEN
    'این ورودی معادل‌سازی مدارک پزشکی در آلمان را مطابق محتوای تخصصی راد پوشش می‌دهد. فرآیندهای معادل‌سازی توسط مراجع صالح آلمانی انجام می‌شود و بر اساس حرفه و ایالت متفاوت است. این متن جایگزین راهنمایی رسمی معادل‌سازی نیست.'
  WHEN p.slug = 'study-united-kingdom' AND l.locale = 'en' THEN
    'This entry covers study topics in the United Kingdom based on RAD service content. Student visa rules, sponsorship, and financial requirements are set by UK authorities and change over time. Verify current official guidance before applying.'
  WHEN p.slug = 'study-united-kingdom' AND l.locale = 'fa' THEN
    'این ورودی موضوعات تحصیل در بریتانیا را بر اساس محتوای خدماتی راد پوشش می‌دهد. قواعد ویزای دانشجویی، اسپانسری و الزامات مالی توسط مراجع بریتانیا تعیین می‌شود و ممکن است تغییر کند. پیش از اقدام راهنمایی رسمی جاری را بررسی کنید.'
  WHEN p.slug = 'medical-work-united-kingdom' AND l.locale = 'en' THEN
    'This entry covers medical work topics in the United Kingdom based on RAD published guidance. Professional registration, visa categories, and employer requirements are set by UK professional and immigration authorities. Confirm current official rules for your profession.'
  WHEN p.slug = 'medical-work-united-kingdom' AND l.locale = 'fa' THEN
    'این ورودی موضوعات کار پزشکی در بریتانیا را بر اساس راهنمایی منتشرشده راد پوشش می‌دهد. ثبت حرفه‌ای، انواع ویزا و الزامات کارفرما توسط مراجع حرفه‌ای و مهاجرتی بریتانیا تعیین می‌شود. قواعد رسمی جاری را برای حرفه خود تأیید کنید.'
  WHEN p.slug = 'study-australia' AND l.locale = 'en' THEN
    'This entry covers study topics in Australia based on RAD service content. Student visa subclasses and education provider rules are set by the Australian Government and change over time. Verify current official requirements before applying.'
  WHEN p.slug = 'study-australia' AND l.locale = 'fa' THEN
    'این ورودی موضوعات تحصیل در استرالیا را بر اساس محتوای خدماتی راد پوشش می‌دهد. زیرکلاس‌های ویزای دانشجویی و قواعد ارائه‌دهندگان آموزشی توسط دولت استرالیا تعیین می‌شود و ممکن است تغییر کند. پیش از اقدام الزامات رسمی جاری را بررسی کنید.'
  WHEN p.slug = 'medical-work-sweden' AND l.locale = 'en' THEN
    'This entry covers medical work and credential topics in Sweden based on RAD content. Professional licensing and residence permits are governed by Swedish authorities. Confirm current official requirements for your profession and pathway.'
  WHEN p.slug = 'medical-work-sweden' AND l.locale = 'fa' THEN
    'این ورودی موضوعات کار پزشکی و معادل‌سازی در سوئد را بر اساس محتوای راد پوشش می‌دهد. مجوز حرفه‌ای و اجازه اقامت تحت نظارت مراجع سوئدی است. الزامات رسمی جاری را برای حرفه و مسیر خود تأیید کنید.'
  ELSE l.description
END
FROM visa_programs p
WHERE l.program_id = p.id
  AND (l.description IS NULL OR length(trim(l.description)) < 20);
