import 'dart:collection';

import 'child_safety.dart';

enum ChildSafetyDirectoryView { cards, table }

final class ChildSafetyDirectoryQuery {
  ChildSafetyDirectoryQuery({
    this.search = '',
    Set<String> institutionIds = const {},
    Set<String> unitIds = const {},
    this.segment = ChildSafetyDirectorySegment.all,
    this.view = ChildSafetyDirectoryView.cards,
    this.cursor,
    this.pageIndex = 0,
    int? pageSize,
  }) : institutionIds = UnmodifiableSetView(Set<String>.of(institutionIds)),
       unitIds = UnmodifiableSetView(Set<String>.of(unitIds)),
       pageSize = pageSize ?? (view == ChildSafetyDirectoryView.cards ? 11 : 8),
       assert(pageIndex >= 0),
       assert(
         pageSize == null ||
             (view == ChildSafetyDirectoryView.cards
                 ? cardPageSizes.contains(pageSize)
                 : tablePageSizes.contains(pageSize)),
       );

  static const cardPageSizes = {11, 20, 50, 100};
  static const tablePageSizes = {8, 20, 50, 100};

  final String search;
  final Set<String> institutionIds;
  final Set<String> unitIds;
  final ChildSafetyDirectorySegment segment;
  final ChildSafetyDirectoryView view;
  final String? cursor;
  final int pageIndex;
  final int pageSize;

  bool get hasActiveFilters =>
      search.trim().isNotEmpty ||
      institutionIds.isNotEmpty ||
      unitIds.isNotEmpty ||
      segment != ChildSafetyDirectorySegment.all;
}

final class ChildSafetySegmentCounts {
  const ChildSafetySegmentCounts({
    this.all = 0,
    this.awaitingApproval = 0,
    this.attention = 0,
    this.authorized = 0,
    this.withoutAuthorization = 0,
  });

  final int all;
  final int awaitingApproval;
  final int attention;
  final int authorized;
  final int withoutAuthorization;

  int operator [](ChildSafetyDirectorySegment segment) => switch (segment) {
    ChildSafetyDirectorySegment.all => all,
    ChildSafetyDirectorySegment.awaitingApproval => awaitingApproval,
    ChildSafetyDirectorySegment.attention => attention,
    ChildSafetyDirectorySegment.authorized => authorized,
    ChildSafetyDirectorySegment.withoutAuthorization => withoutAuthorization,
  };
}

final class ChildSafetyDirectoryPage {
  const ChildSafetyDirectoryPage({
    required this.records,
    required this.totalCount,
    required this.segmentCounts,
    required this.canCreate,
    this.nextCursor,
    this.previousCursor,
  });

  final List<ChildSafetyRecord> records;
  final int totalCount;
  final ChildSafetySegmentCounts segmentCounts;
  final bool canCreate;
  final String? nextCursor;
  final String? previousCursor;
}

final class ChildSafetyChildOption {
  const ChildSafetyChildOption({
    required this.id,
    required this.name,
    required this.institutionName,
    required this.unitName,
    this.internalId,
    this.childContextId,
    this.institutionId,
    this.unitId,
  });

  final String id;
  final String name;
  final String? internalId;
  final String? childContextId;
  final String? institutionId;
  final String institutionName;
  final String? unitId;
  final String unitName;
}

final class ChildSafetyEvidence {
  const ChildSafetyEvidence({
    required this.objectPath,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.checksumSha256,
  });
  final String objectPath;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final String checksumSha256;
}

final class SavePickupAuthorizationCommand {
  const SavePickupAuthorizationCommand({
    required this.requestId,
    required this.childId,
    required this.childContextId,
    required this.unitId,
    required this.personId,
    required this.relationshipCode,
    required this.capabilityCodes,
    required this.requestReason,
    this.authorizationId,
    this.expectedVersion = 1,
    this.relationshipDetail,
    this.validFrom,
    this.validUntil,
  });
  final String requestId;
  final String childId;
  final String childContextId;
  final String unitId;
  final String personId;
  final String? authorizationId;
  final int expectedVersion;
  final String relationshipCode;
  final String? relationshipDetail;
  final Set<String> capabilityCodes;
  final String requestReason;
  final DateTime? validFrom;
  final DateTime? validUntil;
}

final class TransitionPickupAuthorizationCommand {
  const TransitionPickupAuthorizationCommand({
    required this.requestId,
    required this.childId,
    required this.authorizationId,
    required this.status,
    required this.reason,
    this.expectedVersion = 1,
  });
  final String requestId;
  final String childId;
  final String authorizationId;
  final PickupAuthorizationStatus status;
  final String reason;
  final int expectedVersion;
}

final class SuspendPickupAuthorizationCommand {
  const SuspendPickupAuthorizationCommand({
    required this.requestId,
    required this.childId,
    required this.authorizationId,
    required this.reason,
    this.expectedVersion = 1,
  });
  final String requestId;
  final String childId;
  final String authorizationId;
  final String reason;
  final int expectedVersion;
}

abstract interface class ChildSafetyRepository {
  Future<ChildSafetyDirectoryPage> fetchDirectory(ChildSafetyDirectoryQuery query);
  Future<ChildSafetyRecord?> fetchChild(String childId);
  Future<List<ChildSafetyChildOption>> searchChildren(String query, {int limit = 20});
  Future<void> saveAuthorization(SavePickupAuthorizationCommand command);
  Future<void> transitionAuthorization(TransitionPickupAuthorizationCommand command);
  Future<void> suspendAuthorization(SuspendPickupAuthorizationCommand command);
  Future<void> requestExport(ChildSafetyExportCommand command);
}

final class ChildSafetyExportCommand {
  const ChildSafetyExportCommand({
    required this.requestId,
    this.format = 'csv',
    this.filters = const {},
  });
  final String requestId;
  final String format;
  final Map<String, Object?> filters;
}

final class ChildSafetyUnauthorizedException implements Exception {
  const ChildSafetyUnauthorizedException();
}

final class ChildSafetyNotFoundException implements Exception {
  const ChildSafetyNotFoundException();
}

final class ChildSafetyConflictException implements Exception {
  const ChildSafetyConflictException();
}

final class ChildSafetyValidationException implements Exception {
  const ChildSafetyValidationException();
}

final class ChildSafetyUnavailableException implements Exception {
  const ChildSafetyUnavailableException();
}

final class UnavailableChildSafetyRepository implements ChildSafetyRepository {
  const UnavailableChildSafetyRepository();
  Future<T> _fail<T>() => Future<T>.error(const ChildSafetyUnavailableException());
  @override
  Future<ChildSafetyDirectoryPage> fetchDirectory(ChildSafetyDirectoryQuery query) => _fail();
  @override
  Future<ChildSafetyRecord?> fetchChild(String childId) => _fail();
  @override
  Future<List<ChildSafetyChildOption>> searchChildren(String query, {int limit = 20}) => _fail();
  @override
  Future<void> saveAuthorization(SavePickupAuthorizationCommand command) => _fail();
  @override
  Future<void> transitionAuthorization(TransitionPickupAuthorizationCommand command) => _fail();
  @override
  Future<void> suspendAuthorization(SuspendPickupAuthorizationCommand command) => _fail();
  @override
  Future<void> requestExport(ChildSafetyExportCommand command) => _fail();
}
