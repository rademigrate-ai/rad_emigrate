create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

insert into storage.buckets (id, name, public)
values ('documents', 'documents', false)
on conflict (id) do nothing;

drop policy if exists "Users can upload own documents" on storage.objects;
drop policy if exists "Users can view own documents" on storage.objects;
drop policy if exists "Users can delete own documents" on storage.objects;

create policy "Users can upload own documents"
on storage.objects for insert
with check (
  bucket_id = 'documents'
  and auth.uid()::text = (storage.foldername(name))[1]
);

create policy "Users can view own documents"
on storage.objects for select
using (
  bucket_id = 'documents'
  and auth.uid()::text = (storage.foldername(name))[1]
);

create policy "Users can delete own documents"
on storage.objects for delete
using (
  bucket_id = 'documents'
  and auth.uid()::text = (storage.foldername(name))[1]
);

