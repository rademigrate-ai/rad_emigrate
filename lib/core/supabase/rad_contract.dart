import 'dart:convert';
import 'dart:math';

import 'rad_contract_schemas.dart';

/// Closed v1 schemas generated from the reviewed registry. Invalid data never
/// becomes a successful CMS acknowledgement or an apparently certain AI reply.
void requireRadContract(String name, Object? value) {
  if (!_valid(radContractSchemas[name] as Map?, value, 0)) {
    throw FormatException('invalid_contract:$name');
  }
}

bool _valid(Map? schema, Object? value, int depth) {
  if (schema == null || depth > 32) return false;
  final reference = schema[r'$ref'];
  if (reference is String) {
    return _valid(
      radContractSchemas[reference.split('/').last] as Map?,
      value,
      depth + 1,
    );
  }
  for (final variant in ['anyOf', 'oneOf']) {
    if (schema[variant] is List) {
      final matches = (schema[variant] as List)
          .where((s) => _valid(s as Map, value, depth + 1))
          .length;
      return variant == 'oneOf' ? matches == 1 : matches > 0;
    }
  }
  if (schema.containsKey('const') && schema['const'] != value) return false;
  if (schema['enum'] is List && !(schema['enum'] as List).contains(value)) {
    return false;
  }
  final type = schema['type'];
  if (type != null &&
      !switch (type) {
        'null' => value == null,
        'object' => value is Map && value.keys.every((k) => k is String),
        'array' => value is List,
        'string' => value is String,
        'boolean' => value is bool,
        'integer' => value is int,
        'number' => value is num && value.isFinite,
        _ => false,
      }) {
    return false;
  }
  if (value is Map) {
    if ((schema['required'] as List? ?? []).any((k) => !value.containsKey(k))) {
      return false;
    }
    final properties = schema['properties'] as Map? ?? {};
    for (final key in value.keys) {
      if (!properties.containsKey(key)) {
        if (schema['additionalProperties'] == false) return false;
      } else if (!_valid(properties[key] as Map, value[key], depth + 1)) {
        return false;
      }
    }
  } else if (value is List) {
    if (value.length < (schema['minItems'] as int? ?? 0) ||
        value.length > (schema['maxItems'] as int? ?? 10000)) {
      return false;
    }
    if (schema['uniqueItems'] == true &&
        value.map(jsonEncode).toSet().length != value.length) {
      return false;
    }
    if (schema['items'] is Map &&
        value.any((v) => !_valid(schema['items'] as Map, v, depth + 1))) {
      return false;
    }
  } else if (value is String) {
    if (value.runes.length < (schema['minLength'] as int? ?? 0) ||
        value.runes.length > (schema['maxLength'] as int? ?? 2000000)) {
      return false;
    }
    if (schema['pattern'] is String &&
        !RegExp(schema['pattern'] as String).hasMatch(value)) {
      return false;
    }
    if (schema['format'] == 'date-time' || schema['format'] == 'date') {
      if (schema['format'] == 'date-time' &&
          !RegExp(
            r'^\d{4}-\d{2}-\d{2}T(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d(?:\.\d+)?Z$',
          ).hasMatch(value)) {
        return false;
      }
      final date = DateTime.tryParse(value);
      if (date == null ||
          !value.startsWith(
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
          )) {
        return false;
      }
    }
  } else if (value is num) {
    if (!value.isFinite ||
        (schema['minimum'] is num && value < (schema['minimum'] as num)) ||
        (schema['maximum'] is num && value > (schema['maximum'] as num))) {
      return false;
    }
  }
  return true;
}

String newRadRequestKey() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}
