-- Disposable synthetic fixture only. This test must never be sent to hosted SQL.
begin;
insert into public.source_documents(id,canonical_url,source_authority,title,language_code)
values('d9000000-0000-4000-8000-000000000001','https://authority.example.invalid/audit','government','SYNTHETIC audit evidence','en');
insert into public.source_snapshots(id,document_id,normalized_text,content_hash,http_status,fetched_at)
values('f9000000-0000-4000-8000-000000000001','d9000000-0000-4000-8000-000000000001','SYNTHETIC audit evidence',encode(extensions.digest('SYNTHETIC audit evidence','sha256'),'hex'),200,now());
do $$ begin
 begin
  update public.source_snapshots set normalized_text='SYNTHETIC changed after evidence capture' where id='f9000000-0000-4000-8000-000000000001';
  raise exception 'AUDIT_MUTABLE_SOURCE_SNAPSHOT_ACCEPTED';
 exception when sqlstate 'PT409' then null;
 end;
end $$;
rollback;
