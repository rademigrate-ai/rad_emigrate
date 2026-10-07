import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

enum RadBrandSize { small, medium, large }

/// The owner-supplied RAD emblem with its original proportions and transparency.
///
/// Renders the asset without an artificial opaque backing so the transparent
/// WebP/PNG background is preserved on application surfaces.
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
      child: Image.asset(
        asset,
        height: _height,
        width: _height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
      ),
    );
  }
}
