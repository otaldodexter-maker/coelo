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
    internalId: _string(context['internal_id']),
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
        internalId: child['internal_id'] as String?,
        childContextId: context['child_context_id'] as String?,
        institutionId: context['institution_id'] as String?,
        institutionName: _string(context['institution_name']),
        unitId: context['unit_id'] as String?,
        unitName: _string(context['unit_name']),
      );
    });
  }).toList();
}

Map<String, Object?> _map(Object? value) =>
    value is Map ? value.map((key, item) => MapEntry(key.toString(), item)) : const {};
List<Object?> _list(Object? value) => value is List ? value : const [];
String _string(Object? value) => value is String ? value : '';
String? _nullableString(Object? value) => value is String && value.isNotEmpty ? value : null;
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
  'suspended' => PickupAuthorizationLifecycleStatus.suspended,
  'expired' => PickupAuthorizationLifecycleStatus.expired,
  'revoked' || 'archived' || 'inactive' => PickupAuthorizationLifecycleStatus.revoked,
  _ => PickupAuthorizationLifecycleStatus.active,
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
  return contexts.isEmpty ? const {} : _map(contexts.first);
}
