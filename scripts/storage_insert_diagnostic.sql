CREATE OR REPLACE FUNCTION public.project08_storage_insert_diagnostic()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE LOG 'PROJECT08_STORAGE_DIAGNOSTIC bucket_id=%, name=%, owner_id=%, auth.uid()=%, auth.role()=%',
    NEW.bucket_id,
    NEW.name,
    NEW.owner_id,
    auth.uid(),
    auth.role();
  RAISE EXCEPTION 'PROJECT08_STORAGE_DIAGNOSTIC captured in disposable Postgres logs';
END
$$;

DROP TRIGGER IF EXISTS project08_storage_insert_diagnostic ON storage.objects;
CREATE TRIGGER project08_storage_insert_diagnostic
BEFORE INSERT ON storage.objects
FOR EACH ROW
EXECUTE FUNCTION public.project08_storage_insert_diagnostic();
