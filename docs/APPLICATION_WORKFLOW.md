# Application Workflow
Statuses: draft, submitted, reviewing, documents_required, approved, rejected, completed
User may INSERT as draft/submitted only; UPDATE status only draft→submitted
Admin/super_admin may set any status (trigger private.guard_application_status)
Existing production applications preserved (text destination/visa_type)
