import 'package:flutter/material.dart';

/// Deterministic photography for destination cards when the schema has no
/// image column. URLs are static Unsplash source links (no API key).
///
/// Missing codes fall back to a neutral skyline plate so UI never invents
/// immigration content.
abstract final class CountryPhotography {
  static const _fallback =
      'https://images.unsplash.com/photo-1488085061387-422e29b40080?auto=format&fit=crop&w=1200&q=80';

  static const Map<String, String> _byCode = {
    'CA':
        'https://images.unsplash.com/photo-1519834785169-98be25ec3f84?auto=format&fit=crop&w=1200&q=80',
    'AU':
        'https://images.unsplash.com/photo-1506973035872-a4ec16b8e8d9?auto=format&fit=crop&w=1200&q=80',
    'DE':
        'https://images.unsplash.com/photo-1467269204594-9661b134dd2b?auto=format&fit=crop&w=1200&q=80',
    'TR':
        'https://images.unsplash.com/photo-1524231757912-21f4fe3a7200?auto=format&fit=crop&w=1200&q=80',
    'GB':
        'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?auto=format&fit=crop&w=1200&q=80',
    'US':
        'https://images.unsplash.com/photo-1485738422979-f5c462d49f74?auto=format&fit=crop&w=1200&q=80',
    'FR':
        'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?auto=format&fit=crop&w=1200&q=80',
    'NL':
        'https://images.unsplash.com/photo-1534351590666-13e3e96b5017?auto=format&fit=crop&w=1200&q=80',
    'IT':
        'https://images.unsplash.com/photo-1523906834658-6e24ef2386f9?auto=format&fit=crop&w=1200&q=80',
    'ES':
        'https://images.unsplash.com/photo-1543783207-ec64e4d95325?auto=format&fit=crop&w=1200&q=80',
    'AE':
        'https://images.unsplash.com/photo-1512453979798-5ea833fbd51e?auto=format&fit=crop&w=1200&q=80',
    'NZ':
        'https://images.unsplash.com/photo-1507699622108-4be3abd695ad?auto=format&fit=crop&w=1200&q=80',
    'IE':
        'https://images.unsplash.com/photo-1590089415225-401ed6f9db8e?auto=format&fit=crop&w=1200&q=80',
    'SE':
        'https://images.unsplash.com/photo-1509356843151-3e7d96241e11?auto=format&fit=crop&w=1200&q=80',
    'NO':
        'https://images.unsplash.com/photo-1520769669658-f07657f5a3fa?auto=format&fit=crop&w=1200&q=80',
    'DK':
        'https://images.unsplash.com/photo-1513622470522-26c3c8a59899?auto=format&fit=crop&w=1200&q=80',
    'FI':
        'https://images.unsplash.com/photo-1538332574038-a960c3e9f0c3?auto=format&fit=crop&w=1200&q=80',
    'CH':
        'https://images.unsplash.com/photo-1527668752968-14dc70a27c95?auto=format&fit=crop&w=1200&q=80',
    'AT':
        'https://images.unsplash.com/photo-1516550893923-42d28e5677af?auto=format&fit=crop&w=1200&q=80',
    'JP':
        'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?auto=format&fit=crop&w=1200&q=80',
    'KR':
        'https://images.unsplash.com/photo-1517154421773-0529f29ea451?auto=format&fit=crop&w=1200&q=80',
    'SG':
        'https://images.unsplash.com/photo-1525625293386-3f8f99389edd?auto=format&fit=crop&w=1200&q=80',
  };

  static String urlForCode(String code) =>
      _byCode[code.toUpperCase()] ?? _fallback;

  static ImageProvider providerForCode(String code) =>
      NetworkImage(urlForCode(code));

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
