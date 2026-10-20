-- Align protected synchronous worker transport contracts with existing handlers.
-- No Edge Function, transport, deployment or feature flag is enabled here.
begin;
insert into private.rad_contract_schemas(name,schema) values('EdgeError','{"type":"object","properties":{"error":{"type":"string"},"code":{"type":"string"},"request_id":{"$ref":"#/$defs/UUID"}},"required":["error"],"additionalProperties":false}'::jsonb) on conflict(name) do update set schema=excluded.schema;
insert into private.rad_contract_schemas(name,schema) values('notification_dispatch_request','{"type":"object","properties":{"limit":{"type":"integer","minimum":1,"maximum":20}},"required":[],"additionalProperties":false}'::jsonb) on conflict(name) do update set schema=excluded.schema;
insert into private.rad_contract_schemas(name,schema) values('notification_dispatch_response','{"type":"object","properties":{"mode":{"const":"sandbox"},"claimed":{"type":"integer","minimum":0,"maximum":20},"sandbox_receipts":{"type":"integer","minimum":0,"maximum":20},"retry_scheduled":{"type":"integer","minimum":0,"maximum":20},"failed":{"type":"integer","minimum":0,"maximum":20},"stale":{"type":"integer","minimum":0,"maximum":20}},"required":["mode","claimed","sandbox_receipts","retry_scheduled","failed","stale"],"additionalProperties":false}'::jsonb) on conflict(name) do update set schema=excluded.schema;
commit;
