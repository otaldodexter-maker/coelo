final class PrincipalRuntimeContext {
  const PrincipalRuntimeContext({
    required this.membershipId,
    required this.personId,
    required this.institutionId,
    required this.institutionName,
    required this.roleCode,
    required this.scopeKind,
    this.unitId,
    this.unitName,
    this.groupId,
    this.groupName,
  });

  final String membershipId;
  final String personId;
  final String institutionId;
  final String institutionName;
  final String roleCode;
  final String scopeKind;
  final String? unitId;
  final String? unitName;
  final String? groupId;
  final String? groupName;
}

abstract interface class PrincipalRuntimeContextRepository {
  Future<List<PrincipalRuntimeContext>> listAvailableContexts();
}

final class UnavailablePrincipalRuntimeContextRepository
    implements PrincipalRuntimeContextRepository {
  const UnavailablePrincipalRuntimeContextRepository();

  @override
  Future<List<PrincipalRuntimeContext>> listAvailableContexts() =>
      Future.error(const PrincipalRuntimeContextUnavailable());
}

final class PrincipalRuntimeContextUnauthorized implements Exception {
  const PrincipalRuntimeContextUnauthorized();
}

final class PrincipalRuntimeContextUnavailable implements Exception {
  const PrincipalRuntimeContextUnavailable();
}
