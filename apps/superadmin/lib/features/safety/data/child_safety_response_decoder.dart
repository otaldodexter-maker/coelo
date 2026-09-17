import 'dart:convert';

import '../domain/child_safety.dart';
import '../domain/child_safety_contract.dart';

ChildSafetyDirectoryPage decodeChildSafetyDirectory(Object? payload) {
  final json = _map(payload);
  final counts = _map(json['segment_counts']);
  return ChildSafetyDirectoryPage(
    records: _list(json['items']).map((item) => decodeChildSafetyRecord(_map(item))).toList(),
    totalCount: _integer(json['total_count']),
    segmentCounts: ChildSafetySegmentCounts(
      all: _integer(counts['all']),
      awaitingApproval: _integer(counts['awaiting_approval']),
      attention: _integer(counts['attention']),
      authorized: _integer(counts['authorized']),
      withoutAuthorization: _integer(counts['without_authorization']),
    ),
    canCreate: json['can_create'] == true,
    nextCursor: _cursor(json['next_cursor']),
    previousCursor: _cursor(json['previous_cursor']),
  );
}

ChildSafetyRecord decodeChildSafetyRecord(Object? payload) {
  final json = _map(payload);
  final contexts = _list(json['contexts']);
  final context = contexts.isEmpty ? json : _map(contexts.first);
  return ChildSafetyRecord(
    childId: _string(json['child_id']),
    childName: _string(json['child_name'] ?? json['display_name']),
    internalId: _nullableString(context['internal_id']) ?? '',
    institutionName: _string(context['institution_name']),
    unitName: _string(context['unit_name']),
    childContextId: _nullableString(json['child_context_id'] ?? context['child_context_id']),
    institutionId: _nullableString(json['institution_id'] ?? context['institution_id']),
    unitId: _nullableString(json['unit_id'] ?? context['unit_id']),
    directorySegment: _segment(json['segment']),
    authorizationCount: _integer(json['authorization_count']),
    directoryPendingCount: _integer(json['pending_count'] ?? json['awaiting_approval_count']),
    authorizations: _list(json['authorizations']).map((item) {
      final authorization = _map(item);
      final authorizationContext = _contextFor(
        contexts,
        childContextId: _nullableString(authorization['child_context_id']),
        unitId: _nullableString(authorization['unit_id']),
      );
      return PickupAuthorization(
        id: _string(authorization['id']),
        name: _string(authorization['name']),
        relationship: _string(
          authorization['relationship_detail'] ?? authorization['relationship_code'],
        ),
        institutionName: _string(authorizationContext['institution_name']),
        unitName: _string(authorizationContext['unit_name']),
        personId: _nullableString(authorization['person_id']),
        // B6: pessoa sem conta = authorized_people sem person_id.
        hasAppAccount: _nullableString(authorization['person_id']) != null,
        childContextId: _nullableString(authorization['child_context_id']),
        unitId: _nullableString(authorization['unit_id']),
        capabilityCodes: _list(authorization['capability_codes']).whereType<String>().toSet(),
        requestReason: _nullableString(authorization['request_reason']),
        status: _decision(authorization['decision_status']),
        lifecycleStatus: _lifecycle(authorization['lifecycle_status']),
        origin: authorization['origin'] == 'guardian'
            ? PickupAuthorizationOrigin.guardian
            : PickupAuthorizationOrigin.institution,
        startsAt: _date(authorization['valid_from']),
        endsAt: _date(authorization['valid_until']),
        lifetime: authorization['valid_until'] == null,
        version: _integer(authorization['version'], fallback: 1),
      );
    }).toList(),
  );
}

List<ChildSafetyChildOption> decodeChildSafetyOptions(Object? payload) {
  return _list(payload).expand((item) {
    final child = _map(item);
    final contexts = _list(child['contexts']);
    return contexts.map((value) {
      final context = _map(value);
      return ChildSafetyChildOption(
        id: _string(child['id'] ?? child['child_id']),
        name: _string(child['display_name'] ?? child['child_name']),
        internalId: _nullableString(child['internal_id']),
        childContextId: _nullableString(context['child_context_id']),
        institutionId: _nullableString(context['institution_id']),
        institutionName: _string(context['institution_name']),
        unitId: _nullableString(context['unit_id']),
        unitName: _string(context['unit_name']),
      );
    });
  }).toList();
}

/// Payload de `superadmin_person_search_v1` (spec 061): `{ok, kind, results}`.
/// Somente os campos minimizados sao lidos; qualquer chave extra e ignorada.
List<ChildSafetyPersonMatch> decodeChildSafetyPersonMatches(Object? payload) {
  final envelope = _map(payload);
  return _list(envelope['results']).map((item) {
    final person = _map(item);
    final personId = _string(person['person_id']);
    final displayName = _string(person['display_name']);
    if (personId.isEmpty || displayName.isEmpty) {
      throw const ChildSafetyUnavailableException();
    }
    return ChildSafetyPersonMatch(
      personId: personId,
      displayName: displayName,
      initials: _string(person['initials']),
      matchedBy: _string(person['matched_by']),
      handle: _nullableString(person['handle']),
      phoneLast4: _nullableString(person['phone_last4']),
      hasAccount: person['has_account'] == true,
      children: _list(person['children']).map((value) {
        final child = _map(value);
        return ChildSafetyChildOption(
          id: _string(child['child_id']),
          name: _string(child['child_name']),
          childContextId: _nullableString(child['child_context_id']),
          institutionId: _nullableString(child['institution_id']),
          institutionName: _string(child['institution_name']),
          unitId: _nullableString(child['unit_id']),
          unitName: _string(child['unit_name']),
        );
      }).toList(),
    );
  }).toList();
}

PersonWithoutAccountRegistration decodePersonWithoutAccountRegistration(Object? payload) {
  final json = _map(payload);
  final id = _string(json['authorized_person_id']);
  if (id.isEmpty) throw const ChildSafetyUnavailableException();
  return PersonWithoutAccountRegistration(
    authorizedPersonId: id,
    displayName: _string(json['display_name']),
    cpfMasked: _string(json['cpf_masked']),
    existing: json['existing'] == true,
    documentStatus: _string(json['document_status']),
  );
}

Map<String, Object?> _map(Object? value) =>
    value is Map ? value.map((key, item) => MapEntry(key.toString(), item)) : const {};
List<Object?> _list(Object? value) => value is List ? value : const [];
String _string(Object? value) => value is String ? value : '';
String? _nullableString(Object? value) {
  if (value == null) return null;
  if (value is! String) throw const ChildSafetyUnavailableException();
  return value.isEmpty ? null : value;
}

int _integer(Object? value, {int fallback = 0}) =>
    value is int ? value : int.tryParse(value?.toString() ?? '') ?? fallback;
DateTime? _date(Object? value) => value is String ? DateTime.tryParse(value) : null;
String? _cursor(Object? value) => value == null
    ? null
    : value is String
    ? value
    : jsonEncode(value);

PickupAuthorizationStatus _decision(Object? value) => switch (value) {
  'approved' => PickupAuthorizationStatus.approved,
  'rejected' => PickupAuthorizationStatus.rejected,
  _ => PickupAuthorizationStatus.pending,
};

PickupAuthorizationLifecycleStatus _lifecycle(Object? value) => switch (value) {
  'inactive' => PickupAuthorizationLifecycleStatus.inactive,
  'active' => PickupAuthorizationLifecycleStatus.active,
  'suspended' => PickupAuthorizationLifecycleStatus.suspended,
  'expired' => PickupAuthorizationLifecycleStatus.expired,
  'revoked' || 'archived' => PickupAuthorizationLifecycleStatus.revoked,
  _ => PickupAuthorizationLifecycleStatus.unavailable,
};

ChildSafetyDirectorySegment _segment(Object? value) => switch (value) {
  'awaiting_approval' => ChildSafetyDirectorySegment.awaitingApproval,
  'attention' => ChildSafetyDirectorySegment.attention,
  'authorized' => ChildSafetyDirectorySegment.authorized,
  _ => ChildSafetyDirectorySegment.withoutAuthorization,
};

Map<String, Object?> _contextFor(
  List<Object?> contexts, {
  required String? childContextId,
  required String? unitId,
}) {
  for (final value in contexts) {
    final context = _map(value);
    if (_nullableString(context['child_context_id']) == childContextId &&
        _nullableString(context['unit_id']) == unitId) {
      return context;
    }
  }
  return const {};
}
