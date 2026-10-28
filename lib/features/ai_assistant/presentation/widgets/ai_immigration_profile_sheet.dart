import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../domain/entities/ai_user_profile.dart';
import '../providers/ai_user_profile_provider.dart';

/// Modal bottom sheet for viewing and editing the voluntary immigration profile.
class AiImmigrationProfileSheet extends ConsumerStatefulWidget {
  const AiImmigrationProfileSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const AiImmigrationProfileSheet(),
    );
  }

  @override
  ConsumerState<AiImmigrationProfileSheet> createState() =>
      _AiImmigrationProfileSheetState();
}

class _AiImmigrationProfileSheetState
    extends ConsumerState<AiImmigrationProfileSheet> {
  late final TextEditingController _educationCtrl;
  late final TextEditingController _experienceCtrl;
  late final TextEditingController _languageCtrl;
  late final TextEditingController _targetCountryCtrl;
  late final TextEditingController _budgetCtrl;
  late bool _enableAiReuse;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(aiUserProfileProvider);
    _educationCtrl = TextEditingController(text: profile.education);
    _experienceCtrl = TextEditingController(
      text: profile.workExperienceYears > 0
          ? '${profile.workExperienceYears}'
          : '',
    );
    _languageCtrl = TextEditingController(text: profile.languageScore);
    _targetCountryCtrl = TextEditingController(text: profile.targetCountry);
    _budgetCtrl = TextEditingController(text: profile.estimatedBudget);
    _enableAiReuse = profile.enableAiPersonalization;
  }

  @override
  void dispose() {
    _educationCtrl.dispose();
    _experienceCtrl.dispose();
    _languageCtrl.dispose();
    _targetCountryCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final expYears = int.tryParse(_experienceCtrl.text.trim()) ?? 0;
    final updated = AiImmigrationProfile(
      education: _educationCtrl.text.trim(),
      workExperienceYears: expYears,
      languageScore: _languageCtrl.text.trim(),
      targetCountry: _targetCountryCtrl.text.trim(),
      estimatedBudget: _budgetCtrl.text.trim(),
      enableAiPersonalization: _enableAiReuse,
    );
    ref.read(aiUserProfileProvider.notifier).updateProfile(updated);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('پروفایل مهاجرتی هوش مصنوعی به‌روزرسانی شد.'),
        backgroundColor: AppColors.teal,
      ),
    );
  }

  void _clear() {
    ref.read(aiUserProfileProvider.notifier).clearProfile();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('اطلاعات پروفایل پاک شد.')));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: context.premium.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.lg),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.premium.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  color: AppColors.primaryRed,
                  size: 24,
                ),
                const SizedBox(width: 10),
                const Text(
                  'پروفایل مهاجرتی اختیاری',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'تکمیل این اطلاعات اختیاری است و به هوش مصنوعی کمک می‌کند مشاوره‌ها و شرایط ویزا را دقیقاً بر اساس وضعیت شما تنظیم کند.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // Fields
            _buildField(
              controller: _educationCtrl,
              label: 'آخرین مقطع تحصیلی و رشته',
              hint: 'مثال: کارشناسی ارشد مهندسی کامپیوتر',
              icon: Icons.school_outlined,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildField(
                    controller: _experienceCtrl,
                    label: 'سابقه کار مرتبط (سال)',
                    hint: 'مثال: ۵',
                    icon: Icons.work_outline,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildField(
                    controller: _languageCtrl,
                    label: 'مدرک و نمره زبان',
                    hint: 'مثال: IELTS 7.5',
                    icon: Icons.translate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildField(
                    controller: _targetCountryCtrl,
                    label: 'کشور هدف مورد نظر',
                    hint: 'مثال: کانادا / آلمان',
                    icon: Icons.public_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildField(
                    controller: _budgetCtrl,
                    label: 'تمکن مالی تقریبی',
                    hint: 'مثال: ۵۰۰ میلیون تا ۱ میلیارد',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // AI Personalization Switch
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.premium.surfaceElevated,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: context.premium.border),
              ),
              child: Material(
                color: Colors.transparent,
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _enableAiReuse,
                  activeTrackColor: AppColors.teal,
                  title: const Text(
                    'شخصی‌سازی خودکار پاسخ‌های هوش مصنوعی',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'با فعال بودن، هوش مصنوعی بدون نیاز به تکرار سوال شرایط شما را لحاظ می‌کند.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  onChanged: (val) => setState(() => _enableAiReuse = val),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Actions
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _clear,
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: AppColors.error,
                  ),
                  label: const Text(
                    'پاک‌سازی پروفایل',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('انصراف'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                      ),
                      onPressed: _save,
                      child: const Text('ذخیره تنظیمات'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }
}
