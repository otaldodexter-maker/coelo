import 'dart:convert';

import 'package:coelo_domain/locations.dart';

final class LocationReadDeniedException implements Exception {
  const LocationReadDeniedException();

  @override
  String toString() => 'Location read denied';
}

/// Transport integrity only. This never establishes permission or ownership.
LocationCatalogEntry decodeLocationDetailV2(Object? value, {required String requestedId}) {
  final expectedId = _uuid(requestedId);
  final entry = _entry(_data(value));
  if (entry.id != expectedId) _invalid();
  return entry;
}

LocationDirectoryResult decodeLocationDirectoryV2(
  Object? value, {
  required LocationScope requestedScope,
}) {
  final institution = _uuid(requestedScope.institutionId);
  final unit = switch (requestedScope) {
    InstitutionLocationScope() => null,
    UnitLocationScope(:final unitId) => _uuid(unitId),
  };
  final data = _map(_data(value), const {'items', 'total_count'});
  final rawItems = data['items'];
  if (rawItems is! List || rawItems.length > 100) _invalid();
  final total = _integer(data['total_count'], minimum: 0);
  if (total < rawItems.length) _invalid();
  final ids = <String>{};
  final items = <LocationCatalogEntry>[];
  for (final raw in rawItems) {
    final entry = _entry(raw);
    final entryUnit = switch (entry.scope) {
      InstitutionLocationScope() => null,
      UnitLocationScope(:final unitId) => unitId,
    };
    if (entry.scope.institutionId != institution || entryUnit != unit || !ids.add(entry.id)) {
      _invalid();
    }
    items.add(entry);
  }
  return LocationDirectoryResult(items: items, totalCount: total);
}

Object? _data(Object? value) {
  final envelope = _map(value, const {'ok', 'data', 'error'});
  if (envelope['ok'] == false) {
    if (envelope['data'] != null) _invalid();
    final error = _map(envelope['error'], const {
      'code',
      'message',
      'correlation_id',
      'http_status',
    });
    final code = error['code'];
    if (code is! String || error['message'] is! String) _invalid();
    _uuid(error['correlation_id']);
    final status = _integer(error['http_status'], minimum: 400);
    if (status > 599) _invalid();
    if (const {
      'SAI_AUTH_REQUIRED',
      'SAI_SESSION_INVALID',
      'SAI_INTERNAL_CONTEXT_DENIED',
      'SAI_MEMBERSHIP_SUSPENDED',
      'SAI_MEMBERSHIP_REVOKED',
      'SAI_PERMISSION_DENIED',
      'SAI_MFA_REQUIRED',
    }.contains(code)) {
      throw const LocationReadDeniedException();
    }
    _invalid();
  }
  if (envelope['ok'] != true || envelope['error'] != null) _invalid();
  return envelope['data'];
}

LocationCatalogEntry _entry(Object? value) {
  final data = _map(value, const {
    'id',
    'scope_kind',
    'institution_id',
    'unit_id',
    'name',
    'description',
    'kind',
    'floor',
    'address',
    'visibility',
    'status',
    'management_version',
    'created_at',
    'updated_at',
  });
  final id = _uuid(data['id']);
  final institutionId = _uuid(data['institution_id']);
  final LocationScope scope;
  if (data['scope_kind'] == 'institution' && data['unit_id'] == null) {
    scope = LocationScope.institution(institutionId: institutionId);
  } else if (data['scope_kind'] == 'unit') {
    scope = LocationScope.unit(institutionId: institutionId, unitId: _uuid(data['unit_id']));
  } else {
    _invalid();
  }
  final kind = _enum(data['kind'], LocationKind.values);
  final address = _address(data['address']);
  if (kind == LocationKind.external && address == null) _invalid();
  return LocationCatalogEntry(
    id: id,
    scope: scope,
    kind: kind,
    name: _text(data['name'], 120),
    description: _nullableText(data['description'], 500),
    floor: _nullableText(data['floor'], 120),
    address: address,
    visibility: _enum(data['visibility'], LocationVisibility.values),
    status: _enum(data['status'], LocationCatalogStatus.values),
    managementVersion: _integer(data['management_version'], minimum: 1),
    createdAt: _timestamp(data['created_at']),
    updatedAt: _timestamp(data['updated_at']),
  );
}

Map<String, String?>? _address(Object? value) {
  if (value == null) return null;
  if (value is! Map || value['country'] != 'Brasil') _invalid();
  const allowed = {
    'country',
    'state',
    'city',
    'district',
    'street',
    'number',
    'complement',
    'postal_code',
  };
  final result = <String, String?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String || !allowed.contains(key)) _invalid();
    final text = _nullableText(entry.value, 240);
    final limit = key == 'country' ? 80 : (key == 'number' || key == 'postal_code' ? 64 : 240);
    if (text != null &&
        (utf8.encode(text).length > limit ||
            (key == 'postal_code' && !RegExp(r'^[0-9]{8}$').hasMatch(text)))) {
      _invalid();
    }
    result[key] = text;
  }
  return result;
}

Map<String, Object?> _map(Object? value, Set<String> keys) {
  if (value is! Map ||
      value.length != keys.length ||
      value.keys.any((key) => key is! String || !keys.contains(key))) {
    _invalid();
  }
  return Map<String, Object?>.from(value);
}

String _uuid(Object? value) {
  if (value is! String ||
      !RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(value)) {
    _invalid();
  }
  return value.toLowerCase();
}

String _text(Object? value, int limit) {
  if (value is! String ||
      value.isEmpty ||
      value.startsWith(' ') ||
      value.endsWith(' ') ||
      value.runes.length > limit ||
      value.runes.any((rune) => rune >= 0xd800 && rune <= 0xdfff) ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
    _invalid();
  }
  return value;
}

String? _nullableText(Object? value, int limit) => value == null ? null : _text(value, limit);

T _enum<T extends Enum>(Object? value, List<T> values) {
  for (final candidate in values) {
    if (candidate.name == value) return candidate;
  }
  _invalid();
}

int _integer(Object? value, {required int minimum}) {
  if (value is! int || value < minimum || value > 9007199254740991) _invalid();
  return value;
}

DateTime _timestamp(Object? value) {
  if (value is! String) _invalid();
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?(Z|[+-]\d{2}:\d{2})$',
  ).firstMatch(value);
  if (match == null) _invalid();
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final hour = int.parse(match.group(4)!);
  final minute = int.parse(match.group(5)!);
  final second = int.parse(match.group(6)!);
  final calendar = DateTime.utc(year, month, day);
  if (year < 1 ||
      calendar.year != year ||
      calendar.month != month ||
      calendar.day != day ||
      hour > 23 ||
      minute > 59 ||
      second > 59) {
    _invalid();
  }
  final zone = match.group(7)!;
  if (zone != 'Z' && (int.parse(zone.substring(1, 3)) > 23 || int.parse(zone.substring(4)) > 59)) {
    _invalid();
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) _invalid();
  return parsed.toUtc();
}

Never _invalid() => throw const FormatException('Invalid location read response');

/// The server denied the write; it never says whether the resource exists.
final class LocationWriteDeniedException implements Exception {
  const LocationWriteDeniedException();

  @override
  String toString() => 'Location write denied';
}

/// The payload does not satisfy the catalog contract.
///
/// Raised locally before transport whenever possible, and also for the
/// server's own `SAI_INVALID_ARGUMENT`, so a client bug and a server refusal
/// reach the caller the same way.
final class LocationWriteRejectedException implements Exception {
  const LocationWriteRejectedException();

  @override
  String toString() => 'Location write rejected';
}

/// The same request id was already used for a different payload.
///
/// Retrying with the identical payload is safe and returns the first result;
/// changing the payload under the same id is a conflict, never a second
/// location.
final class LocationWriteConflictException implements Exception {
  const LocationWriteConflictException();

  @override
  String toString() => 'Location write conflict';
}

/// What a consumer asks the catalog to create.
///
/// Status, ownership, provenance and audit belong to the server: this carries
/// only what the actor typed plus the scope it typed it in.
final class LocationWriteDraft {
  const LocationWriteDraft({
    required this.scope,
    required this.kind,
    required this.name,
    required this.visibility,
    this.description,
    this.floor,
    this.address,
  });

  final LocationScope scope;
  final LocationKind kind;
  final String name;
  final LocationVisibility visibility;
  final String? description;
  final String? floor;
  final Map<String, String?>? address;
}

/// Builds the create payload with exactly the nine keys the server accepts.
///
/// Every rule the server enforces is enforced here first, so a malformed draft
/// fails without spending a round trip and without reaching a function that
/// would refuse it anyway. This is convenience and honesty, never authority:
/// the server validates the same payload again.
Map<String, Object?> encodeLocationCreateV2(LocationWriteDraft draft) {
  final institutionId = _writeUuid(draft.scope.institutionId);
  final unitId = switch (draft.scope) {
    InstitutionLocationScope() => null,
    UnitLocationScope(:final unitId) => _writeUuid(unitId),
  };
  final name = _writeText(draft.name, 120);
  if (name == null) throw const LocationWriteRejectedException();
  final address = _writeAddress(draft.address);
  if (draft.kind == LocationKind.external && address == null) {
    throw const LocationWriteRejectedException();
  }
  return {
    'scope_kind': draft.scope is UnitLocationScope ? 'unit' : 'institution',
    'institution_id': institutionId,
    'unit_id': unitId,
    'name': name,
    'description': _writeText(draft.description, 500),
    'kind': draft.kind.name,
    'floor': _writeText(draft.floor, 120),
    'address': address,
    'visibility': draft.visibility.name,
  };
}

/// Reads the created location back, refusing anything outside the asked scope.
LocationCatalogEntry decodeLocationCreateV2(
  Object? value, {
  required LocationScope requestedScope,
}) {
  final entry = _entry(_writeData(value));
  final entryUnit = switch (entry.scope) {
    InstitutionLocationScope() => null,
    UnitLocationScope(:final unitId) => unitId,
  };
  final requestedUnit = switch (requestedScope) {
    InstitutionLocationScope() => null,
    UnitLocationScope(:final unitId) => unitId,
  };
  if (entry.scope.institutionId != requestedScope.institutionId || entryUnit != requestedUnit) {
    _invalid();
  }
  return entry;
}

Object? _writeData(Object? value) {
  final envelope = _map(value, const {'ok', 'data', 'error'});
  if (envelope['ok'] == false) {
    if (envelope['data'] != null) _invalid();
    final error = _map(envelope['error'], const {
      'code',
      'message',
      'correlation_id',
      'http_status',
    });
    final code = error['code'];
    if (code is! String || error['message'] is! String) _invalid();
    _uuid(error['correlation_id']);
    final status = _integer(error['http_status'], minimum: 400);
    if (status > 599) _invalid();
    if (const {
      'SAI_AUTH_REQUIRED',
      'SAI_SESSION_INVALID',
      'SAI_INTERNAL_CONTEXT_DENIED',
      'SAI_MEMBERSHIP_SUSPENDED',
      'SAI_MEMBERSHIP_REVOKED',
      'SAI_PERMISSION_DENIED',
      'SAI_MFA_REQUIRED',
    }.contains(code)) {
      throw const LocationWriteDeniedException();
    }
    if (code == 'SAI_INVALID_ARGUMENT') throw const LocationWriteRejectedException();
    if (code == 'SAI_CONCURRENT_CHANGE') throw const LocationWriteConflictException();
    _invalid();
  }
  if (envelope['ok'] != true || envelope['error'] != null) _invalid();
  return envelope['data'];
}

String _writeUuid(String value) {
  if (!RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$').hasMatch(value)) {
    throw const LocationWriteRejectedException();
  }
  return value;
}

/// Trims to null and refuses control characters, like the server does.
String? _writeText(String? value, int limit) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.length > limit || RegExp(r'[\x00-\x1f\x7f]').hasMatch(trimmed)) {
    throw const LocationWriteRejectedException();
  }
  return trimmed;
}

Map<String, Object?>? _writeAddress(Map<String, String?>? value) {
  if (value == null) return null;
  const allowed = {
    'country',
    'state',
    'city',
    'district',
    'street',
    'number',
    'complement',
    'postal_code',
  };
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (!allowed.contains(entry.key)) throw const LocationWriteRejectedException();
    final limit = entry.key == 'country'
        ? 80
        : (entry.key == 'number' || entry.key == 'postal_code' ? 64 : 240);
    final text = _writeText(entry.value, 240);
    if (text != null &&
        (utf8.encode(text).length > limit ||
            (entry.key == 'postal_code' && !RegExp(r'^[0-9]{8}$').hasMatch(text)))) {
      throw const LocationWriteRejectedException();
    }
    result[entry.key] = text;
  }
  if (result['country'] != 'Brasil') throw const LocationWriteRejectedException();
  return result;
}
