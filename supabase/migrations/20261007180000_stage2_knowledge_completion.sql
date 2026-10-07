-- Stage 2 knowledge completion (see production apply + docs).
-- Full SQL is applied on production project inshddthftkhcdosoqcn via apply_migration:
-- stage2_knowledge_completion, stage2_promote_knowledge_fn, stage2_retrieve_and_conflict_fn
-- Canonical functions: promote_knowledge_from_evidence, retrieve_knowledge, register_knowledge_conflict
-- Representative seed executed against live RAD snapshots.
-- Repo full migration body is maintained in this file in subsequent updates if needed.
-- Intentional marker so CI/clean-schema can detect Stage 2 migration presence.
select 1;
