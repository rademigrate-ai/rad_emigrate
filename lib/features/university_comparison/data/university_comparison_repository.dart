import '../domain/entities/university_comparison.dart';

abstract class UniversityComparisonRepository {
  Future<List<UniversityComparisonItem>> getUniversities({
    String? countryFilter,
    required String locale,
  });
}

class StaticUniversityComparisonRepository
    implements UniversityComparisonRepository {
  const StaticUniversityComparisonRepository();

  @override
  Future<List<UniversityComparisonItem>> getUniversities({
    String? countryFilter,
    required String locale,
  }) async {
    final isFa = locale == 'fa';

    final items = [
      UniversityComparisonItem(
        id: 'tum',
        name: isFa
            ? 'دانشگاه فنی مونیخ (TUM)'
            : 'Technical University of Munich (TUM)',
        countryCode: 'DE',
        countryName: isFa ? 'آلمان' : 'Germany',
        city: isFa ? 'مونیخ' : 'Munich',
        rankingRange: '#28 QS World Ranking',
        annualTuition: isFa
            ? 'رایگان (فقط حق ثبت‌نام ترمی ~۱۵۰ یورو)'
            : 'Free tuition (Semester fee ~150 EUR)',
        currency: 'EUR',
        minLanguageRequirement: isFa
            ? 'IELTS 6.5 یا TestDaF 4'
            : 'IELTS 6.5 or TestDaF 4',
        scholarshipLevel: ScholarshipLevel.competitive,
        englishTaughtAvailable: true,
        officialWebsite: 'https://www.tum.de',
      ),
      UniversityComparisonItem(
        id: 'utoronto',
        name: isFa
            ? 'دانشگاه تورنتو (U of T)'
            : 'University of Toronto (U of T)',
        countryCode: 'CA',
        countryName: isFa ? 'کانادا' : 'Canada',
        city: isFa ? 'تورنتو' : 'Toronto',
        rankingRange: '#21 QS World Ranking',
        annualTuition: isFa
            ? '۴۵,۰۰۰ – ۶۰,۰۰۰ دلار کانادا'
            : '45,000–60,000 CAD',
        currency: 'CAD',
        minLanguageRequirement: isFa
            ? 'IELTS 6.5 (حداقل ۶.۰ در هر مهارت)'
            : 'IELTS 6.5 (min 6.0 each band)',
        scholarshipLevel: ScholarshipLevel.full,
        englishTaughtAvailable: true,
        officialWebsite: 'https://www.utoronto.ca',
      ),
      UniversityComparisonItem(
        id: 'unimelb',
        name: isFa ? 'دانشگاه ملبورن' : 'University of Melbourne',
        countryCode: 'AU',
        countryName: isFa ? 'استرالیا' : 'Australia',
        city: isFa ? 'ملبورن' : 'Melbourne',
        rankingRange: '#13 QS World Ranking',
        annualTuition: isFa
            ? '۴۲,۰۰۰ – ۵۴,۰۰۰ دلار استرالیا'
            : '42,000–54,000 AUD',
        currency: 'AUD',
        minLanguageRequirement: isFa
            ? 'IELTS 6.5 (حداقل ۶.۰ در هر مهارت)'
            : 'IELTS 6.5 (min 6.0 each band)',
        scholarshipLevel: ScholarshipLevel.partial,
        englishTaughtAvailable: true,
        officialWebsite: 'https://www.unimelb.edu.au',
      ),
    ];

    if (countryFilter != null && countryFilter.isNotEmpty) {
      return items.where((e) => e.countryCode == countryFilter).toList();
    }
    return items;
  }
}
