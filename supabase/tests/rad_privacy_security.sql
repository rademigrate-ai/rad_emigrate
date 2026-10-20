begin;
do $$ declare sanitized jsonb;begin
 sanitized:=private.redact_safe_metadata('{"diagnostic":{"password":"NESTED_CANARY"},"status":[{"secret":"ARRAY_CANARY"}],"person@example.invalid":"KEY_CANARY","latency_ms":17,"retryable":true,"attempt_count":2,"safe_error_code":"provider_timeout"}');
 if sanitized::text like '%CANARY%' or sanitized::text like '%example.invalid%' then raise exception 'nested telemetry leak';end if;
 if sanitized->>'latency_ms'<>'17' or sanitized->>'retryable'<>'true' or sanitized->>'attempt_count'<>'2' then raise exception 'safe metrics lost';end if;
 if private.redact_safe_metadata(sanitized)<>sanitized then raise exception 'redaction not idempotent';end if;
 if private.redact_safe_metadata('null')->>'payload_rejected'<>'true' or private.redact_safe_metadata('[]')->>'payload_rejected'<>'true' then raise exception 'invalid telemetry accepted';end if;
 if exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname<>'has_role' and
 (has_function_privilege('anon',p.oid,'EXECUTE') or has_function_privilege('authenticated',p.oid,'EXECUTE'))) then raise exception 'private helper client EXECUTE';end if;
end $$;
set local role anon;
select set_config('request.jwt.claims','{"role":"anon"}',true);
do $$ declare result jsonb;begin
 result:=public.get_backend_contract_status('{}');
 if result->'data'->>'content'<>'false' or result->'data'->>'research'<>'false' or result->'data'->>'copilot'<>'false' then raise exception 'unapproved capability activation';end if;
end $$;
reset role;
rollback;
