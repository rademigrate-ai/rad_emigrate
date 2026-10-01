-- Project 06: enforce the hardened empty search path on the signup trigger.
alter function public.handle_new_user() set search_path = '';
