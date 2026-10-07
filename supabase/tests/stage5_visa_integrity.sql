-- Stage 5 integrity checks (run against production/staging)
SELECT 'orphan_requirements' AS check, count(*)::int AS n FROM visa_program_requirements r
WHERE NOT EXISTS (SELECT 1 FROM visa_programs p WHERE p.id = r.program_id);
SELECT 'orphan_steps' AS check, count(*)::int AS n FROM visa_program_steps s
WHERE NOT EXISTS (SELECT 1 FROM visa_programs p WHERE p.id = s.program_id);
SELECT 'dup_program_slug' AS check, count(*)::int AS n FROM (
  SELECT slug FROM visa_programs GROUP BY slug HAVING count(*) > 1) t;
SELECT 'dup_dest_code' AS check, count(*)::int AS n FROM (
  SELECT code FROM destinations GROUP BY code HAVING count(*) > 1) t;
SELECT 'dest_without_en_fa' AS check, count(*)::int AS n FROM destinations d
WHERE (SELECT count(DISTINCT locale) FROM destination_localizations dl WHERE dl.destination_id = d.id AND locale IN ('en','fa')) < 2;
SELECT 'prog_without_en_fa' AS check, count(*)::int AS n FROM visa_programs p
WHERE (SELECT count(DISTINCT locale) FROM visa_program_localizations l WHERE l.program_id = p.id AND locale IN ('en','fa')) < 2;
SELECT 'feed' AS check, count(*)::int AS n FROM feed_items;
