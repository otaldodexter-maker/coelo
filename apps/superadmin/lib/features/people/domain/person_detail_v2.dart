import 'person_directory.dart';

/// Decodes only the spec 046 read response, never a legacy list/write payload.
/// This checks transport integrity, not actor authorization or tenant scope.
PersonDirectoryItem decodePersonDetailV2(Object? value, {required String requestedId}) {
  final envelope = _map(value, const {'ok', 'data', 'error'});
  if (envelope['ok'] == false) {
    if (envelope['data'] != null) _invalid();
    final error = _map(envelope['error'], const {
      'code',
      'message',
      'correlation_id',
      'http_status',
    });
    final code = _text(error['code']);
    _text(error['message']);
    _text(error['correlation_id']);
    if (error['http_status'] is! int) _invalid();
    if (const {
      'SAI_AUTH_REQUIRED',
      'SAI_SESSION_INVALID',
      'SAI_INTERNAL_CONTEXT_DENIED',
      'SAI_MEMBERSHIP_SUSPENDED',
      'SAI_MEMBERSHIP_REVOKED',
      'SAI_PERMISSION_DENIED',
      'SAI_MFA_REQUIRED',
    }.contains(code)) {
      throw const PersonDirectoryUnauthorizedException();
    }
    _invalid();
  }
  if (envelope['ok'] != true || envelope['error'] != null) _invalid();
  final data = _map(envelope['data'], const {
    'id',
    'first_name',
    'last_name',
    'display_name',
    'legal_name',
    'type',
    'status',
    'auth_link',
    'memberships',
    'child_contexts',
    'updated_at',
  });
  final id = _uuid(data['id']);
  if (id.toLowerCase() != requestedId.toLowerCase()) _invalid();
  final type = PersonType.values.where((type) => type.databaseValue == data['type']).firstOrNull;
  final status = PersonStatus.values
      .where((status) => status.databaseValue == data['status'])
      .firstOrNull;
  final auth = AuthLinkStatus.values
      .where((auth) => auth.databaseValue == data['auth_link'])
      .firstOrNull;
  // record_status.suspended is valid upstream but not representable by the
  // legacy PersonDirectoryItem. Keep unavailable; never invent another status.
  if (type == null || status == null || auth == null) _invalid();
  final memberships = _list(data['memberships']).map(_membership).toList(growable: false);
  final contexts = _list(data['child_contexts']).map(_context).toList(growable: false);
  if (type != PersonType.child && contexts.isNotEmpty) _invalid();
  final updatedAt = _timestamp(data['updated_at']);
  return PersonDirectoryItem(
    id: id,
    firstName: _text(data['first_name']),
    lastName: _text(data['last_name']),
    displayName: _text(data['display_name']),
    legalName: _nullableText(data['legal_name']),
    type: type,
    status: status,
    authLink: auth,
    memberships: List.unmodifiable(memberships),
    childContexts: List.unmodifiable(contexts),
    updatedAt: updatedAt.toUtc(),
  );
}

PersonMembership _membership(Object? value) {
  final data = _map(value, const {
    'id',
    'membership_id',
    'institution_id',
    'institution_name',
    'unit_id',
    'unit_name',
    'group_id',
    'group_name',
    'role',
    'is_platform',
  });
  if (data['is_platform'] != false) _invalid();
  return PersonMembership(
    id: _uuid(data['id']),
    membershipId: _nullableUuid(data['membership_id']),
    institutionId: _uuid(data['institution_id']),
    institutionName: _text(data['institution_name']),
    unitId: _nullableUuid(data['unit_id']),
    unitName: _nullableText(data['unit_name']),
    groupId: _nullableUuid(data['group_id']),
    groupName: _nullableText(data['group_name']),
    role: _text(data['role']),
  );
}

PersonChildContext _context(Object? value) {
  final data = _map(value, const {
    'id',
    'institution_id',
    'institution_name',
    'unit_id',
    'unit_name',
    'group_id',
    'group_name',
    'child_unit_link_id',
    'child_group_link_id',
  });
  return PersonChildContext(
    id: _uuid(data['id']),
    institutionId: _uuid(data['institution_id']),
    institutionName: _text(data['institution_name']),
    unitId: _nullableUuid(data['unit_id']),
    unitName: _nullableText(data['unit_name']),
    groupId: _nullableUuid(data['group_id']),
    groupName: _nullableText(data['group_name']),
    childUnitLinkId: _nullableUuid(data['child_unit_link_id']),
    childGroupLinkId: _nullableUuid(data['child_group_link_id']),
  );
}

Map<String, Object?> _map(Object? value, Set<String> keys) {
  if (value is! Map || value.length != keys.length || !keys.every(value.containsKey)) _invalid();
  return Map<String, Object?>.from(value);
}

List<Object?> _list(Object? value) => value is List ? value : _invalid();
String _text(Object? value) => value is String ? value : _invalid();
String? _nullableText(Object? value) => value == null ? null : _text(value);
String? _nullableUuid(Object? value) => value == null ? null : _uuid(value);
String _uuid(Object? value) {
  final id = _text(value);
  if (!RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$').hasMatch(id)) _invalid();
  return id;
}

Never _invalid() => throw const PersonDirectoryUnavailableException();

DateTime _timestamp(Object? value) {
  final text = _text(value);
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?(?:Z|[+-](\d{2}):(\d{2}))$',
  ).firstMatch(text);
  if (match == null) _invalid();
  int part(int index) => int.parse(match.group(index)!);
  final year = part(1);
  final month = part(2);
  final day = part(3);
  final calendar = DateTime.utc(year, month, day);
  if (calendar.year != year ||
      calendar.month != month ||
      calendar.day != day ||
      part(4) > 23 ||
      part(5) > 59 ||
      part(6) > 59 ||
      (match.group(7) != null && (part(7) > 23 || part(8) > 59))) {
    _invalid();
  }
  return DateTime.tryParse(text)?.toUtc() ?? _invalid();
}
