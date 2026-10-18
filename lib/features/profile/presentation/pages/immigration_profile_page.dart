import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/inline_alert.dart';
import '../../../../core/widgets/premium_visuals.dart';
import '../../../../core/widgets/rad_loading.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/profile_entity.dart';
import '../../domain/pathway_assessment.dart';
import '../providers/immigration_profile_controller.dart';

class ImmigrationProfilePage extends ConsumerStatefulWidget {
  const ImmigrationProfilePage({super.key});

  @override
  ConsumerState<ImmigrationProfilePage> createState() =>
      _ImmigrationProfilePageState();
}

class _ImmigrationProfilePageState
    extends ConsumerState<ImmigrationProfilePage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _nationalityCtrl;
  late final TextEditingController _educationCtrl;
  late final TextEditingController _workCtrl;
  late final TextEditingController _languagesCtrl;
  late final TextEditingController _destinationCtrl;
  late final TextEditingController _maritalCtrl;

  bool _initialized = false;
  String _selectedProgramId = 'express-entry';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _nationalityCtrl = TextEditingController();
    _educationCtrl = TextEditingController();
    _workCtrl = TextEditingController();
    _languagesCtrl = TextEditingController();
    _destinationCtrl = TextEditingController();
    _maritalCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _nationalityCtrl.dispose();
    _educationCtrl.dispose();
    _workCtrl.dispose();
    _languagesCtrl.dispose();
    _destinationCtrl.dispose();
    _maritalCtrl.dispose();
    super.dispose();
  }

  void _syncControllers(ImmigrationProfile p) {
    if (_initialized) return;
    _nameCtrl.text = p.fullName ?? '';
    _emailCtrl.text = p.email ?? '';
    _phoneCtrl.text = p.phone ?? '';
    _nationalityCtrl.text = p.nationality ?? '';
    _educationCtrl.text = p.education ?? '';
    _workCtrl.text = p.workExperience ?? '';
    _languagesCtrl.text = p.languages.join(', ');
    _destinationCtrl.text = p.destinationPreference ?? '';
    _maritalCtrl.text = p.maritalStatus ?? '';
    _initialized = true;
  }

  String _fieldLabel(ImmigrationProfileField field, bool isFa) {
    switch (field) {
      case ImmigrationProfileField.fullName:
        return isFa ? 'نام و نام خانوادگی' : 'Full Name';
      case ImmigrationProfileField.email:
        return isFa ? 'ایمیل' : 'Email Address';
      case ImmigrationProfileField.phone:
        return isFa ? 'شماره تماس' : 'Phone Number';
      case ImmigrationProfileField.nationality:
        return isFa ? 'ملیت' : 'Nationality';
      case ImmigrationProfileField.education:
        return isFa ? 'آخرین مقطع تحصیلی' : 'Highest Education';
      case ImmigrationProfileField.workExperience:
        return isFa ? 'سابقه کاری (سال و عنوان)' : 'Work Experience';
      case ImmigrationProfileField.languages:
        return isFa
            ? 'زبان‌ها (با کاما جدا کنید)'
            : 'Languages (comma separated)';
      case ImmigrationProfileField.destinationPreference:
        return isFa ? 'کشور مقصد مورد نظر' : 'Destination Preference';
      case ImmigrationProfileField.maritalStatus:
        return isFa ? 'وضعیت تأهل' : 'Marital Status';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(immigrationProfileControllerProvider);
    final controller = ref.read(immigrationProfileControllerProvider.notifier);
    final l10n = AppLocalizations.of(context);
    final isFa = Localizations.localeOf(context).languageCode == 'fa';

    if (!state.isLoading && !_initialized) {
      _syncControllers(state.profile);
    }

    final completeness = state.validation.completenessPercent;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isFa
              ? 'پرونده مهاجرتی و سنجش مسیر'
              : 'Immigration Profile & Assessment',
        ),
        leading: const AppBackButton(fallback: '/profile'),
        actions: [
          if (state.isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: RadPending(),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: isFa ? 'ذخیره پیش‌نویس' : 'Save Draft',
              onPressed: () async {
                final ok = await controller.saveDraft();
                if (context.mounted && ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isFa
                            ? 'پیش‌نویس پرونده با موفقیت ذخیره شد.'
                            : 'Profile draft saved locally.',
                      ),
                    ),
                  );
                }
              },
            ),
        ],
      ),
      body: PremiumCanvas(
        accent: AppColors.teal,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                // 1. Profile Completeness Card
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isFa ? 'تکمیل پرونده' : 'Profile Completeness',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: completeness == 100
                                  ? context.premium.success.withValues(
                                      alpha: .15,
                                    )
                                  : context.premium.accent.withValues(
                                      alpha: .15,
                                    ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$completeness%',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: completeness == 100
                                    ? context.premium.success
                                    : context.premium.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: completeness / 100.0,
                          minHeight: 8,
                          backgroundColor: context.premium.border,
                          valueColor: AlwaysStoppedAnimation(
                            completeness == 100
                                ? context.premium.success
                                : context.premium.accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (state.validation.isStructurallyComplete)
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: context.premium.success,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                isFa
                                    ? 'تمام فیلدها با موفقیت تکمیل یا مشخص شده‌اند.'
                                    : 'All profile fields are provided or accounted for.',
                                style: TextStyle(
                                  color: context.premium.success,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        Text(
                          isFa
                              ? 'برای ارزیابی دقیق، فیلدهای باقیمانده را تکمیل کنید یا به عنوان ناشناخته علامت بزنید:'
                              : 'Provide remaining fields or mark them as unknown for evaluation:',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final missing
                                in state.validation.missingFields)
                              Chip(
                                avatar: const Icon(
                                  Icons.help_outline,
                                  size: 14,
                                ),
                                label: Text(
                                  _fieldLabel(missing, isFa),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            for (final invalid
                                in state.validation.invalidFields)
                              Chip(
                                avatar: Icon(
                                  Icons.error_outline,
                                  size: 14,
                                  color: context.premium.error,
                                ),
                                label: Text(
                                  '${_fieldLabel(invalid, isFa)} (${isFa ? "نامعتبر" : "invalid"})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.premium.error,
                                  ),
                                ),
                                backgroundColor: context.premium.error
                                    .withValues(alpha: .1),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 2. Profile Editor Form
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isFa
                            ? 'اطلاعات متقاضی مهاجرت'
                            : 'Applicant Immigration Profile',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isFa
                            ? 'این داده‌ها به صورت امن ذخیره می‌شوند و برای ارزیابی شواهد محور استفاده می‌گردند.'
                            : 'Saved privately in local storage. Never sent to unverified third-parties.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),

                      // Full Name
                      _buildProfileField(
                        controller: _nameCtrl,
                        field: ImmigrationProfileField.fullName,
                        label: _fieldLabel(
                          ImmigrationProfileField.fullName,
                          isFa,
                        ),
                        icon: Icons.person_outline,
                        profile: state.profile,
                        isFa: isFa,
                        onChanged: (v) => controller.updateField(
                          ImmigrationProfileField.fullName,
                          v,
                        ),
                        onToggleUnknown: (val) {
                          controller.toggleUnknown(
                            ImmigrationProfileField.fullName,
                            val,
                          );
                          if (val) _nameCtrl.clear();
                        },
                      ),

                      // Email
                      _buildProfileField(
                        controller: _emailCtrl,
                        field: ImmigrationProfileField.email,
                        label: _fieldLabel(ImmigrationProfileField.email, isFa),
                        icon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        profile: state.profile,
                        isFa: isFa,
                        onChanged: (v) => controller.updateField(
                          ImmigrationProfileField.email,
                          v,
                        ),
                        onToggleUnknown: (val) {
                          controller.toggleUnknown(
                            ImmigrationProfileField.email,
                            val,
                          );
                          if (val) _emailCtrl.clear();
                        },
                      ),

                      // Phone
                      _buildProfileField(
                        controller: _phoneCtrl,
                        field: ImmigrationProfileField.phone,
                        label: _fieldLabel(ImmigrationProfileField.phone, isFa),
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        profile: state.profile,
                        isFa: isFa,
                        onChanged: (v) => controller.updateField(
                          ImmigrationProfileField.phone,
                          v,
                        ),
                        onToggleUnknown: (val) {
                          controller.toggleUnknown(
                            ImmigrationProfileField.phone,
                            val,
                          );
                          if (val) _phoneCtrl.clear();
                        },
                      ),

                      // Nationality
                      _buildProfileField(
                        controller: _nationalityCtrl,
                        field: ImmigrationProfileField.nationality,
                        label: _fieldLabel(
                          ImmigrationProfileField.nationality,
                          isFa,
                        ),
                        icon: Icons.flag_outlined,
                        profile: state.profile,
                        isFa: isFa,
                        onChanged: (v) => controller.updateField(
                          ImmigrationProfileField.nationality,
                          v,
                        ),
                        onToggleUnknown: (val) {
                          controller.toggleUnknown(
                            ImmigrationProfileField.nationality,
                            val,
                          );
                          if (val) _nationalityCtrl.clear();
                        },
                      ),

                      // Education
                      _buildProfileField(
                        controller: _educationCtrl,
                        field: ImmigrationProfileField.education,
                        label: _fieldLabel(
                          ImmigrationProfileField.education,
                          isFa,
                        ),
                        icon: Icons.school_outlined,
                        profile: state.profile,
                        isFa: isFa,
                        onChanged: (v) => controller.updateField(
                          ImmigrationProfileField.education,
                          v,
                        ),
                        onToggleUnknown: (val) {
                          controller.toggleUnknown(
                            ImmigrationProfileField.education,
                            val,
                          );
                          if (val) _educationCtrl.clear();
                        },
                      ),

                      // Work Experience
                      _buildProfileField(
                        controller: _workCtrl,
                        field: ImmigrationProfileField.workExperience,
                        label: _fieldLabel(
                          ImmigrationProfileField.workExperience,
                          isFa,
                        ),
                        icon: Icons.work_outline,
                        profile: state.profile,
                        isFa: isFa,
                        onChanged: (v) => controller.updateField(
                          ImmigrationProfileField.workExperience,
                          v,
                        ),
                        onToggleUnknown: (val) {
                          controller.toggleUnknown(
                            ImmigrationProfileField.workExperience,
                            val,
                          );
                          if (val) _workCtrl.clear();
                        },
                      ),

                      // Languages
                      _buildProfileField(
                        controller: _languagesCtrl,
                        field: ImmigrationProfileField.languages,
                        label: _fieldLabel(
                          ImmigrationProfileField.languages,
                          isFa,
                        ),
                        icon: Icons.translate,
                        profile: state.profile,
                        isFa: isFa,
                        onChanged: (v) {
                          final list = v
                              .split(',')
                              .map((s) => s.trim())
                              .where((s) => s.isNotEmpty)
                              .toList();
                          controller.updateField(
                            ImmigrationProfileField.languages,
                            v,
                            languageList: list,
                          );
                        },
                        onToggleUnknown: (val) {
                          controller.toggleUnknown(
                            ImmigrationProfileField.languages,
                            val,
                          );
                          if (val) _languagesCtrl.clear();
                        },
                      ),

                      // Destination Preference
                      _buildProfileField(
                        controller: _destinationCtrl,
                        field: ImmigrationProfileField.destinationPreference,
                        label: _fieldLabel(
                          ImmigrationProfileField.destinationPreference,
                          isFa,
                        ),
                        icon: Icons.flight_takeoff_outlined,
                        profile: state.profile,
                        isFa: isFa,
                        onChanged: (v) => controller.updateField(
                          ImmigrationProfileField.destinationPreference,
                          v,
                        ),
                        onToggleUnknown: (val) {
                          controller.toggleUnknown(
                            ImmigrationProfileField.destinationPreference,
                            val,
                          );
                          if (val) _destinationCtrl.clear();
                        },
                      ),

                      // Marital Status
                      _buildProfileField(
                        controller: _maritalCtrl,
                        field: ImmigrationProfileField.maritalStatus,
                        label: _fieldLabel(
                          ImmigrationProfileField.maritalStatus,
                          isFa,
                        ),
                        icon: Icons.people_outline,
                        profile: state.profile,
                        isFa: isFa,
                        onChanged: (v) => controller.updateField(
                          ImmigrationProfileField.maritalStatus,
                          v,
                        ),
                        onToggleUnknown: (val) {
                          controller.toggleUnknown(
                            ImmigrationProfileField.maritalStatus,
                            val,
                          );
                          if (val) _maritalCtrl.clear();
                        },
                      ),

                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: isFa ? 'ذخیره پیش‌نویس' : 'Save Draft',
                              icon: Icons.save,
                              loading: state.isSaving,
                              onPressed: () async {
                                final ok = await controller.saveDraft();
                                if (context.mounted && ok) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isFa
                                            ? 'پیش‌نویس ذخیره شد'
                                            : 'Draft saved successfully',
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      if (state.lastSaved != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          isFa
                              ? 'آخرین ذخیره‌سازی محلی: ${state.lastSaved!.hour.toString().padLeft(2, "0")}:${state.lastSaved!.minute.toString().padLeft(2, "0")}'
                              : 'Last saved locally at: ${state.lastSaved!.hour.toString().padLeft(2, "0")}:${state.lastSaved!.minute.toString().padLeft(2, "0")}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Evidence-Aware Pathway Assessment Card
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.verified_outlined,
                            color: context.premium.accent,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isFa
                                  ? 'سنجش مسیر مهاجرتی بر اساس شواهد معتبر'
                                  : 'Evidence-Grounded Pathway Assessment',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isFa
                            ? 'این ارزیابی صرفاً بر اساس قوانین مصوب و مدون سازمانی صورت می‌گیرد و هیچ پیش‌بینی غیرمستندی ارائه نمی‌دهد.'
                            : 'Evaluates facts against verified official rules only. Never produces speculative AI scores or visa promises.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 14),

                      // Program Selection
                      Text(
                        isFa
                            ? 'انتخاب برنامه مهاجرتی:'
                            : 'Select Pathway Program:',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _selectedProgramId,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'express-entry',
                            child: Text(
                              isFa
                                  ? 'کانادا — Express Entry (نیروی متخصص فدرال)'
                                  : 'Canada — Express Entry (Federal Skilled Worker)',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'de-chancenkarte',
                            child: Text(
                              isFa
                                  ? 'آلمان — کارت فرصت جویای کار (Chancenkarte)'
                                  : 'Germany — Opportunity Card (Chancenkarte)',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'ca-startup',
                            child: Text(
                              isFa
                                  ? 'کانادا — استارتاپ و کارآفرینی (Start-up Visa)'
                                  : 'Canada — Start-up Visa Program',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'unsupported-sample',
                            child: Text(
                              isFa
                                  ? 'سایر برنامه‌ها (بدون قواعد مصوب در سیستم)'
                                  : 'Other Pathway (No curated rules registered)',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedProgramId = val);
                            controller.assessPathway(val);
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      AppButton(
                        label: isFa
                            ? 'ارزیابی صلاحیت اولیه'
                            : 'Assess Eligibility',
                        icon: Icons.fact_check_outlined,
                        variant: AppButtonVariant.secondary,
                        onPressed: () =>
                            controller.assessPathway(_selectedProgramId),
                      ),
                      const SizedBox(height: 16),

                      // Assessment Result Section
                      if (state.assessment != null)
                        _buildAssessmentResult(
                          state.assessment!,
                          isFa,
                          context,
                        ),

                      const SizedBox(height: 12),
                      // Uncertainty and Legal Notice Banner
                      InlineAlert(
                        error: false,
                        message: isFa
                            ? 'هشدار شفافیت: سیستم راد ای‌میگریت هیچ تضمینی برای قبولی ویزا ارائه نمی‌دهد. تمام پرونده‌ها مستلزم بررسی اسناد تکمیلی و مشاوره تخصصی وکلای رسمی هستند.'
                            : 'Transparency Notice: RAD Emigrate does not offer legal advice or guarantee visa approval. Final outcomes rest solely with government immigration authorities and licensed consultant review.',
                      ),
                      const SizedBox(height: 14),
                      AppButton(
                        label: l10n.bookConsultationAction,
                        icon: Icons.support_agent_outlined,
                        onPressed: () => context.push('/consultation'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileField({
    required TextEditingController controller,
    required ImmigrationProfileField field,
    required String label,
    required IconData icon,
    required ImmigrationProfile profile,
    required bool isFa,
    required ValueChanged<String> onChanged,
    required ValueChanged<bool> onToggleUnknown,
    TextInputType? keyboardType,
    TextDirection? textDirection,
  }) {
    final isUnknown = profile.unknownFields.contains(field);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: controller,
                  label: label,
                  prefixIcon: icon,
                  enabled: !isUnknown,
                  keyboardType: keyboardType,
                  textDirection: textDirection,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: isUnknown,
                    onChanged: (v) => onToggleUnknown(v ?? false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    onTap: () => onToggleUnknown(!isUnknown),
                    child: Text(
                      isFa
                          ? 'نامشخص / ترجیح می‌دهم فعلاً نگویم'
                          : 'Unknown / Prefer not to specify',
                      style: TextStyle(
                        fontSize: 12,
                        color: isUnknown
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentResult(
    PathwayAssessmentResult res,
    bool isFa,
    BuildContext context,
  ) {
    Color color;
    IconData icon;
    String title;

    switch (res.outcome) {
      case PathwayOutcome.potentiallyEligible:
        color = context.premium.success;
        icon = Icons.check_circle_outlined;
        title = isFa
            ? 'واجد شرایط احتمالی بر اساس شواهد مدون'
            : 'Potentially Eligible (Verified Rules)';
      case PathwayOutcome.insufficientInformation:
        color = context.premium.warning;
        icon = Icons.info_outline;
        title = isFa
            ? 'اطلاعات پرونده ناکافی است'
            : 'Insufficient Information to Assess';
      case PathwayOutcome.potentiallyIneligible:
        color = context.premium.error;
        icon = Icons.cancel_outlined;
        title = isFa
            ? 'احتمال عدم تطابق با معیارهای اولیه'
            : 'Potentially Ineligible';
      case PathwayOutcome.requiresProfessionalReview:
        color = const Color(0xFF8B5CF6);
        icon = Icons.psychology_outlined;
        title = isFa
            ? 'نیازمند بررسی کارشناسی و چندجانبه'
            : 'Professional Review Required';
      case PathwayOutcome.insufficientVerifiedEvidence:
        color = context.premium.mutedText;
        icon = Icons.search_off_outlined;
        title = isFa
            ? 'قوانین مصوب رسمی در سامانه یافت نشد'
            : 'Insufficient Verified Evidence';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          if (res.rationale.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(res.rationale, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (res.missingFields.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              isFa
                  ? 'فیلدهای الزامی که تکمیل نشده‌اند:'
                  : 'Missing required fields for this pathway:',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: [
                for (final f in res.missingFields)
                  Chip(
                    label: Text(
                      _fieldLabel(f, isFa),
                      style: const TextStyle(fontSize: 11),
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
          if (res.evidence.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              isFa
                  ? 'مراجع و شواهد قانونی معتبر:'
                  : 'Authoritative Legal Evidence:',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(height: 4),
            for (final ev in res.evidence)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(
                      child: Text(
                        '${ev.title} (${ev.jurisdiction}) — ${ev.publisher ?? ""}\n${ev.sourceUrl}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
