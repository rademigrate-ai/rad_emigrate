import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/l10n/locale_controller.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../domain/entities/user_profile.dart';
import '../providers/profile_controller.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _nationality;
  var _editing = false;
  var _controllersReady = false;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _firstName = TextEditingController();
    _lastName = TextEditingController();
    _email = TextEditingController();
    _phone = TextEditingController();
    _nationality = TextEditingController();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _nationality.dispose();
    super.dispose();
  }

  void _hydrate(UserProfile? profile) {
    if (profile == null || _controllersReady) return;
    _setControllerValues(profile);
    _controllersReady = true;
  }

  void _setControllerValues(UserProfile profile) {
    _firstName.text = profile.firstName ?? '';
    _lastName.text = profile.lastName ?? '';
    _email.text = profile.email ?? '';
    _phone.text = profile.phone ?? '';
    _nationality.text = profile.nationality ?? '';
  }

  void _cancelEditing(UserProfile? profile) {
    if (profile != null) _setControllerValues(profile);
    setState(() => _editing = false);
  }

  String? _optionalEmailValidator(String? value) {
    final l10n = AppLocalizations.of(context);
    final email = value?.trim() ?? '';
    if (email.isEmpty || email.contains('@')) return null;
    return l10n.invalidEmail;
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final current = ref.read(profileControllerProvider).valueOrNull;
    final session = ref.read(authControllerProvider).valueOrNull;
    final userId = current?.id ?? session?.userId;
    if (userId == null || userId.isEmpty) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).errorAuthSession),
          ),
        );
      }
      return;
    }
    final profile = UserProfile(
      id: userId,
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      nationality: _nationality.text.trim().isEmpty
          ? null
          : _nationality.text.trim(),
      avatar: current?.avatar,
      createdAt: current?.createdAt ?? DateTime.now(),
    );
    try {
      await ref.read(profileControllerProvider.notifier).save(profile);
      if (profile.fullName.isNotEmpty) {
        await ref
            .read(authControllerProvider.notifier)
            .completeProfile(
              fullName: profile.fullName,
              nationality: profile.nationality,
            );
      }
      if (mounted) {
        setState(() {
          _saving = false;
          _editing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).save)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).errorGeneric)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(authControllerProvider).valueOrNull;
    final profileState = ref.watch(profileControllerProvider);
    final themePref = ref.watch(themeControllerProvider);
    final localePref = ref.watch(localeControllerProvider);
    profileState.whenData(_hydrate);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.profile),
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.settings,
              onPressed: () => setState(() => _editing = true),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.logout,
            onPressed: _saving
                ? null
                : () async {
                    await ref.read(authControllerProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: profileState.when(
        loading: () => _saving
            ? _ProfileContent(
                child: _buildProfileContent(
                  context,
                  null,
                  session,
                  themePref,
                  localePref,
                  l10n,
                ),
              )
            : const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: l10n.errorGeneric,
          onRetry: () => ref.read(profileControllerProvider.notifier).load(),
        ),
        data: (profile) => _ProfileContent(
          child: _buildProfileContent(
            context,
            profile,
            session,
            themePref,
            localePref,
            l10n,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    UserProfile? profile,
    dynamic session,
    AppThemePreference themePref,
    AppLocale localePref,
    AppLocalizations l10n,
  ) {
    final displayName = profile?.fullName.isNotEmpty == true
        ? profile!.fullName
        : (session?.fullName ?? 'User');
    final initials = displayName.trim().isEmpty
        ? 'U'
        : displayName.trim()[0].toUpperCase();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.primaryRed,
                child: Text(
                  initials,
                  style: const TextStyle(fontSize: 28, color: Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (profile?.email != null || session?.email != null)
                      _ContactLine(
                        icon: Icons.mail_outline,
                        text: profile?.email ?? session?.email ?? '',
                      ),
                    if (profile?.phone != null || session?.phone != null)
                      _ContactLine(
                        icon: Icons.phone_outlined,
                        text: profile?.phone ?? session?.phone ?? '',
                      ),
                    if (profile?.nationality != null)
                      _ContactLine(
                        icon: Icons.public_outlined,
                        text: profile!.nationality!,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_editing) ...[
          _buildEditForm(l10n),
        ] else ...[
          SectionCard(
            title: l10n.profile,
            subtitle: l10n.profileCompletionSubtitle,
            icon: Icons.badge_outlined,
            onTap: () => setState(() => _editing = true),
            trailing: const Icon(Icons.chevron_right),
            child: Text(
              profile == null
                  ? l10n.profileCompletionSubtitle
                  : '${l10n.fullName}: $displayName',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
        const SizedBox(height: 8),
        SectionCard(
          title: l10n.applications,
          subtitle: l10n.viewDetails,
          icon: Icons.assignment_outlined,
          onTap: () => context.go('/applications'),
          trailing: const Icon(Icons.chevron_right),
        ),
        const SizedBox(height: 8),
        SectionCard(
          title: l10n.documents,
          subtitle: l10n.uploadDocument,
          icon: Icons.folder_outlined,
          onTap: () => context.go('/documents'),
          trailing: const Icon(Icons.chevron_right),
        ),
        const SizedBox(height: 8),
        SectionCard(
          title: l10n.aiAssistant,
          subtitle: l10n.viewDetails,
          icon: Icons.smart_toy_outlined,
          onTap: () => context.go('/ai-assistant'),
          trailing: const Icon(Icons.chevron_right),
        ),
        const SizedBox(height: 16),
        Text(l10n.settings, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.language),
                title: Text(l10n.language),
                subtitle: Text(
                  localePref.languageCode == 'fa' ? l10n.persian : l10n.english,
                ),
                trailing: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'en', label: Text(l10n.english)),
                    ButtonSegment(value: 'fa', label: Text(l10n.persian)),
                  ],
                  selected: {localePref.languageCode},
                  onSelectionChanged: (set) {
                    final code = set.first;
                    ref
                        .read(localeControllerProvider.notifier)
                        .setLocale(AppLocale.fromLanguageCode(code));
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.brightness_6_outlined),
                title: Text(l10n.theme),
                subtitle: Text(switch (themePref) {
                  AppThemePreference.light => l10n.themeLight,
                  AppThemePreference.dark => l10n.themeDark,
                  AppThemePreference.system => l10n.themeSystem,
                }),
                trailing: SegmentedButton<AppThemePreference>(
                  segments: [
                    ButtonSegment(
                      value: AppThemePreference.light,
                      label: Text(l10n.themeLight),
                    ),
                    ButtonSegment(
                      value: AppThemePreference.dark,
                      label: Text(l10n.themeDark),
                    ),
                    ButtonSegment(
                      value: AppThemePreference.system,
                      label: Text(l10n.themeSystem),
                    ),
                  ],
                  selected: {themePref},
                  onSelectionChanged: (set) {
                    ref
                        .read(themeControllerProvider.notifier)
                        .setPreference(set.first);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditForm(AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: AppCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.profile, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 18),
            AppTextField(
              controller: _firstName,
              label: l10n.fullName,
              prefixIcon: Icons.person_outline,
              textInputAction: TextInputAction.next,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? l10n.required
                  : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _lastName,
              label: l10n.fullName,
              prefixIcon: Icons.person_outline,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _email,
              label: l10n.email,
              prefixIcon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: _optionalEmailValidator,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _phone,
              label: l10n.phone,
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _nationality,
              label: l10n.profile,
              prefixIcon: Icons.public_outlined,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: l10n.cancel,
                    variant: AppButtonVariant.secondary,
                    onPressed: _saving
                        ? null
                        : () => _cancelEditing(
                            ref.read(profileControllerProvider).valueOrNull,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: l10n.save,
                    icon: Icons.check,
                    loading: _saving,
                    onPressed: _save,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: child,
      ),
    );
  }
}

class _ContactLine extends StatelessWidget {
  const _ContactLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        children: [
          Icon(icon, size: 15, color: Theme.of(context).hintColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
