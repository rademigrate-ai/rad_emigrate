import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/section_card.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
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
      body: ListView(
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
                      (session?.fullName?.isNotEmpty == true)
                          ? session!.fullName![0].toUpperCase()
                          : 'U',
                      style: const TextStyle(fontSize: 28, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session?.fullName ?? 'User',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (session?.email != null) Text(session!.email!),
                        if (session?.phone != null) Text(session!.phone!),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Immigration Profile',
            subtitle: 'Education, work, languages, destination',
            icon: Icons.badge_outlined,
            child: const Text(
              'Profile fields (education, work experience, languages, marital status, destination preference) are prepared for future API sync.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),
          SectionCard(
            title: 'Saved Content',
            subtitle: 'Bookmarks and saved programs',
            icon: Icons.bookmark_outline,
          ),
          const SizedBox(height: 8),
          SectionCard(
            title: 'AI Conversation History',
            subtitle: 'Past assistant chats',
            icon: Icons.chat_bubble_outline,
          ),
          const SizedBox(height: 8),
          SectionCard(
            title: 'Subscription & Usage',
            subtitle: 'AI questions and packages',
            icon: Icons.credit_card_outlined,
          ),
        ],
      ),
    );
  }
}
