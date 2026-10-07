import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';

enum RadBrandSize { small, medium, large }

/// Shared RAD identity mark and wordmark.
///
/// Keeping the asset selection here prevents screens from drifting into
/// one-off logo treatments and leaves room for future dark/light branding.
class RadBrand extends StatelessWidget {
  const RadBrand({
    super.key,
    this.size = RadBrandSize.medium,
    this.showInstituteName = true,
    this.darkSurface = false,
  });

  final RadBrandSize size;
  final bool showInstituteName;
  final bool darkSurface;

  double get _height => switch (size) {
    RadBrandSize.small => 48,
    RadBrandSize.medium => 84,
    RadBrandSize.large => 116,
  };

  @override
  Widget build(BuildContext context) {
    const asset = 'assets/branding/rad_official_logo.png';
    final label = AppLocalizations.of(context).appTitle;

    return Semantics(
      label: label,
      image: true,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Image.asset(
          asset,
          height: _height,
          width: _height * 1.94,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) =>
              _FallbackMark(size: _height, label: label),
        ),
      ),
    );
  }
}

class _FallbackMark extends StatelessWidget {
  const _FallbackMark({required this.size, required this.label});

  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primaryRed,
          borderRadius: BorderRadius.circular(size * 0.24),
        ),
        child: Text(
          'R',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.55,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
