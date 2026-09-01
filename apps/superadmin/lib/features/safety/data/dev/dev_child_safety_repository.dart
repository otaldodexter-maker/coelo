import '../../../../app/dev_menu/development_access_health_fixture_catalog.dart';
import '../../domain/child_safety_contract.dart';
import '../../domain/child_safety.dart';

/// Stateful, deterministic repository used only by development previews.
final class DevChildSafetyRepository implements ChildSafetyRepository {
  DevChildSafetyRepository({
    List<ChildSafetyRecord> records = const [],
    List<ChildSafetyChildOption> children = const [],
  }) : _seed = List.unmodifiable(records),
       _records = List.of(records),
       _children = List.of(children);

  factory DevChildSafetyRepository.content({DevelopmentAccessHealthFixtureCatalog? catalog}) {
    final fixtures = catalog ?? DevelopmentAccessHealthFixtureCatalog.standard();
    return DevChildSafetyRepository(
      records: _developmentRecords(fixtures),
      children: _developmentChildren(fixtures),
    );
  }

  final List<ChildSafetyRecord> _seed;
  List<ChildSafetyRecord> _records;
  final List<ChildSafetyChildOption> _children;

  void resetSession() => _records = List.of(_seed);

  @override
  Future<ChildSafetyDirectoryPage> fetchDirectory(ChildSafetyDirectoryQuery query) async {
    final needle = query.search.trim().toLowerCase();
    final filtered = _records.where((record) {
      final textMatch =
          needle.isEmpty ||
          record.childName.toLowerCase().contains(needle) ||
          record.internalId.toLowerCase().contains(needle);
      final institutionMatch =
          query.institutionIds.isEmpty || query.institutionIds.contains(record.institutionId);
      final unitMatch = query.unitIds.isEmpty || query.unitIds.contains(record.unitId);
      final segmentMatch =
          query.segment == ChildSafetyDirectorySegment.all ||
          record.directorySegment == query.segment;
      return textMatch && institutionMatch && unitMatch && segmentMatch;
    }).toList();
    final start = query.pageIndex * query.pageSize;
    final end = (start + query.pageSize).clamp(0, filtered.length);
    return ChildSafetyDirectoryPage(
      records: start >= filtered.length ? const [] : filtered.sublist(start, end),
      totalCount: filtered.length,
      segmentCounts: _counts(),
      canCreate: true,
      nextCursor: end < filtered.length ? '$end' : null,
      previousCursor: start > 0 ? '${(start - query.pageSize).clamp(0, filtered.length)}' : null,
    );
  }

  ChildSafetySegmentCounts _counts() => ChildSafetySegmentCounts(
    all: _records.length,
    awaitingApproval: _records
        .where((r) => r.directorySegment == ChildSafetyDirectorySegment.awaitingApproval)
        .length,
    attention: _records
        .where((r) => r.directorySegment == ChildSafetyDirectorySegment.attention)
        .length,
    authorized: _records
        .where((r) => r.directorySegment == ChildSafetyDirectorySegment.authorized)
        .length,
    withoutAuthorization: _records
        .where((r) => r.directorySegment == ChildSafetyDirectorySegment.withoutAuthorization)
        .length,
  );

  @override
  Future<ChildSafetyRecord?> fetchChild(String childId) async =>
      _records.where((record) => record.childId == childId).firstOrNull;

  @override
  Future<List<ChildSafetyChildOption>> searchChildren(String query, {int limit = 20}) async {
    final needle = query.trim().toLowerCase();
    return _children
        .where(
          (child) =>
              child.name.toLowerCase().contains(needle) ||
              (child.internalId?.toLowerCase().contains(needle) ?? false),
        )
        .take(limit)
        .toList();
  }

  @override
  Future<void> saveAuthorization(SavePickupAuthorizationCommand command) async {
    final record = await fetchChild(command.childId) ?? _emptyRecord(command.childId);
    final authorization = PickupAuthorization(
      id: command.authorizationId ?? 'authorization-${record.authorizations.length + 1}',
      name: command.personId,
      relationship: command.relationshipCode,
      institutionName: record.institutionName,
      unitName: record.unitName,
      status: PickupAuthorizationStatus.pending,
      origin: PickupAuthorizationOrigin.institution,
      personId: command.personId,
      childContextId: command.childContextId,
      unitId: command.unitId,
      capabilityCodes: command.capabilityCodes,
      requestReason: command.requestReason,
      startsAt: command.validFrom,
      endsAt: command.validUntil,
    );
    _replace(record.withAuthorizations([...record.authorizations, authorization]));
  }

  @override
  Future<void> transitionAuthorization(TransitionPickupAuthorizationCommand command) async {
    final record = await fetchChild(command.childId);
    if (record == null) throw const ChildSafetyNotFoundException();
    final updated = record.authorizations
        .map((item) => item.id == command.authorizationId ? item.withStatus(command.status) : item)
        .toList();
    _replace(record.withAuthorizations(updated));
  }

  @override
  Future<void> removeAuthorization(RemovePickupAuthorizationCommand command) async {
    final record = await fetchChild(command.childId);
    if (record == null) throw const ChildSafetyNotFoundException();
    _replace(
      record.withAuthorizations(
        record.authorizations.where((item) => item.id != command.authorizationId).toList(),
      ),
    );
  }

  @override
  Future<void> requestExport(ChildSafetyExportCommand command) async {}

  void _replace(ChildSafetyRecord value) {
    final exists = _records.any((record) => record.childId == value.childId);
    _records = [
      for (final record in _records) record.childId == value.childId ? value : record,
      if (!exists) value,
    ];
  }

  ChildSafetyRecord _emptyRecord(String childId) {
    final child = _children.where((option) => option.id == childId).firstOrNull;
    if (child == null) throw const ChildSafetyNotFoundException();
    return ChildSafetyRecord(
      childId: child.id,
      childName: child.name,
      internalId: child.internalId ?? '',
      institutionName: child.institutionName,
      unitName: child.unitName,
      childContextId: child.childContextId,
      institutionId: child.institutionId,
      unitId: child.unitId,
      authorizations: const [],
    );
  }
}

List<ChildSafetyChildOption> _developmentChildren(DevelopmentAccessHealthFixtureCatalog catalog) =>
    [
      for (final child in catalog.children)
        ChildSafetyChildOption(
          id: child.id,
          name: child.name,
          internalId: child.privateIdentifier,
          childContextId: child.groupId,
          institutionId: child.institutionId,
          institutionName: child.institutionName,
          unitId: child.unitId,
          unitName: child.unitName,
        ),
    ];

List<ChildSafetyRecord> _developmentRecords(DevelopmentAccessHealthFixtureCatalog catalog) {
  final children = {for (final child in catalog.children) child.id: child};
  final adults = {
    for (final adult in [...catalog.guardians, ...catalog.teamMembers]) adult.id: adult,
  };
  return [
    for (final (recordIndex, fixture) in catalog.safetyRecords.indexed)
      _developmentRecord(fixture, children[fixture.childId]!, adults, recordIndex),
  ];
}

ChildSafetyRecord _developmentRecord(
  DevelopmentSafetyFixture fixture,
  DevelopmentChildFixture child,
  Map<String, DevelopmentAdultFixture> adults,
  int recordIndex,
) {
  final authorized = [
    for (var index = 0; index < fixture.authorizedPeopleCount; index++)
      _authorization(
        id: '${fixture.id}-approved-${index + 1}',
        adult: adults[child.guardianIds[index % child.guardianIds.length]]!,
        child: child,
        index: index,
        status: PickupAuthorizationStatus.approved,
      ),
  ];
  final pending = [
    for (var index = 0; index < fixture.pendingRequestsCount; index++)
      _authorization(
        id: '${fixture.id}-pending-${index + 1}',
        adult: adults[child.guardianIds[index % child.guardianIds.length]]!,
        child: child,
        index: index,
        status: PickupAuthorizationStatus.pending,
      ),
  ];
  final attention = fixture.status == DevelopmentSafetyStatus.attention
      ? [
          _authorization(
            id: '${fixture.id}-attention',
            adult: adults[child.guardianIds.first]!,
            child: child,
            index: recordIndex,
            status: PickupAuthorizationStatus.rejected,
          ),
        ]
      : const <PickupAuthorization>[];
  return ChildSafetyRecord(
    childId: child.id,
    childName: child.name,
    internalId: child.privateIdentifier,
    institutionName: child.institutionName,
    unitName: child.unitName,
    childContextId: child.groupId,
    institutionId: child.institutionId,
    unitId: child.unitId,
    directorySegment: switch (fixture.status) {
      DevelopmentSafetyStatus.authorized => ChildSafetyDirectorySegment.authorized,
      DevelopmentSafetyStatus.awaitingApproval => ChildSafetyDirectorySegment.awaitingApproval,
      DevelopmentSafetyStatus.attention => ChildSafetyDirectorySegment.attention,
      DevelopmentSafetyStatus.noAuthorization => ChildSafetyDirectorySegment.withoutAuthorization,
    },
    authorizationCount: fixture.authorizedPeopleCount,
    directoryPendingCount: fixture.pendingRequestsCount,
    authorizations: [...authorized, ...pending, ...attention],
  );
}

PickupAuthorization _authorization({
  required String id,
  required DevelopmentAdultFixture adult,
  required DevelopmentChildFixture child,
  required int index,
  required PickupAuthorizationStatus status,
}) => PickupAuthorization(
  id: id,
  name: adult.name,
  relationship: const ['Mãe', 'Pai', 'Avó', 'Tia'][index % 4],
  institutionName: child.institutionName,
  unitName: child.unitName,
  status: status,
  origin: PickupAuthorizationOrigin.guardian,
  personId: adult.id,
  childContextId: child.groupId,
  unitId: child.unitId,
  capabilityCodes: const {'pickup', 'emergency_contact'},
  requestReason: status == PickupAuthorizationStatus.pending
      ? 'Solicitação familiar aguardando revisão da unidade.'
      : 'Vínculo familiar conferido pela unidade.',
  startsAt: DateTime(2026, 1 + index % 12, 1 + index % 27),
  lifetime: index % 5 == 0,
  hasAppAccount: true,
);

extension on Iterable<ChildSafetyRecord> {
  ChildSafetyRecord? get firstOrNull => isEmpty ? null : first;
}
