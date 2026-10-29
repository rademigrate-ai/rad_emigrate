import 'package:flutter/material.dart';

import '../theme/premium_tokens.dart';
import 'app_card.dart';
import 'directional_icons.dart';
import 'rad_ai_bird.dart';

/// Compact, content-sized components from the client-approved mobile boards.
/// No sample names, case percentages or document metadata are synthesized here.
class ReferenceSection extends StatelessWidget {
  const ReferenceSection({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (action != null)
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 40),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: onAction,
            child: Text(action!),
          ),
      ],
    ),
  );
}

class ReferenceIcon extends StatelessWidget {
  const ReferenceIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
  });
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      gradient: RadialGradient(
        colors: [color.withValues(alpha: .18), color.withValues(alpha: .04)],
      ),
      border: Border.all(color: color.withValues(alpha: .08)),
    ),
    child: Icon(icon, color: color, size: size * .52),
  );
}

class ReferenceQuickAction extends StatelessWidget {
  const ReferenceQuickAction({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Column(
          children: [
            AppCard(
              padding: const EdgeInsets.all(9),
              child: ReferenceIcon(icon: icon, color: color),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Licensed project mountain photography with a pearl / midnight atmospheric
/// treatment. The original bird renderer and assets remain authoritative.
class ReferenceScenery extends StatelessWidget {
  const ReferenceScenery({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = context.premium.isDark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/destinations/ch.jpg',
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: dark
                      ? const [
                          Color(0xD9081726),
                          Color(0xB30B1522),
                          Color(0xD82A1020),
                        ]
                      : const [
                          Color(0xE6F9F2FA),
                          Color(0xC4E4F2FF),
                          Color(0xCEE0F0FC),
                        ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class ReferenceJourneyHero extends StatelessWidget {
  const ReferenceJourneyHero({
    super.key,
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
  });
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => ReferenceScenery(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  constraints.maxWidth < 270 ||
                  MediaQuery.textScalerOf(context).scale(20) > 28;
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800, height: 1.45),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    body,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: context.premium.text, height: 1.65),
                  ),
                ],
              );
              const bird = ExcludeSemantics(
                child: RadAiBird(
                  size: 116,
                  semanticLabel: '',
                  showBackgroundOrb: false,
                  state: RadAiBirdState.idle,
                ),
              );
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: bird),
                    const SizedBox(height: 12),
                    copy,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 3, child: copy),
                  const SizedBox(width: 4),
                  const Expanded(flex: 2, child: bird),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            onPressed: onAction,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.public_outlined, size: 20),
                  const SizedBox(width: 10),
                  Flexible(child: Text(action)),
                  const SizedBox(width: 12),
                  Icon(directionalChevron(context), size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Flags are displayed only for explicit known country values. Unknown free
/// text remains a neutral globe; it never inherits a sample destination.
String? referenceCountryCode(String value) {
  final normalized = value.trim().toLowerCase();
  const names = <String, List<String>>{
    'CA': ['ca', 'canada', 'کانادا'],
    'DE': ['de', 'germany', 'آلمان'],
    'AU': ['au', 'australia', 'استرالیا'],
    'GB': ['gb', 'uk', 'united kingdom', 'انگلستان', 'بریتانیا'],
    'US': ['us', 'united states', 'آمریکا'],
    'IR': ['ir', 'iran', 'ایران'],
  };
  for (final entry in names.entries) {
    if (entry.value.contains(normalized)) return entry.key;
  }
  return null;
}

class ReferenceFlag extends StatelessWidget {
  const ReferenceFlag({super.key, required this.country, this.size = 38});
  final String country;
  final double size;
  @override
  Widget build(BuildContext context) {
    final code = referenceCountryCode(country);
    final flag = code == null
        ? null
        : String.fromCharCodes(code.codeUnits.map((c) => c + 127397));
    return Semantics(
      label: country,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.premium.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: flag == null
            ? const Icon(Icons.public_outlined)
            : Text(flag, style: TextStyle(fontSize: size * .67)),
      ),
    );
  }
}
