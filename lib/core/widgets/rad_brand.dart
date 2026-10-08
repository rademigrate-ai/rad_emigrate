import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

enum RadBrandSize { small, medium, large }

/// The owner-supplied RAD emblem, with its original square proportions.
///
/// By default a white backing provides contrast. Set [darkSurface] to true
/// on premium dark screens (e.g. Global Time) to render without the white box.
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

    final image = Image.asset(
      asset,
      height: _height,
      width: _height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    );

    return Semantics(
      label: label,
      image: true,
      child: darkSurface
          ? image
          : Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: image,
            ),
    );
  }
}
