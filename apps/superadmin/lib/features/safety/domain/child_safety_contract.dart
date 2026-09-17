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

/// Transport support only; this never replaces server-side authorization.
/// Real adapters must opt in only after their write contract is qualified.
abstract interface class ChildSafetyMutationSupport {
  bool get mutationsEnabled;
}

/// Busca de pessoa autorizada (ADR 0041 B5, spec 061): leitor unico,
/// resultado minimizado pelo servidor. Adapters sem o contrato nao a expoem e o
/// controlador falha fechado.
abstract interface class ChildSafetyPersonSearchSupport {
  Future<List<ChildSafetyPersonMatch>> searchPeople(String query);
}

/// Pessoa candidata devolvida por `superadmin_person_search_v1`: nome,
/// iniciais, `@handle`, ultimos 4 digitos do celular e as criancas vinculadas
/// dentro do escopo do ator. CPF, e-mail e celular inteiro nunca chegam aqui.
final class ChildSafetyPersonMatch {
  const ChildSafetyPersonMatch({
    required this.personId,
    required this.displayName,
    required this.initials,
    required this.matchedBy,
    this.handle,
    this.phoneLast4,
    this.hasAccount = false,
    this.children = const [],
  });

  final String personId;
  final String displayName;
  final String initials;
  final String matchedBy;
  final String? handle;
  final String? phoneLast4;
  final bool hasAccount;
  final List<ChildSafetyChildOption> children;
}

enum ChildSafetyPersonSearchKind { name, handle, email, digits }

/// Deteccao do tipo e do minimo de caracteres, espelhando a regra do servidor
/// (nome/@/e-mail >= 3 caracteres; celular/CPF >= 4 digitos, com ou sem
/// mascara). A tela so consulta o servidor quando `ready` e verdadeiro.
final class ChildSafetyPersonSearchReadiness {
  const ChildSafetyPersonSearchReadiness({
    required this.kind,
    required this.ready,
    required this.minimum,
    required this.length,
  });

  final ChildSafetyPersonSearchKind kind;
  final bool ready;
  final int minimum;
  final int length;

  int get remaining => ready ? 0 : minimum - length;
}

final _digitsOnlyQuery = RegExp(r'^[0-9\s().+\-]+$');
final _nonDigit = RegExp(r'\D');

ChildSafetyPersonSearchReadiness childSafetyPersonSearchReadiness(String raw) {
  final value = raw.trim();
  final digits = value.replaceAll(_nonDigit, '');
  if (value.startsWith('@')) {
    final needle = value.substring(1).trim();
    return ChildSafetyPersonSearchReadiness(
      kind: ChildSafetyPersonSearchKind.handle,
      ready: needle.length >= 3,
      minimum: 3,
      length: needle.length,
    );
  }
  if (value.contains('@')) {
    return ChildSafetyPersonSearchReadiness(
      kind: ChildSafetyPersonSearchKind.email,
      ready: value.length >= 3,
      minimum: 3,
      length: value.length,
    );
  }
  if (value.isNotEmpty && digits.isNotEmpty && _digitsOnlyQuery.hasMatch(value)) {
    return ChildSafetyPersonSearchReadiness(
      kind: ChildSafetyPersonSearchKind.digits,
      ready: digits.length >= 4,
      minimum: 4,
      length: digits.length,
    );
  }
  return ChildSafetyPersonSearchReadiness(
    kind: ChildSafetyPersonSearchKind.name,
    ready: value.length >= 3,
    minimum: 3,
    length: value.length,
  );
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

/// Limite de taxa da busca de pessoa (SQLSTATE PT422, PERSON_SEARCH_RATE_LIMIT).
final class ChildSafetyRateLimitException implements Exception {
  const ChildSafetyRateLimitException();
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
