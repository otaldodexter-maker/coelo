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
    this.institutionHandle,
    this.unitHandle,
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

  /// O @ da instituicao (ADR 0034 Decisao 16); null enquanto o servidor nao o
  /// projetar (pacote 20260911130100).
  final String? institutionHandle;
  final String? unitHandle;

  /// O @ mais especifico do contexto, sem o prefixo.
  String? get handle => unitHandle ?? institutionHandle;

  /// Responsavel e aluno so leem; o resto da hierarquia pode publicar (P28: o
  /// botao de publicar so aparece para quem pode adicionar algo).
  bool get isGuardianRole => roleCode == 'guardian' || roleCode == 'student';
  bool get canPublish => !isGuardianRole;

  /// Nome curto para o seletor de perfil: turma, unidade ou instituicao.
  String get label => groupName ?? unitName ?? institutionName;
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

extension PrincipalScopeLabel on String {
  /// Devolve [fallback] quando a string esta vazia.
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
