-- Stage 5 Visa integrity suite (executable)
-- All n expected 0 except feed which must be 0 as well.

SELECT 'orphan_requirements' AS chk,
  (SELECT count(*)::int FROM visa_program_requirements r
   WHERE NOT EXISTS (SELECT 1 FROM visa_programs p WHERE p.id = r.program_id)) AS n;

SELECT 'orphan_steps' AS chk,
  (SELECT count(*)::int FROM visa_program_steps s
   WHERE NOT EXISTS (SELECT 1 FROM visa_programs p WHERE p.id = s.program_id)) AS n;

SELECT 'orphan_programs' AS chk,
  (SELECT count(*)::int FROM visa_programs p
   WHERE NOT EXISTS (SELECT 1 FROM destinations d WHERE d.id = p.destination_id)) AS n;

SELECT 'dup_program_slug' AS chk,
  (SELECT count(*)::int FROM (SELECT slug FROM visa_programs GROUP BY slug HAVING count(*) > 1) t) AS n;

SELECT 'dup_dest_code' AS chk,
  (SELECT count(*)::int FROM (SELECT code FROM destinations GROUP BY code HAVING count(*) > 1) t) AS n;

SELECT 'dup_dest_slug' AS chk,
  (SELECT count(*)::int FROM (SELECT slug FROM destinations GROUP BY slug HAVING count(*) > 1) t) AS n;

SELECT 'req_order_dups' AS chk,
  (SELECT count(*)::int FROM (
     SELECT program_id, locale, display_order FROM visa_program_requirements
     GROUP BY 1,2,3 HAVING count(*) > 1) t) AS n;

SELECT 'step_order_dups' AS chk,
  (SELECT count(*)::int FROM (
     SELECT program_id, locale, display_order FROM visa_program_steps
     GROUP BY 1,2,3 HAVING count(*) > 1) t) AS n;

SELECT 'parent_child_published' AS chk,
  (SELECT count(*)::int FROM visa_programs p
   JOIN destinations d ON d.id = p.destination_id
   WHERE p.status = 'published' AND d.status <> 'published') AS n;

SELECT 'dest_locale_gap' AS chk,
  (SELECT count(*)::int FROM destinations d
   WHERE (SELECT count(DISTINCT locale) FROM destination_localizations dl
          WHERE dl.destination_id = d.id AND locale IN ('en','fa')) < 2) AS n;

SELECT 'prog_locale_gap' AS chk,
  (SELECT count(*)::int FROM visa_programs p
   WHERE (SELECT count(DISTINCT locale) FROM visa_program_localizations l
          WHERE l.program_id = p.id AND locale IN ('en','fa')) < 2) AS n;

SELECT 'feed' AS chk, (SELECT count(*)::int FROM feed_items) AS n;
