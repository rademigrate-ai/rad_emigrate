create policy "worker config service only"
on public.research_worker_config
for all
to anon, authenticated
using (false)
with check (false);

