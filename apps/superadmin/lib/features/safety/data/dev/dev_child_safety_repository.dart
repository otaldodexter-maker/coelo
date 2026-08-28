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

  DevChildSafetyRepository.content()
    : this(records: developmentChildSafetyRecords, children: developmentChildSafetyChildren);

  final List<ChildSafetyRecord> _seed;
  List<ChildSafetyRecord> _records;
  final List<ChildSafetyChildOption> _children;

  void resetSession() => _records = List.of(_seed);

  @override
  Future<ChildSafetyDirectoryPage> fetchDirectory(ChildSafetyDirectoryQuery query) async {
    final needle = query.search.trim().toLowerCase();
    final filtered = _records.where((record) {
      final textMatch = needle.isEmpty || record.childName.toLowerCase().contains(needle);
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
  Future<List<ChildSafetyChildOption>> searchChildren(String query, {int limit = 20}) async =>
      _children
          .where((child) => child.name.toLowerCase().contains(query.trim().toLowerCase()))
          .take(limit)
          .toList();

  @override
  Future<void> saveAuthorization(SavePickupAuthorizationCommand command) async {
    final record = await fetchChild(command.childId);
    if (record == null) throw const ChildSafetyNotFoundException();
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
    _records = [for (final record in _records) record.childId == value.childId ? value : record];
  }
}

final developmentChildSafetyRecords = <ChildSafetyRecord>[
  ChildSafetyRecord(
    childId: 'child-1',
    childName: 'Ana Criança',
    internalId: 'RA 1001',
    institutionName: 'Instituição Aurora',
    unitName: 'Unidade Centro',
    childContextId: 'context-1',
    institutionId: 'institution-1',
    unitId: 'unit-1',
    directorySegment: ChildSafetyDirectorySegment.awaitingApproval,
    authorizationCount: 1,
    directoryPendingCount: 1,
    authorizations: [
      PickupAuthorization(
        id: 'auth-1',
        name: 'Maria Martins',
        relationship: 'Mãe',
        institutionName: 'Instituição Aurora',
        unitName: 'Unidade Centro',
        status: PickupAuthorizationStatus.pending,
        origin: PickupAuthorizationOrigin.guardian,
        personId: 'person-1',
        childContextId: 'context-1',
        unitId: 'unit-1',
        capabilityCodes: const {'pickup', 'emergency_contact'},
        requestReason: 'Solicitação familiar',
        startsAt: DateTime(2026, 8, 1),
      ),
    ],
  ),
  const ChildSafetyRecord(
    childId: 'child-2',
    childName: 'Caio Criança',
    internalId: 'RA 1002',
    institutionName: 'Instituição Aurora',
    unitName: 'Unidade Norte',
    childContextId: 'context-2',
    institutionId: 'institution-1',
    unitId: 'unit-2',
    directorySegment: ChildSafetyDirectorySegment.withoutAuthorization,
    authorizations: [],
  ),
  ChildSafetyRecord(
    childId: 'child-3',
    childName: 'Lia Criança',
    internalId: 'RA 1003',
    institutionName: 'Instituto Horizonte',
    unitName: 'Unidade Jardim',
    childContextId: 'context-3',
    institutionId: 'institution-2',
    unitId: 'unit-3',
    directorySegment: ChildSafetyDirectorySegment.authorized,
    authorizationCount: 1,
    authorizations: [
      PickupAuthorization(
        id: 'auth-2',
        name: 'Paulo Santos',
        relationship: 'Avô',
        institutionName: 'Instituto Horizonte',
        unitName: 'Unidade Jardim',
        status: PickupAuthorizationStatus.approved,
        origin: PickupAuthorizationOrigin.institution,
        personId: 'person-2',
        childContextId: 'context-3',
        unitId: 'unit-3',
        capabilityCodes: const {'pickup'},
        requestReason: 'Autorização conferida pela unidade',
        startsAt: DateTime(2026, 1, 1),
      ),
    ],
  ),
];

const developmentChildSafetyChildren = <ChildSafetyChildOption>[
  ChildSafetyChildOption(
    id: 'child-1',
    name: 'Ana Criança',
    internalId: 'RA 1001',
    childContextId: 'context-1',
    institutionId: 'institution-1',
    institutionName: 'Instituição Aurora',
    unitId: 'unit-1',
    unitName: 'Unidade Centro',
  ),
  ChildSafetyChildOption(
    id: 'child-2',
    name: 'Caio Criança',
    internalId: 'RA 1002',
    childContextId: 'context-2',
    institutionId: 'institution-1',
    institutionName: 'Instituição Aurora',
    unitId: 'unit-2',
    unitName: 'Unidade Norte',
  ),
  ChildSafetyChildOption(
    id: 'child-3',
    name: 'Lia Criança',
    internalId: 'RA 1003',
    childContextId: 'context-3',
    institutionId: 'institution-2',
    institutionName: 'Instituto Horizonte',
    unitId: 'unit-3',
    unitName: 'Unidade Jardim',
  ),
];

extension on Iterable<ChildSafetyRecord> {
  ChildSafetyRecord? get firstOrNull => isEmpty ? null : first;
}
