import '../../domain/child_safety_contract.dart';
import '../../domain/child_safety.dart';

/// Stateful, deterministic repository used only by development previews.
final class DevChildSafetyRepository implements ChildSafetyRepository {
  DevChildSafetyRepository({List<ChildSafetyRecord> records = const []})
      : _seed = List.unmodifiable(records),
        _records = List.of(records);

  final List<ChildSafetyRecord> _seed;
  List<ChildSafetyRecord> _records;
  final List<ChildSafetyChildOption> _children = [];

  void resetSession() => _records = List.of(_seed);

  @override
  Future<ChildSafetyDirectoryPage> fetchDirectory(ChildSafetyDirectoryQuery query) async {
    final needle = query.search.trim().toLowerCase();
    final filtered = _records.where((record) {
      final textMatch = needle.isEmpty || record.childName.toLowerCase().contains(needle);
      final institutionMatch = query.institutionIds.isEmpty ||
          query.institutionIds.contains(record.institutionId);
      final unitMatch = query.unitIds.isEmpty || query.unitIds.contains(record.unitId);
      final segmentMatch = query.segment == ChildSafetyDirectorySegment.all ||
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
        awaitingApproval: _records.where((r) => r.directorySegment == ChildSafetyDirectorySegment.awaitingApproval).length,
        attention: _records.where((r) => r.directorySegment == ChildSafetyDirectorySegment.attention).length,
        authorized: _records.where((r) => r.directorySegment == ChildSafetyDirectorySegment.authorized).length,
        withoutAuthorization: _records.where((r) => r.directorySegment == ChildSafetyDirectorySegment.withoutAuthorization).length,
      );

  @override
  Future<ChildSafetyRecord?> fetchChild(String childId) async =>
      _records.where((record) => record.childId == childId).firstOrNull;

  @override
  Future<List<ChildSafetyChildOption>> searchChildren(String query, {int limit = 20}) async =>
      _children.where((child) => child.name.toLowerCase().contains(query.trim().toLowerCase())).take(limit).toList();

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
    final updated = record.authorizations.map((item) => item.id == command.authorizationId ? item.withStatus(command.status) : item).toList();
    _replace(record.withAuthorizations(updated));
  }

  @override
  Future<void> removeAuthorization(RemovePickupAuthorizationCommand command) async {
    final record = await fetchChild(command.childId);
    if (record == null) throw const ChildSafetyNotFoundException();
    _replace(record.withAuthorizations(record.authorizations.where((item) => item.id != command.authorizationId).toList()));
  }

  @override
  Future<void> requestExport(ChildSafetyExportCommand command) async {}

  void _replace(ChildSafetyRecord value) {
    _records = [for (final record in _records) record.childId == value.childId ? value : record];
  }
}

extension on Iterable<ChildSafetyRecord> {
  ChildSafetyRecord? get firstOrNull => isEmpty ? null : first;
}
