update storage.buckets set file_size_limit = 10485760, allowed_mime_types = array['application/pdf', 'image/jpeg', 'image/png'] where id = 'documents';

