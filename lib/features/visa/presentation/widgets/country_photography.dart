import 'package:flutter/material.dart';

/// Deterministic, bundled photography for destination cards when the schema
/// has no image column.
///
/// Missing codes fall back to a neutral skyline plate so UI never invents
/// immigration content.
abstract final class CountryPhotography {
  static const _root = 'assets/images/destinations';
  static const _fallback = '$_root/fallback.jpg';

  static const Map<String, String> _byCode = {
    'AT': '$_root/at.jpg',
    'AU': '$_root/au.jpg',
    'CA': '$_root/ca.jpg',
    'CH': '$_root/ch.jpg',
    'DE': '$_root/de.jpg',
    'ES': '$_root/es.jpg',
    'FR': '$_root/fr.jpg',
    'GB': '$_root/gb.jpg',
    'IE': '$_root/ie.jpg',
    'IT': '$_root/it.jpg',
    'JP': '$_root/jp.jpg',
    'KR': '$_root/kr.jpg',
    'NL': '$_root/nl.jpg',
    'NZ': '$_root/nz.jpg',
    'SE': '$_root/se.jpg',
    'SG': '$_root/sg.jpg',
    'TR': '$_root/tr.jpg',
    'US': '$_root/us.jpg',
  };

  static String pathForCode(String code) =>
      _byCode[code.toUpperCase()] ?? _fallback;

  static ImageProvider providerForCode(String code) =>
      AssetImage(pathForCode(code));

  static Widget image({
    required String code,
    required BoxFit fit,
    double? width,
    double? height,
  }) {
    return Image(
      image: providerForCode(code),
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (context, error, stack) => Container(
        color: const Color(0xFF1A2A32),
        alignment: Alignment.center,
        child: const Icon(Icons.public, color: Colors.white54, size: 36),
      ),
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return Container(color: const Color(0xFF1A2A32));
      },
    );
  }
}
