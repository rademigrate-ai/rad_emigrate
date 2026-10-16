import '../../../../core/errors/localized_error_message.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/l10n/locale_controller.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../../../core/widgets/secondary_destinations.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/directional_icons.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/premium_visuals.dart';
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
      // Sync display name to auth session only when name actually changed.
      // Never put global auth into loading (that redirected users to login).
      final priorName = (session?.fullName ?? current?.fullName ?? '').trim();
      if (profile.fullName.isNotEmpty && profile.fullName.trim() != priorName) {
        try {
          await ref
              .read(authControllerProvider.notifier)
              .completeProfile(
                fullName: profile.fullName,
                nationality: profile.nationality,
              );
        } catch (_) {
          // Profile row already saved; auth metadata sync is best-effort.
        }
      }
      if (mounted) {
        setState(() {
          _saving = false;
          _editing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).changesSaved)),
        );
      }
    } catch (_) {
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
    final isGuest = session == null || !session.isAuthenticated;
    final profileState = ref.watch(profileControllerProvider);
    final themePref = ref.watch(themeControllerProvider);
    final localePref = ref.watch(localeControllerProvider);

    if (!isGuest) {
      profileState.whenData(_hydrate);
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.profile),
        actions: [
          if (!isGuest) ...[
            if (!_editing)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: l10n.editProfile,
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
        ],
      ),
      body: PremiumCanvas(
        accent: AppColors.primaryRed,
        child: isGuest
            ? _buildGuestProfileContent(context, themePref, localePref, l10n)
            : profileState.when(
                skipError: true,
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
                    : LoadingState.section(message: l10n.loading),
                error: (e, _) => ErrorState(
                  message: localizedDataError(e, l10n),
                  onRetry: () =>
                      ref.read(profileControllerProvider.notifier).load(),
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
      ),
    );
  }

  Widget _buildGuestProfileContent(
    BuildContext context,
    AppThemePreference themePref,
    AppLocale localePref,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    return _ProfileContent(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          AppCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.primaryRed.withValues(alpha: 0.15),
                  child: const Icon(
                    Icons.person_outline,
                    size: 38,
                    color: AppColors.primaryRed,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.guestVisitor,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.guestProfileSubtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: l10n.signIn,
                        icon: Icons.login_rounded,
                        onPressed: () => context.go('/login?from=%2Fprofile'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        label: l10n.createAccount,
                        variant: AppButtonVariant.secondary,
                        icon: Icons.person_add_outlined,
                        onPressed: () =>
                            context.go('/register?from=%2Fprofile'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.guestWhySignIn,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _GuestFeatureTile(
            icon: Icons.assignment_outlined,
            title: l10n.guestTrackCasesTitle,
            subtitle: l10n.guestTrackCasesBody,
          ),
          const SizedBox(height: 8),
          _GuestFeatureTile(
            icon: Icons.folder_outlined,
            title: l10n.guestManageDocsTitle,
            subtitle: l10n.guestManageDocsBody,
          ),
          const SizedBox(height: 8),
          _GuestFeatureTile(
            icon: Icons.smart_toy_outlined,
            title: l10n.guestAiTitle,
            subtitle: l10n.guestAiBody,
          ),
          const SizedBox(height: 8),
          _GuestFeatureTile(
            icon: Icons.support_agent_outlined,
            title: l10n.guestConsultationTitle,
            subtitle: l10n.guestConsultationBody,
          ),
          const SizedBox(height: 24),
          const SecondaryDestinations(),
          const SizedBox(height: 20),
          Text(
            l10n.settings,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                _PreferenceSelector<String>(
                  icon: Icons.language,
                  title: l10n.language,
                  selected: localePref.languageCode,
                  options: {'en': l10n.english, 'fa': l10n.persian},
                  onSelected: (code) => ref
                      .read(localeControllerProvider.notifier)
                      .setLocale(AppLocale.fromLanguageCode(code)),
                ),
                const Divider(height: 1),
                _PreferenceSelector<AppThemePreference>(
                  icon: Icons.brightness_6_outlined,
                  title: l10n.theme,
                  selected: themePref,
                  options: {
                    AppThemePreference.light: l10n.themeLight,
                    AppThemePreference.dark: l10n.themeDark,
                    AppThemePreference.system: l10n.themeSystem,
                  },
                  onSelected: (preference) => ref
                      .read(themeControllerProvider.notifier)
                      .setPreference(preference),
                ),
              ],
            ),
          ),
        ],
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
        : (session?.fullName ?? l10n.travelerFallback);
    final initials = displayName.trim().isEmpty
        ? 'U'
        : displayName.trim()[0].toUpperCase();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              _ProfileAvatar(initials: initials, avatar: profile?.avatar),
              const SizedBox(height: 10),
              Text(
                displayName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (profile?.email != null || session?.email != null) ...[
                const SizedBox(height: 3),
                Text(
                  profile?.email ?? session?.email ?? '',
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (profile?.phone != null || session?.phone != null) ...[
                const SizedBox(height: 3),
                Text(
                  profile?.phone ?? session?.phone ?? '',
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: AppMotion.duration(context, AppMotion.modal),
          switchInCurve: AppMotion.curve(context),
          child: _editing
              ? KeyedSubtree(
                  key: const ValueKey('profile-edit'),
                  child: _buildEditForm(l10n),
                )
              : KeyedSubtree(
                  key: const ValueKey('profile-summary'),
                  child: _ProfileActionGroup(
                    children: [
                      _ProfileActionRow(
                        title: l10n.profile,
                        subtitle: profile == null
                            ? l10n.profileCompletionSubtitle
                            : '${l10n.fullName}: $displayName',
                        icon: Icons.badge_outlined,
                        onTap: () => setState(() => _editing = true),
                      ),
                      _ProfileActionRow(
                        title: l10n.applications,
                        subtitle: l10n.viewDetails,
                        icon: Icons.assignment_outlined,
                        onTap: () => context.go('/applications'),
                      ),
                      _ProfileActionRow(
                        title: l10n.documents,
                        subtitle: l10n.uploadDocument,
                        icon: Icons.folder_outlined,
                        onTap: () => context.go('/documents'),
                      ),
                      _ProfileActionRow(
                        title: l10n.aiAssistant,
                        subtitle: l10n.viewDetails,
                        icon: Icons.smart_toy_outlined,
                        onTap: () => context.go('/ai-assistant'),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 16),
        Text(l10n.settings, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: [
              _PreferenceSelector<String>(
                icon: Icons.language,
                title: l10n.language,
                selected: localePref.languageCode,
                options: {'en': l10n.english, 'fa': l10n.persian},
                onSelected: (code) => ref
                    .read(localeControllerProvider.notifier)
                    .setLocale(AppLocale.fromLanguageCode(code)),
              ),
              const Divider(height: 1),
              _PreferenceSelector<AppThemePreference>(
                icon: Icons.brightness_6_outlined,
                title: l10n.theme,
                selected: themePref,
                options: {
                  AppThemePreference.light: l10n.themeLight,
                  AppThemePreference.dark: l10n.themeDark,
                  AppThemePreference.system: l10n.themeSystem,
                },
                onSelected: (preference) => ref
                    .read(themeControllerProvider.notifier)
                    .setPreference(preference),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SecondaryDestinations(),
        const SizedBox(height: 16),
        Text(
          AppLocalizations.of(context).supportInformationLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        _ProfileActionGroup(
          children: [
            _ProfileActionRow(
              title: l10n.consultationTitle,
              subtitle: l10n.consultationIntro,
              icon: Icons.support_agent_outlined,
              onTap: () => context.go('/consultation'),
            ),
            _ProfileActionRow(
              title: l10n.feed,
              subtitle: l10n.feedPublishedOnly,
              icon: Icons.info_outline,
              onTap: () => context.go('/feed'),
            ),
            _ProfileActionRow(
              title: l10n.logout,
              subtitle: AppLocalizations.of(context).secureSignOutLabel,
              icon: Icons.logout,
              destructive: true,
              onTap: _saving
                  ? null
                  : () async {
                      await ref.read(authControllerProvider.notifier).logout();
                      if (context.mounted) context.go('/login');
                    },
            ),
          ],
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
              label: l10n.firstName,
              prefixIcon: Icons.person_outline,
              textInputAction: TextInputAction.next,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? l10n.required
                  : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _lastName,
              label: l10n.lastName,
              prefixIcon: Icons.person_outline,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _email,
              label: l10n.email,
              prefixIcon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              textInputAction: TextInputAction.next,
              validator: _optionalEmailValidator,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _phone,
              label: l10n.phone,
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _nationality,
              label: l10n.nationality,
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

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.initials, this.avatar});
  final String initials;
  final String? avatar;
  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      radius: 36,
      backgroundColor: context.premium.surfaceElevated,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: context.premium.text,
        ),
      ),
    );
    final uri = Uri.tryParse(avatar ?? '');
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      return fallback;
    }
    return ClipOval(
      child: Image.network(
        uri.toString(),
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
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
        constraints: const BoxConstraints(maxWidth: 960),
        child: child,
      ),
    );
  }
}

class _ProfileActionGroup extends StatelessWidget {
  const _ProfileActionGroup({required this.children});

  final List<_ProfileActionRow> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              const Divider(height: 1, indent: 72, endIndent: 18),
          ],
        ],
      ),
    );
  }
}

class _ProfileActionRow extends StatelessWidget {
  const _ProfileActionRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurface;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 62),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color:
                        (destructive
                                ? Theme.of(context).colorScheme.error
                                : AppColors.primaryRed)
                            .withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Icon(
                    icon,
                    color: destructive ? color : AppColors.primaryRed,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  directionalChevron(context),
                  color: destructive
                      ? color
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreferenceSelector<T> extends StatelessWidget {
  const _PreferenceSelector({
    required this.icon,
    required this.title,
    required this.selected,
    required this.options,
    required this.onSelected,
  });

  final IconData icon;
  final String title;
  final T selected;
  final Map<T, String> options;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: const EdgeInsets.symmetric(horizontal: 4),
    shape: const Border(),
    collapsedShape: const Border(),
    leading: Icon(icon, size: 21, color: context.premium.information),
    title: Text(title, style: Theme.of(context).textTheme.titleSmall),
    subtitle: Text(
      options[selected] ?? '',
      style: Theme.of(context).textTheme.bodySmall,
    ),
    childrenPadding: const EdgeInsets.only(bottom: 10),
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in options.entries)
            ChoiceChip(
              label: Text(option.value),
              selected: selected == option.key,
              onSelected: (_) => onSelected(option.key),
            ),
        ],
      ),
    ],
  );
}

class _GuestFeatureTile extends StatelessWidget {
  const _GuestFeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Icon(icon, color: AppColors.teal, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
