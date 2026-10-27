-- Stage7.2 additive: seed candidate authorities for scraped reference domains.
-- Idempotent, fail-closed, does not verify or auto-approve.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';

insert into private.authority_entities(id,name,authority_type,country_code,jurisdiction,competence_topics,state)
values
 ('11000000-0000-4000-8000-000000000001','RadVisa Australian Immigration Reference','government','AU','AU',array['study','work','migration'],'candidate'),
 ('11000000-0000-4000-8000-000000000002','RadMohajer Iranian Immigration Reference','other_competent_body','IR','IR',array['study','work','migration'],'candidate'),
 ('11000000-0000-4000-8000-000000000003','DigiVisa Cross-Border Reference','other_competent_body','AU','AU',array['study','work','migration'],'candidate')
on conflict(id) do update set competence_topics=excluded.competence_topics,state=excluded.state;

insert into private.authority_domains(authority_id,host,path_prefix,state)
values
 ('11000000-0000-4000-8000-000000000001','radvisa.com','/','candidate'),
 ('11000000-0000-4000-8000-000000000002','radmohajer.ir','/','candidate'),
 ('11000000-0000-4000-8000-000000000003','digivisa.ir','/','candidate')
on conflict(authority_id,host,path_prefix) do update set state=excluded.state;

commit;
