// University Comparison domain entities.
//
// Accurately presents public university admission criteria and scholarship availability.
// Strictly avoids fabricating university partnerships or admission guarantees.

enum ScholarshipLevel { full, partial, competitive, none }

extension ScholarshipLevelX on ScholarshipLevel {
  String label(bool fa) => switch (this) {
    ScholarshipLevel.full =>
      fa ? 'بورسیه کامل (فول فاند)' : 'Full Scholarship (Fully Funded)',
    ScholarshipLevel.partial =>
      fa ? 'کمک‌هزینه و معافیت شهریه' : 'Partial / Tuition Waiver',
    ScholarshipLevel.competitive =>
      fa
          ? 'بورسیه رقابتی (DAAD/شورای پژوهشی)'
          : 'Competitive (DAAD/Research Council)',
    ScholarshipLevel.none =>
      fa
          ? 'شهریه‌پرداز (بدون بورسیه عمومی)'
          : 'Tuition-based (No public grant)',
  };
}

class UniversityComparisonItem {
  const UniversityComparisonItem({
    required this.id,
    required this.name,
    required this.countryCode,
    required this.countryName,
    required this.city,
    required this.rankingRange,
    required this.annualTuition,
    required this.currency,
    required this.minLanguageRequirement,
    required this.scholarshipLevel,
    required this.englishTaughtAvailable,
    required this.officialWebsite,
  });

  final String id;
  final String name;
  final String countryCode;
  final String countryName;
  final String city;
  final String rankingRange;
  final String annualTuition;
  final String currency;
  final String minLanguageRequirement;
  final ScholarshipLevel scholarshipLevel;
  final bool englishTaughtAvailable;
  final String officialWebsite;
}
