import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

/// Read-only source snapshot, used only when the public CMS reader RPC is not
/// installed. Never used for administrator previews, writes or approvals.
/// The dynamic CMS is authoritative when its public endpoints are installed.
class FrozenVisaContent {
  FrozenVisaContent({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  late final Future<List<Map<String, dynamic>>> _rows = _loadIndex();

  Future<List<Map<String, dynamic>>> _loadIndex() async {
    final text = await _bundle.loadString(
      'assets/visa_frozen_content/index.json',
    );
    final decoded = jsonDecode(text);
    if (decoded is! Map ||
        decoded['format'] != 'RAD_FROZEN_VISA_DELIVERY_V1' ||
        decoded['editorial_approved'] != false ||
        decoded['update_mode'] != 'read_only' ||
        decoded['total_candidates'] != 1077 ||
        decoded['held_excluded'] != 23 ||
        decoded['countries_count'] != 56 ||
        decoded['independent_other_titles'] != 251 ||
        decoded['articles'] is! List) {
      throw const FormatException('invalid_frozen_visa_index');
    }
    final rows = (decoded['articles'] as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
    if (rows.length != 1077 ||
        rows.any(
          (r) =>
              r['editorial_approved'] == true ||
              r['id'] is! String ||
              r['locale'] is! String ||
              r['asset'] is! String ||
              r['sha256'] is! String ||
              r['compressed_sha256'] is! String ||
              !RegExp(
                r'^assets/visa_frozen_content/articles/[a-f0-9-]+_(fa|en)\.json\.gz$',
              ).hasMatch(r['asset'] as String),
        )) {
      throw const FormatException('invalid_frozen_visa_manifest');
    }
    return rows;
  }

  Map<String, dynamic> _card(Map<String, dynamic> row) => {
    'id': row['id'],
    'title': row['title'],
    'locale': row['locale'],
    'country_codes': row['country_codes'],
    'content_class': row['content_class'],
    'visa_category': row['visa_category'],
    'source_publishers': row['source_publishers'],
    'delivery_mode': 'frozen_source_readonly',
    'verification_state': 'unverified',
  };

  Iterable<Map<String, dynamic>> _preferred(
    Iterable<Map<String, dynamic>> input,
    String locale,
  ) {
    final grouped = <String, Map<String, dynamic>>{};
    for (final row in input) {
      final id = row['id'] as String;
      final previous = grouped[id];
      if (previous == null ||
          (row['locale'] == locale && previous['locale'] != locale) ||
          (previous['locale'] != locale &&
              row['locale'] == 'fa' &&
              previous['locale'] != 'fa')) {
        grouped[id] = row;
      }
    }
    return grouped.values;
  }

  Future<List<Map<String, dynamic>>> countries(String locale) async {
    final rows = _preferred(await _rows, locale);
    final counts = <String, int>{};
    for (final row in rows) {
      for (final code in (row['country_codes'] as List).whereType<String>()) {
        counts.update(code, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    return [
      for (final code in counts.keys.toList()..sort())
        {'country_code': code, 'category_count': counts[code]},
    ];
  }

  Future<Map<String, dynamic>> country(String code, String locale) async {
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(code)) {
      throw const FormatException('invalid_frozen_visa_country');
    }
    final rows =
        _preferred(
          (await _rows).where(
            (r) => (r['country_codes'] as List).contains(code),
          ),
          locale,
        ).toList()..sort(
          (a, b) => (a['title'] as String).compareTo(b['title'] as String),
        );
    final categories = <Map<String, dynamic>>[];
    final other = <Map<String, dynamic>>[];
    for (final row in rows) {
      final card = _card(row);
      if (row['content_class'] == 'canonical' &&
          (row['country_codes'] as List).length == 1) {
        categories.add(card);
      } else {
        other.add(card);
      }
    }
    return {
      'country_code': code,
      'categories': categories,
      'other_titles': other,
      'preview': false,
      'delivery_mode': 'frozen_source_readonly',
    };
  }

  Future<Map<String, dynamic>> library(
    String locale,
    String? cursor, {
    int limit = 20,
  }) async {
    final offset = int.tryParse(cursor ?? '0');
    if (offset == null ||
        offset < 0 ||
        offset > 1000000 ||
        limit < 1 ||
        limit > 100) {
      throw const FormatException('invalid_frozen_library_cursor');
    }
    final items =
        _preferred(
            (await _rows).where((r) => r['content_class'] == 'editorial'),
            locale,
          ).toList()
          ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    final page = items.skip(offset).take(limit).map(_card).toList();
    final more = offset + page.length < items.length;
    return {
      'items': page,
      'has_more': more,
      'next_cursor': more ? '${offset + page.length}' : null,
      'preview': false,
      'delivery_mode': 'frozen_source_readonly',
    };
  }

  Future<Map<String, dynamic>> article(String id, String locale) async {
    if (!RegExp(
      r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$',
    ).hasMatch(id)) {
      throw const FormatException('invalid_frozen_article_id');
    }
    final rows = (await _rows).where((r) => r['id'] == id).toList();
    if (rows.isEmpty) throw const FormatException('frozen_article_not_found');
    final match = rows.firstWhere(
      (r) => r['locale'] == locale,
      orElse: () =>
          rows.firstWhere((r) => r['locale'] == 'fa', orElse: () => rows.first),
    );
    final bytes = (await _bundle.load(match['asset'] as String)).buffer
        .asUint8List();
    if (sha256.convert(bytes).toString() != match['compressed_sha256']) {
      throw const FormatException('frozen_article_asset_checksum_mismatch');
    }
    final uncompressed = Uint8List.fromList(
      GZipDecoder().decodeBytes(bytes, verify: true),
    );
    if (sha256.convert(uncompressed).toString() != match['sha256']) {
      throw const FormatException('frozen_article_content_checksum_mismatch');
    }
    final decoded = jsonDecode(utf8.decode(uncompressed));
    if (decoded is! Map ||
        decoded['id'] != id ||
        decoded['locale'] != match['locale'] ||
        decoded['revision_id'] != match['revision_id'] ||
        decoded['editorial_approved'] != false ||
        decoded['delivery_mode'] != 'frozen_source_readonly' ||
        decoded['rich_sections'] is! List) {
      throw const FormatException('frozen_article_identity_mismatch');
    }
    final data = Map<String, dynamic>.from(decoded);
    final relatedCountries = (match['country_codes'] as List)
        .whereType<String>()
        .toSet();
    final related = _preferred(
      (await _rows).where(
        (r) =>
            r['id'] != id &&
            r['content_class'] == 'editorial' &&
            relatedCountries
                .intersection(
                  (r['country_codes'] as List).whereType<String>().toSet(),
                )
                .isNotEmpty,
      ),
      locale,
    ).take(12).map(_card).toList();
    return {
      ...data,
      'other_titles': related,
      'references_capture_status': 'not_captured',
      if (match['locale'] != locale) 'requested_locale_fallback': locale,
    };
  }
}

/// Explicitly separate read-only source display from future CMS editing.
final frozenVisaContent = FrozenVisaContent();
