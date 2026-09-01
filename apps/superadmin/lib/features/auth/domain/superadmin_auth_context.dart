enum SuperadminAuthScopeKind { platform, institution }

final class SuperadminAuthContext {
  const SuperadminAuthContext({
    required this.platformRoleCode,
    required this.scopeKind,
    this.scopeInstitutionId,
    required this.permissionCodes,
    required this.aal,
  });

  final String platformRoleCode;
  final SuperadminAuthScopeKind scopeKind;
  final String? scopeInstitutionId;
  final Set<String> permissionCodes;
  final String aal;
}

abstract interface class SuperadminAuthContextGateway {
  Future<SuperadminAuthContext?> bootstrap();
}

final class UnavailableSuperadminAuthContextGateway implements SuperadminAuthContextGateway {
  const UnavailableSuperadminAuthContextGateway();

  @override
  Future<SuperadminAuthContext?> bootstrap() async => null;
}
