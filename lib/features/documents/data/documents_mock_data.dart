import '../domain/entities/document_entities.dart';

const mockDocumentTypes = [
  DocumentType(
    id: 'passport',
    name: 'Passport',
    description: 'Valid passport bio page',
  ),
  DocumentType(
    id: 'photo',
    name: 'Photo',
    description: 'Passport-size photograph',
  ),
  DocumentType(
    id: 'education',
    name: 'Education Certificate',
    description: 'Diplomas and transcripts',
  ),
  DocumentType(
    id: 'language',
    name: 'Language Test',
    description: 'IELTS / TOEFL / PTE results',
  ),
  DocumentType(
    id: 'funds',
    name: 'Proof of Funds',
    description: 'Bank statements',
  ),
];

final mockDocuments = [
  DocumentItem(
    id: 'doc-1',
    typeId: 'passport',
    name: 'Passport',
    status: DocumentStatus.verified,
    updatedAt: DateTime(2026, 9, 10),
  ),
  DocumentItem(
    id: 'doc-2',
    typeId: 'photo',
    name: 'Photograph',
    status: DocumentStatus.uploaded,
    updatedAt: DateTime(2026, 9, 18),
  ),
  DocumentItem(
    id: 'doc-3',
    typeId: 'education',
    name: 'Bachelor Degree',
    status: DocumentStatus.underReview,
    updatedAt: DateTime(2026, 9, 22),
  ),
  DocumentItem(
    id: 'doc-4',
    typeId: 'language',
    name: 'IELTS Result',
    status: DocumentStatus.missing,
  ),
  DocumentItem(
    id: 'doc-5',
    typeId: 'funds',
    name: 'Bank Statement',
    status: DocumentStatus.missing,
  ),
];
