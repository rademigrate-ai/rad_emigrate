import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/section_card.dart';
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
    final email = value?.trim() ?? '';
    if (email.isEmpty || email.contains('@')) return null;
    return 'Enter a valid email address';
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final current = ref.read(profileControllerProvider).valueOrNull;
    final session = ref.read(authControllerProvider).valueOrNull;
    final profile = UserProfile(
      id: current?.id ?? session?.userId ?? 'user-demo-001',
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      nationality:
          _nationality.text.trim().isEmpty ? null : _nationality.text.trim(),
      avatar: current?.avatar,
      createdAt: current?.createdAt ?? DateTime.now(),
    );
    try {
      await ref.read(profileControllerProvider.notifier).save(profile);
      if (profile.fullName.isNotEmpty) {
        await ref.read(authControllerProvider.notifier).completeProfile(
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
          const SnackBar(content: Text('Profile saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save profile: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).valueOrNull;
    final profileState = ref.watch(profileControllerProvider);
    profileState.whenData(_hydrate);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit profile',
              onPressed: () => setState(() => _editing = true),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
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
                child: _buildProfileContent(context, null, session),
              )
            : const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: 'Could not load profile: $e',
          onRetry: () => ref.read(profileControllerProvider.notifier).load(),
        ),
        data: (profile) => _ProfileContent(
          child: _buildProfileContent(context, profile, session),
        ),
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    UserProfile? profile,
    dynamic session,
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
          _buildEditForm(),
        ] else ...[
          SectionCard(
            title: 'Immigration profile',
            subtitle: 'Education, work, languages, destination',
            icon: Icons.badge_outlined,
            onTap: () => setState(() => _editing = true),
            trailing: const Icon(Icons.chevron_right),
            child: Text(
              profile == null
                  ? 'Tap edit to complete your immigration profile.'
                  : 'Name: $displayName\nNationality: ${profile.nationality ?? '—'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
        const SizedBox(height: 8),
        SectionCard(
          title: 'Applications',
          subtitle: 'Track visa applications',
          icon: Icons.assignment_outlined,
          onTap: () => context.go('/applications'),
          trailing: const Icon(Icons.chevron_right),
        ),
        const SizedBox(height: 8),
        SectionCard(
          title: 'Documents',
          subtitle: 'Upload and manage documents',
          icon: Icons.folder_outlined,
          onTap: () => context.go('/documents'),
          trailing: const Icon(Icons.chevron_right),
        ),
        const SizedBox(height: 8),
        SectionCard(
          title: 'AI assistant',
          subtitle: 'Ask immigration questions',
          icon: Icons.smart_toy_outlined,
          onTap: () => context.go('/ai-assistant'),
          trailing: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildEditForm() {
    return Form(
      key: _formKey,
      child: AppCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('About you', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Keep these details up to date for your applications.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            AppTextField(
              controller: _firstName,
              label: 'First name',
              prefixIcon: Icons.person_outline,
              textInputAction: TextInputAction.next,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'First name is required'
                  : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _lastName,
              label: 'Last name',
              prefixIcon: Icons.person_outline,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _email,
              label: 'Email',
              prefixIcon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: _optionalEmailValidator,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _phone,
              label: 'Phone',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _nationality,
              label: 'Nationality',
              prefixIcon: Icons.public_outlined,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Cancel',
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
                    label: 'Save changes',
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
          Icon(icon, size: 15, color: AppColors.textTertiary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
