import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final fa = lookupAppLocalizations(const Locale('fa'));

  test('document labels and assistant suggestions exist in EN and FA', () {
    final english = [
      en.documentTypePassport,
      en.documentTypeIdentity,
      en.documentTypeEducation,
      en.documentTypeFinancial,
      en.documentTypeVisa,
      en.documentTypeOther,
      en.documentStatusMissing,
      en.documentStatusUploaded,
      en.documentStatusUnderReview,
      en.documentStatusVerified,
      en.documentStatusRejected,
      en.suggestionStudyPermitDocuments,
      en.suggestionVisaProcessingTime,
      en.suggestionGteStatement,
      en.aiUnavailableResponse('Question'),
    ];
    final persian = [
      fa.documentTypePassport,
      fa.documentTypeIdentity,
      fa.documentTypeEducation,
      fa.documentTypeFinancial,
      fa.documentTypeVisa,
      fa.documentTypeOther,
      fa.documentStatusMissing,
      fa.documentStatusUploaded,
      fa.documentStatusUnderReview,
      fa.documentStatusVerified,
      fa.documentStatusRejected,
      fa.suggestionStudyPermitDocuments,
      fa.suggestionVisaProcessingTime,
      fa.suggestionGteStatement,
      fa.aiUnavailableResponse('پرسش'),
    ];

    expect(english.every((value) => value.trim().isNotEmpty), isTrue);
    expect(persian.every((value) => value.trim().isNotEmpty), isTrue);
    for (var index = 0; index < english.length; index++) {
      expect(persian[index], isNot(english[index]));
    }
  });

  test('document localization keys remain mirrored in both ARB files', () {
    final enArb = jsonDecode(
      File('lib/l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final faArb = jsonDecode(
      File('lib/l10n/app_fa.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    const keys = [
      'documentTypePassport',
      'documentTypeIdentity',
      'documentTypeEducation',
      'documentTypeFinancial',
      'documentTypeVisa',
      'documentTypeOther',
      'documentStatusMissing',
      'documentStatusUploaded',
      'documentStatusUnderReview',
      'documentStatusVerified',
      'documentStatusRejected',
      'aiUnavailableResponse',
    ];

    for (final key in keys) {
      expect(enArb[key], isA<String>(), reason: 'missing EN key: $key');
      expect(faArb[key], isA<String>(), reason: 'missing FA key: $key');
    }
  });

  test('Stage 1 AI and research strings are complete in EN and FA', () {
    final english = [
      en.adminAiConfig,
      en.providerModelConnection,
      en.credentialsServerOnly,
      en.testProvider,
      en.discoverModels,
      en.runtimeScope,
      en.researchSource,
      en.queueResearchRun,
      en.adminResearchAssistant,
      en.untrustedResearchDisclaimer,
    ];
    final persian = [
      fa.adminAiConfig,
      fa.providerModelConnection,
      fa.credentialsServerOnly,
      fa.testProvider,
      fa.discoverModels,
      fa.runtimeScope,
      fa.researchSource,
      fa.queueResearchRun,
      fa.adminResearchAssistant,
      fa.untrustedResearchDisclaimer,
    ];
    expect(english.every((value) => value.trim().isNotEmpty), isTrue);
    expect(persian.every((value) => value.trim().isNotEmpty), isTrue);
    for (var index = 0; index < english.length; index++) {
      expect(persian[index], isNot(english[index]));
    }
  });
}
