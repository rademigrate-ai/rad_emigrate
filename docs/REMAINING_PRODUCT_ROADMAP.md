# Remaining Product Roadmap

Project 07 code hardening, CI, live security checks, and clean schema reconstruction are complete. Project 08 covers real account, hosting, and release verification that still needs the owner's production environment. No phase below is marked complete by this document.

## PROJECT 08 — Production Verification and Deployment

- Configure production hosting, environment values, and SPA rewrites to serve `index.html` for GoRouter paths
- Configure Supabase Auth redirect URLs
- Verify real signup/login, profile CRUD, and application CRUD
- Verify document upload/download/delete and multi-user isolation
- Run browser route tests and production deployment smoke checks
- Set the production Android package ID and release signing configuration

## PROJECT 09 — Visa and Product Data Layer

- Structured visa, country, program, and service catalog
- Authoritative source provenance and data freshness
- Content ownership and management model

## PROJECT 10 — RAD Knowledge Base

- Ingest RAD content from `radvisa.com`, `digivisa.ir`, and `radmohajer.ir/fa/`
- Ingest authoritative external sources
- Store source metadata, versions, citations, and freshness
- Add retrieval and governance workflows

## PROJECT 11 — AI Assistant Production

- Select an approved AI provider and implement a provider abstraction
- Ground responses in the RAD Knowledge Base
- Add citations, safety guardrails, rate limits, persistence, and cost controls

## PROJECT 12 — Document Intelligence

- Add OCR, extraction, classification, and validation
- Define processing states and a document intelligence pipeline

## PROJECT 13 — Operations and Admin

- Add staff/admin roles, user and case management
- Support document review, content/AI management, and audit logging

## PROJECT 14 — Client Workflow

- Add notifications, deadlines, case updates, document requests, checklists, and client communications

## PROJECT 15 — Observability and Analytics

- Add privacy-safe crash reporting, error monitoring, product events, performance monitoring, and operational metrics

## PROJECT 16 — Final Release QA

- Add integration and end-to-end tests
- Verify browser/device matrices and accessibility
- Run security regression and load/performance checks
- Complete a release checklist and production acceptance

Project numbering should be reconciled with the actual history before starting each phase.