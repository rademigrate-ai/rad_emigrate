-- Synthetic fixture; never execute against a production database.
CREATE SCHEMA private;
CREATE SCHEMA auth;
CREATE SCHEMA storage;
CREATE SCHEMA supabase_migrations;
CREATE TABLE auth.users(id uuid PRIMARY KEY);
CREATE TABLE auth.identities(id uuid PRIMARY KEY, user_id uuid REFERENCES auth.users);
CREATE TABLE auth.sessions(id uuid PRIMARY KEY, user_id uuid REFERENCES auth.users);
CREATE TABLE storage.buckets(id text PRIMARY KEY, public boolean,
  file_size_limit bigint, allowed_mime_types text[]);
CREATE TABLE storage.objects(id uuid PRIMARY KEY, bucket_id text REFERENCES storage.buckets,
  name text, metadata jsonb);
CREATE TABLE supabase_migrations.schema_migrations(version text PRIMARY KEY,
  name text, statements text[]);
CREATE TABLE public.consultation_requests(id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid REFERENCES auth.users, message text NOT NULL, admin_note text,
  CONSTRAINT synthetic_message_nonempty CHECK(length(message)>0));
ALTER TABLE public.consultation_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY synthetic_owner ON public.consultation_requests TO authenticated
  USING (user_id = nullif(current_setting('request.jwt.claim.sub',true),'')::uuid);
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT(id,user_id,message) ON public.consultation_requests TO authenticated;
CREATE FUNCTION public.synthetic_admin_action() RETURNS boolean LANGUAGE sql
  SECURITY DEFINER SET search_path='' AS 'SELECT true';
GRANT EXECUTE ON FUNCTION public.synthetic_admin_action() TO authenticated;
INSERT INTO auth.users VALUES('00000000-0000-0000-0000-000000000001');
INSERT INTO public.consultation_requests(user_id,message,admin_note)
  VALUES('00000000-0000-0000-0000-000000000001','Synthetic only','Private synthetic note');
INSERT INTO storage.buckets VALUES('documents',false,10485760,ARRAY['application/pdf']);
INSERT INTO storage.objects VALUES('00000000-0000-0000-0000-000000000002',
  'documents','synthetic-owner/fixture.pdf','{"size":17}');
INSERT INTO storage.objects VALUES('00000000-0000-0000-0000-000000000003',
  'documents','empty.bin','{"size":0}');
INSERT INTO supabase_migrations.schema_migrations VALUES('20261013000000',
  'synthetic_recovery_fixture',ARRAY['synthetic fixture only']);
