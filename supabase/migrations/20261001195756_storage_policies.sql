insert into storage.buckets (id, name, public) values ('documents', 'documents', false) on conflict (id) do update set public = false;
drop policy if exists "documents storage read own" on storage.objects;
drop policy if exists "documents storage upload own" on storage.objects;
drop policy if exists "documents storage delete own" on storage.objects;
create policy "documents storage read own" on storage.objects for select to authenticated using (bucket_id = 'documents' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "documents storage upload own" on storage.objects for insert to authenticated with check (bucket_id = 'documents' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "documents storage delete own" on storage.objects for delete to authenticated using (bucket_id = 'documents' and (storage.foldername(name))[1] = (select auth.uid())::text);

