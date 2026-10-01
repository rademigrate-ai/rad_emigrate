import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/section_card.dart';
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

  void _hydrate(UserProfile? p) {
    if (p == null || _controllersReady) return;
    _firstName.text = p.firstName ?? '';
    _lastName.text = p.lastName ?? '';
    _email.text = p.email ?? '';
    _phone.text = p.phone ?? '';
    _nationality.text = p.nationality ?? '';
    _controllersReady = true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final current = ref.read(profileControllerProvider).valueOrNull;
    final session = ref.read(authControllerProvider).valueOrNull;
    final profile = UserProfile(
      id: current?.id ?? session?.userId ?? 'user-demo-001',
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      nationality: _nationality.text.trim().isEmpty ? null : _nationality.text.trim(),
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
        setState(() => _editing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
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
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: profileState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Could not load profile: $e'),
              TextButton(
                onPressed: () => ref.read(profileControllerProvider.notifier).load(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (profile) {
          final displayName = profile?.fullName.isNotEmpty == true
              ? profile!.fullName
              : (session?.fullName ?? 'User');
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: AppColors.primaryRed,
                        child: Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                          style: const TextStyle(fontSize: 28, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(displayName, style: Theme.of(context).textTheme.titleLarge),
                            if (profile?.email != null || session?.email != null)
                              Text(profile?.email ?? session?.email ?? ''),
                            if (profile?.phone != null || session?.phone != null)
                              Text(profile?.phone ?? session?.phone ?? ''),
                            if (profile?.nationality != null)
                              Text('Nationality: ${profile!.nationality}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_editing) ...[
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _firstName,
                        decoration: const InputDecoration(
                          labelText: 'First name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _lastName,
                        decoration: const InputDecoration(
                          labelText: 'Last name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nationality,
                        decoration: const InputDecoration(
                          labelText: 'Nationality',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setState(() => _editing = false),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primaryRed,
                              ),
                              onPressed: _save,
                              child: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                SectionCard(
                  title: 'Immigration Profile',
                  subtitle: 'Education, work, languages, destination',
                  icon: Icons.badge_outlined,
                  onTap: () => setState(() => _editing = true),
                  trailing: const Icon(Icons.chevron_right),
                  child: Text(
                    profile == null
                        ? 'Tap edit to complete your immigration profile.'
                        : 'Name: $displayName\n'
                            'Nationality: ${profile.nationality ?? '—'}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
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
                title: 'AI Assistant',
                subtitle: 'Ask immigration questions',
                icon: Icons.smart_toy_outlined,
                onTap: () => context.go('/ai-assistant'),
                trailing: const Icon(Icons.chevron_right),
              ),
            ],
          );
        },
      ),
    );
  }
}
