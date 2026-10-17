import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/premium_tokens.dart';
import 'country_photo_catalog.dart';

abstract final class CountryPhotography {
  // One catalog/manifest parse per app session. Images share Flutter's bounded
  // ImageCache across cards and repeat visits, without network requests.
  static final Future<CountryPhotoCatalog> catalog = CountryPhotoCatalog.load(
    rootBundle,
  );

  static Future<String> pathForCode(String code, {String? destination}) async =>
      (await catalog).resolve(code, destination: destination);

  static Widget image({
    required String code,
    required BoxFit fit,
    String? destination,
    double? width,
    double? height,
  }) => FutureBuilder<CountryPhotoCatalog>(
    future: catalog,
    builder: (context, snapshot) => _CountryPhoto(
      path:
          snapshot.data?.resolve(code, destination: destination) ??
          CountryPhotoCatalog.fallback,
      fit: fit,
      width: width,
      height: height,
    ),
  );
}

class _CountryPhoto extends StatelessWidget {
  const _CountryPhoto({
    required this.path,
    required this.fit,
    this.width,
    this.height,
  });
  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;

  Widget _plate(BuildContext context) => ColoredBox(
    color: context.premium.surfaceElevated,
    child: Center(
      child: Icon(Icons.public, color: context.premium.mutedText, size: 36),
    ),
  );

  Widget _fallback(BuildContext context) => Image.asset(
    CountryPhotoCatalog.fallback,
    fit: fit,
    width: width,
    height: height,
    excludeFromSemantics: true,
    errorBuilder: (context, _, _) => _plate(context),
  );

  @override
  Widget build(BuildContext context) => Image.asset(
    path,
    fit: fit,
    width: width,
    height: height,
    excludeFromSemantics: true,
    errorBuilder: (context, _, _) => path == CountryPhotoCatalog.fallback
        ? _plate(context)
        : _fallback(context),
    frameBuilder: (context, child, frame, synchronous) =>
        synchronous || frame != null ? child : _plate(context),
  );
}
