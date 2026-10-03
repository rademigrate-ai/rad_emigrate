# Remaining Product Roadmap

This roadmap records future work after the current codebase has been stabilized and the incomplete Project 07 audit blockers have been resolved. No phase below is marked complete by this document.

## PROJECT 08 — Production Verification and Deployment

- Clean-clone verification and reproducible migrations
- CI validation for formatting, analysis, tests, and web build
- Production hosting and environment variables
- Supabase redirect URLs
- Real signup/login and profile CRUD smoke tests
- Application CRUD and document upload/download/delete tests
- Multi-user isolation and browser route tests
- Deployment verification

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