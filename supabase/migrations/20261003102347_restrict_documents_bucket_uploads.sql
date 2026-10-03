-- Defense in depth: enforce document upload restrictions at the bucket layer.
-- This migration is additive and safe for the existing RAD documents bucket.
UPDATE storage.buckets
SET file_size_limit = 10485760,
    allowed_mime_types = ARRAY['application/pdf', 'image/jpeg', 'image/png']
WHERE id = 'documents';
