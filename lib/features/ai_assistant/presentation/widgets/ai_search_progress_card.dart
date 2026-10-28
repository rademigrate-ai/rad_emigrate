import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/premium_tokens.dart';

/// Progress and status card rendered when web search is active.
class AiSearchProgressCard extends StatelessWidget {
  const AiSearchProgressCard({
    super.key,
    required this.query,
    this.isSearching = true,
  });

  final String query;
  final bool isSearching;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: AppColors.teal.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: isSearching
                ? const Padding(
                    padding: EdgeInsets.all(6),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppColors.teal),
                    ),
                  )
                : const Icon(
                    Icons.travel_explore,
                    size: 16,
                    color: AppColors.teal,
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSearching
                      ? 'در حال جستجو در پایگاه‌های رسمی و وب...'
                      : 'نتایج جستجوی زنده در پاسخ لحاظ شد',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.teal,
                  ),
                ),
                if (query.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'عبارت جستجو: $query',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
