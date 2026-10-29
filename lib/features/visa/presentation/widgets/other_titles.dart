import 'package:flutter/material.dart';

import '../../../../core/widgets/directional_icons.dart';

import 'package:go_router/go_router.dart';

/// One collection shared by country and continuous article pages. Links are
/// deduplicated by identity, never by potentially ambiguous display title.
class OtherTitles extends StatelessWidget {
  const OtherTitles({
    super.key,
    required this.items,
    required this.locale,
    this.preview = false,
  });
  final List<Map<String, dynamic>> items;
  final String locale;
  final bool preview;

  @override
  Widget build(BuildContext context) {
    final seen = <String>{};
    final unique = items
        .where((e) => e['id'] is String && seen.add(e['id'] as String))
        .toList();
    if (unique.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text(
          locale == 'fa' ? 'دیگر عناوین' : 'Other Titles',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        for (final item in unique)
          Card(
            child: ListTile(
              title: Text(item['title'] as String? ?? ''),
              trailing: Icon(directionalForward(context)),
              onTap: () => context.push(
                '/visa/content/${item['id']}?locale=$locale${preview ? '&preview=true' : ''}',
              ),
            ),
          ),
      ],
    );
  }
}
