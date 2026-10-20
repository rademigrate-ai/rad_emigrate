import '../domain/entities/pathway_comparison.dart';

abstract class PathwayComparisonRepository {
  Future<List<PathwayComparisonItem>> getComparisonItems({
    required String locale,
  });
}

class StaticPathwayComparisonRepository implements PathwayComparisonRepository {
  const StaticPathwayComparisonRepository();

  @override
  Future<List<PathwayComparisonItem>> getComparisonItems({
    required String locale,
  }) async {
    final isFa = locale == 'fa';

    return [
      PathwayComparisonItem(
        countryCode: 'DE',
        countryName: isFa ? 'آلمان' : 'Germany',
        pathwaySlug: 'chancenkarte',
        pathwayName: isFa
            ? 'کارت شانس (Chancenkarte)'
            : 'Opportunity Card (Chancenkarte)',
        minLanguageLevel: isFa
            ? 'A1 آلمانی یا B2 انگلیسی'
            : 'A1 German or B2 English',
        processingTimeRange: isFa ? '۴ تا ۸ هفته' : '4–8 weeks',
        jobOfferRequired: false,
        directPermanentResidency: false,
        keyAdvantage: isFa
            ? 'ورود به آلمان بدون جاب‌آفر برای جستجوی کار'
            : 'Enter Germany without a job offer to seek employment',
        keyRequirement: isFa
            ? 'کسب حداقل ۶ امتیاز از سیستم امتیازبندی یا داشتن مدرک تحصیلی معتبر'
            : 'Minimum 6 points in points system or recognized university degree',
      ),
      PathwayComparisonItem(
        countryCode: 'CA',
        countryName: isFa ? 'کانادا' : 'Canada',
        pathwaySlug: 'express-entry',
        pathwayName: isFa
            ? 'اکسپرس اینتری (Express Entry)'
            : 'Express Entry (FSW/CEC)',
        minLanguageLevel: isFa
            ? 'CLB 7 (IELTS 6.0)'
            : 'CLB 7 (IELTS 6.0 in all bands)',
        processingTimeRange: isFa ? '۶ تا ۹ ماه' : '6–9 months',
        jobOfferRequired: false,
        directPermanentResidency: true,
        keyAdvantage: isFa
            ? 'اعطای اقامت دائم (PR) مستقیم از ابتدای ورود'
            : 'Direct Permanent Residency (PR) granted upon landing',
        keyRequirement: isFa
            ? 'کسب نمره رقابتی CRS و حداقل ۶۷ امتیاز در سیستم اولیه'
            : 'Competitive CRS score in pool draws and 67 points initial grid',
      ),
      PathwayComparisonItem(
        countryCode: 'AU',
        countryName: isFa ? 'استرالیا' : 'Australia',
        pathwaySlug: 'subclass-189',
        pathwayName: isFa
            ? 'اسکیل ایندیپندنت (Subclass 189)'
            : 'Skilled Independent (Subclass 189)',
        minLanguageLevel: isFa
            ? 'Competent English (IELTS 6.0)'
            : 'Competent English (IELTS 6.0)',
        processingTimeRange: isFa ? '۸ تا ۱۲ ماه' : '8–12 months',
        jobOfferRequired: false,
        directPermanentResidency: true,
        keyAdvantage: isFa
            ? 'اقامت دائم کامل بدون وابستگی به کارفرما یا ایالت خاص'
            : 'Full Permanent Residency without employer or state bond',
        keyRequirement: isFa
            ? 'ارزیابی مثبت مدارک شغلی (Skills Assessment) و حداقل ۶۵ امتیاز'
            : 'Positive Skills Assessment and minimum 65 points in EOI',
      ),
    ];
  }
}
