/// Visa catalog integrity checks — never invent eligibility, fees, or timelines.
///
/// Empty or incomplete catalog data must surface as incomplete/unverified,
/// not as complete official guidance.
library;

import 'entities/visa_entities.dart';

enum VisaDataCompleteness {
  complete,
  partial,
  empty,
  contradictory,
  unverified,
}

class VisaIntegrityReport {
  const VisaIntegrityReport({
    required this.completeness,
    required this.issues,
    this.safeForGuidance = false,
  });

  final VisaDataCompleteness completeness;
  final List<String> issues;
  final bool safeForGuidance;
}

class VisaCatalogIntegrity {
  const VisaCatalogIntegrity();

  VisaIntegrityReport evaluateProgram(VisaProgram program) {
    final issues = <String>[];

    if (program.title.trim().isEmpty) {
      issues.add('missing_title');
    }
    if (program.countryId.trim().isEmpty) {
      issues.add('missing_country');
    }
    if (program.summary.trim().isEmpty &&
        (program.description == null || program.description!.trim().isEmpty)) {
      issues.add('missing_description');
    }
    if (program.requirements.isEmpty) {
      issues.add('missing_requirements');
    }
    if (program.steps.isEmpty) {
      issues.add('missing_steps');
    }

    // Processing time and fees are never treated as verified without source.
    if (program.processingTime != null &&
        program.processingTime!.trim().isNotEmpty &&
        !_hasUsableSource(program.source)) {
      issues.add('processing_time_unverified');
    }
    if (program.fees != null &&
        program.fees!.trim().isNotEmpty &&
        !_hasUsableSource(program.source)) {
      issues.add('fees_unverified');
    }

    if (!_hasUsableSource(program.source)) {
      issues.add('source_unverified');
    }

    // Contradictory: mandatory requirement with empty text.
    for (final r in program.requirements) {
      if ((r.isMandatory ?? false) && r.text.trim().isEmpty) {
        issues.add('contradictory_mandatory_empty');
      }
    }

    if (issues.contains('contradictory_mandatory_empty')) {
      return VisaIntegrityReport(
        completeness: VisaDataCompleteness.contradictory,
        issues: issues,
        safeForGuidance: false,
      );
    }

    if (issues.contains('source_unverified') ||
        issues.contains('fees_unverified') ||
        issues.contains('processing_time_unverified')) {
      return VisaIntegrityReport(
        completeness: VisaDataCompleteness.unverified,
        issues: issues,
        safeForGuidance: false,
      );
    }

    if (issues.isEmpty) {
      return const VisaIntegrityReport(
        completeness: VisaDataCompleteness.complete,
        issues: [],
        safeForGuidance: true,
      );
    }

    if (program.summary.isEmpty &&
        program.requirements.isEmpty &&
        program.steps.isEmpty) {
      return VisaIntegrityReport(
        completeness: VisaDataCompleteness.empty,
        issues: issues,
        safeForGuidance: false,
      );
    }

    return VisaIntegrityReport(
      completeness: VisaDataCompleteness.partial,
      issues: issues,
      safeForGuidance: false,
    );
  }

  VisaIntegrityReport evaluateCountry(Country country) {
    final issues = <String>[];
    if (country.name.trim().isEmpty) issues.add('missing_name');
    if (country.code.trim().isEmpty) issues.add('missing_code');
    if (country.summary.trim().isEmpty) issues.add('missing_summary');

    if (issues.isEmpty) {
      return const VisaIntegrityReport(
        completeness: VisaDataCompleteness.complete,
        issues: [],
        // Country summary alone is not program guidance.
        safeForGuidance: false,
      );
    }
    if (country.summary.isEmpty && country.name.isEmpty) {
      return VisaIntegrityReport(
        completeness: VisaDataCompleteness.empty,
        issues: issues,
        safeForGuidance: false,
      );
    }
    return VisaIntegrityReport(
      completeness: VisaDataCompleteness.partial,
      issues: issues,
      safeForGuidance: false,
    );
  }

  bool _hasUsableSource(VisaSource source) {
    final url = source.url.trim();
    if (url.isEmpty) return false;
    if (!url.startsWith('https://')) return false;
    if (source.title.trim().isEmpty) return false;
    if (source.publisher.trim().isEmpty) return false;
    return true;
  }
}
