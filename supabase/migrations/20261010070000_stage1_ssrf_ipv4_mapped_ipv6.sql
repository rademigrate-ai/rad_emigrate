-- F-05: close IPv4-mapped/compatible IPv6 SSRF representations in the
-- database-side provider URL validator. Existing migrations are immutable;
-- this is a forward-only replacement.
begin;

create or replace function private.is_safe_public_https_url(p_url text)
returns boolean
language plpgsql
immutable
set search_path = ''
as $function$
declare
  v_authority text;
  v_host text;
  v_addr inet;
begin
  if p_url is null or p_url !~* '^https://' then
    return false;
  end if;

  v_authority := split_part(split_part(substring(p_url from 9), '/', 1), '?', 1);
  if v_authority = '' or v_authority like '%@%' or position('%' in v_authority) > 0 then
    return false;
  end if;

  if left(v_authority, 1) = '[' then
    if position(']' in v_authority) = 0 then
      return false;
    end if;
    v_host := substring(v_authority from 2 for position(']' in v_authority) - 2);
  else
    v_host := split_part(v_authority, ':', 1);
  end if;
  v_host := lower(rtrim(v_host, '.'));
  if v_host = '' or v_host ~ '^[0-9]+$' then
    return false;
  end if;

  -- PostgreSQL inet parsing covers compressed and canonical IPv6 spellings.
  begin
    v_addr := v_host::inet;
  exception when invalid_text_representation then
    v_addr := null;
  end;

  if v_addr is not null then
    if family(v_addr) = 6 then
      -- Reject IPv4-compatible (::/96) and IPv4-mapped (::ffff:0:0/96)
      -- literals outright, including hexadecimal and compressed spellings.
      if v_addr << inet '::/96' or v_addr << inet '::ffff:0:0/96' then
        return false;
      end if;
      if v_addr << inet '::1/128' or v_addr << inet 'fe80::/10' or
         v_addr << inet 'fc00::/7' or v_addr << inet 'ff00::/8' then
        return false;
      end if;
    else
      if v_addr << inet '0.0.0.0/8' or v_addr << inet '10.0.0.0/8' or
         v_addr << inet '100.64.0.0/10' or v_addr << inet '127.0.0.0/8' or
         v_addr << inet '169.254.0.0/16' or v_addr << inet '172.16.0.0/12' or
         v_addr << inet '192.0.0.0/24' or v_addr << inet '192.0.2.0/24' or
         v_addr << inet '192.168.0.0/16' or v_addr << inet '198.18.0.0/15' or
         v_addr << inet '198.51.100.0/24' or v_addr << inet '203.0.113.0/24' or
         v_addr << inet '224.0.0.0/4' then
        return false;
      end if;
    end if;
    return true;
  end if;

  if v_host in (
    'localhost',
    'localhost.localdomain',
    'metadata.google.internal',
    'metadata',
    '0.0.0.0'
  ) then
    return false;
  end if;
  if v_host like '%.localhost' or v_host like '%.local' or
     v_host like '%.internal' or v_host like '%.home.arpa' then
    return false;
  end if;
  return true;
end
$function$;

alter function private.is_safe_public_https_url(text) owner to postgres;
revoke all on function private.is_safe_public_https_url(text) from public, anon, authenticated;

commit;
