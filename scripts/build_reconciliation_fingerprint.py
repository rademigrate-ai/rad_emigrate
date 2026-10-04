"""Generate the single-result catalog query from the existing forensic SQL."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
source = root / 'supabase/reconciliation/production_fingerprint.sql'
queries = re.sub(r'^--.*$', '', source.read_text(), flags=re.M).split(';')
names = ['history', 'tables', 'columns', 'constraints', 'rls', 'policies',
         'indexes', 'functions', 'triggers', 'table_grants', 'column_grants',
         'buckets', 'cron', 'extensions', 'vault_metadata', 'ai_providers',
         'ai_models', 'search_providers', 'document_processor', 'research_sources']
queries = [q.strip() for q in queries if q.strip()]
assert len(queries) == len(names)
# Generated identities, extension versions, and secret metadata are environment
# differences. Preserve them in the raw fingerprint; classify them explicitly.
queries[names.index('vault_metadata')] = 'select name from vault.secrets order by name'
queries[names.index('research_sources')] = 'select base_url, allowed_host, authority, enabled, minimum_interval from public.research_sources order by base_url'
extra = {
    'schemas': "select nspname, pg_get_userbyid(nspowner) as owner, nspacl::text from pg_namespace where nspname in ('public','private') order by nspname",
    'types': "select n.nspname, t.typname, e.enumsortorder, e.enumlabel from pg_type t join pg_namespace n on n.oid=t.typnamespace join pg_enum e on e.enumtypid=t.oid where n.nspname in ('public','private') order by 1,2,3",
    'function_grants': "select n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) as args, pg_get_userbyid(p.proowner) as owner, coalesce(p.proacl, acldefault('f',p.proowner))::text as acl from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private') order by 1,2,3",
    'table_acl': "select n.nspname,c.relname,pg_get_userbyid(c.relowner) as owner,coalesce(c.relacl,acldefault((case when c.relkind='S' then 's' else 'r' end)::\"char\",c.relowner))::text as acl from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','private') and c.relkind in ('r','p','S','v','m') order by 1,2",
    'views': "select n.nspname,c.relname,c.reloptions,pg_get_viewdef(c.oid,true) as definition from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','private') and c.relkind in ('v','m') order by 1,2",
    'sequences': "select schemaname,sequencename,data_type,start_value,min_value,max_value,increment_by,cycle,cache_size from pg_sequences where schemaname in ('public','private') order by 1,2",
    'default_acl': "select pg_get_userbyid(d.defaclrole) as owner,n.nspname,d.defaclobjtype,d.defaclacl::text from pg_default_acl d left join pg_namespace n on n.oid=d.defaclnamespace where n.nspname in ('public','private') order by 1,2,3",
    'vault_client_access': "select r.rolname,has_schema_privilege(r.rolname,'vault','USAGE') as schema_usage,has_table_privilege(r.rolname,'vault.secrets','SELECT') as encrypted_read,has_table_privilege(r.rolname,'vault.decrypted_secrets','SELECT') as decrypted_read from pg_roles r where r.rolname in ('anon','authenticated') order by 1",
}
names.extend(extra)
queries.extend(extra.values())
parts = []
for name, query in zip(names, queries):
    parts.append("'" + name + "', (select coalesce(jsonb_agg(to_jsonb(q) order by to_jsonb(q)::text),'[]'::jsonb) from (" + query + ") q)")
target = root / 'supabase/reconciliation/catalog_fingerprint.sql'
target.write_text('-- Metadata only. No Vault values or application/user data.\nselect jsonb_build_object(\n' + ',\n'.join(parts) + '\n) as fingerprint;\n')
