import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/premium_tokens.dart';

/// Card offering seamless navigation to human expert consultation when AI detects complex legal needs.
class AiAdviserHandoffCard extends StatelessWidget {
  const AiAdviserHandoffCard({
    super.key,
    this.reason = 'برای بررسی دقیق‌تر شرایط و پرونده مهاجرتی شما، مشاوره با کارشناسان و وکلای رسمی راد توصیه می‌شود.',
  });

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: AppColors.navy.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  size: 18,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'مشاوره تخصصی با کارشناسان و وکلای مهاجرتی راد',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            reason,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                '🔒 اطلاعات شما تنها با رضایت مستقیم ارسال خواهد شد.',
                style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => context.push('/consultation'),
                icon: const Icon(Icons.calendar_today_outlined, size: 14),
                label: const Text(
                  'درخواست وقت مشاوره',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
