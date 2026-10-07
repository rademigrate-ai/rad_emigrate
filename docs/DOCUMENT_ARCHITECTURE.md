# Document Architecture
- Table: documents (user_id, name, status, file_path, application_id nullable)
- Storage bucket: documents (private, 10MB, pdf/jpeg/png)
- Path: {user_id}/{document_id}/{safe_name}
- Signed URL for read
- Flutter: DocumentsPage + DocumentRemoteDataSource + SupabaseStorageService
