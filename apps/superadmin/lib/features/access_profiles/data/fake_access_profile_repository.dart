import '../domain/access_profile.dart';

/// Fixtures determinísticas para dev, catálogo e testes.
///
/// Nunca deve ser conectada ao caminho de produção ou usada para autorização.
final class FakeAccessProfileRepository
    implements AccessProfileRepository, AccessProfileDuplicator {
  FakeAccessProfileRepository({
    List<AccessProfile> profiles = demoAccessProfiles,
    List<PrincipalCapability> capabilities = demoPrincipalCapabilities,
  }) : _profiles = [...profiles],
       _capabilities = [...capabilities];

  final List<AccessProfile> _profiles;
  final List<PrincipalCapability> _capabilities;

  @override
  bool get isDemo => true;

  @override
  Future<AccessProfilePage> fetchProfiles(AccessProfileQuery query) async {
    var filtered = _profiles.where((item) => item.domain == query.domain);
    final search = query.search.trim().toLowerCase();
    if (search.isNotEmpty) {
      filtered = filtered.where(
        (item) =>
            item.name.toLowerCase().contains(search) ||
            item.description.toLowerCase().contains(search),
      );
    }
    if (query.statuses.isNotEmpty) {
      filtered = filtered.where((item) => query.statuses.contains(item.status));
    }
    if (query.scopes.isNotEmpty) {
      filtered = filtered.where((item) => query.scopes.contains(item.maxScope));
    }
    final ordered = filtered.toList()..sort((left, right) => left.name.compareTo(right.name));
    final start = query.page * query.pageSize;
    final items = start >= ordered.length
        ? const <AccessProfile>[]
        : ordered.sublist(start, (start + query.pageSize).clamp(0, ordered.length));
    return AccessProfilePage(
      items: items,
      totalCount: ordered.length,
      page: query.page,
      pageSize: query.pageSize,
      isDemo: true,
    );
  }

  @override
  Future<AccessProfile> fetchDetail(AccessProfileDomain domain, String profileId) async =>
      _profiles.firstWhere((item) => item.domain == domain && item.id == profileId);

  @override
  Future<AccessProfile> fetchTemplate(AccessProfileDomain domain) async {
    final permissions = domain == AccessProfileDomain.platform
        ? _platformPermissions
        : _institutionPermissions;
    return AccessProfile(
      id: '',
      domain: domain,
      code: '',
      name: '',
      description: '',
      status: AccessProfileStatus.active,
      maxScope: domain == AccessProfileDomain.platform
          ? AccessProfileScope.platform
          : AccessProfileScope.institution,
      version: 0,
      membershipCount: 0,
      permissions: permissions
          .map((permission) => permission.withSelection(false))
          .toList(growable: false),
    );
  }

  @override
  Future<List<PrincipalCapability>> fetchPrincipalCapabilities() async =>
      List.unmodifiable(_capabilities);

  @override
  Future<AccessProfile> save({
    required String requestId,
    required int expectedVersion,
    required String reason,
    required AccessProfile draft,
  }) async {
    final index = _profiles.indexWhere((item) => item.id == draft.id);
    if (index >= 0 && _profiles[index].version != expectedVersion) {
      throw const AccessProfileConflictException();
    }
    final saved = draft.copyWith(
      id: draft.id.isEmpty ? 'demo-profile-${_profiles.length + 1}' : draft.id,
      version: index < 0 ? 1 : expectedVersion + 1,
    );
    if (index < 0) {
      _profiles.add(saved);
    } else {
      _profiles[index] = saved;
    }
    return saved;
  }

  @override
  Future<void> deleteAndReassign({
    required String requestId,
    required AccessProfileDomain domain,
    required String profileId,
    required int expectedVersion,
    required String? replacementProfileId,
    required String reason,
  }) async {
    final item = await fetchDetail(domain, profileId);
    if (item.version != expectedVersion) {
      throw const AccessProfileConflictException();
    }
    if (item.membershipCount > 0 && replacementProfileId == null) {
      throw const AccessProfileException('Selecione um perfil para realocar os vínculos.');
    }
    _profiles.removeWhere((profile) => profile.id == profileId);
  }

  @override
  Future<AccessProfile> duplicate({
    required String requestId,
    required String sourceProfileId,
    required AccessProfileDomain domain,
    required String name,
    required String reason,
  }) async {
    final source = await fetchDetail(domain, sourceProfileId);
    final duplicate = source.copyWith(
      id: 'demo-profile-${_profiles.length + 1}',
      code: '${source.code}.copy.${_profiles.length + 1}',
      name: name.trim(),
      status: AccessProfileStatus.inactive,
      version: 1,
      membershipCount: 0,
      isSystem: false,
      links: const [],
      auditEvents: const [],
      auditAvailable: false,
      localAssignments: const [],
    );
    _profiles.add(duplicate);
    return duplicate;
  }
}

const _platformPermissions = [
  AccessPermission(
    code: 'platform.read',
    module: 'Plataforma',
    screenCode: 'platform',
    actionCode: 'read',
    name: 'Visualizar plataforma',
    description: 'Consulta dados operacionais da plataforma.',
    selected: true,
  ),
  AccessPermission(
    code: 'audit.read',
    module: 'Auditoria',
    screenCode: 'audit',
    actionCode: 'read',
    name: 'Visualizar auditoria',
    description: 'Consulta a trilha de ações sensíveis.',
    selected: true,
    risk: 'high',
    requiresMfa: true,
  ),
  AccessPermission(
    code: 'platform.roles.manage',
    module: 'Perfis',
    screenCode: 'access_profiles',
    actionCode: 'manage',
    name: 'Gerenciar perfis Superadmin',
    description: 'Cria, edita e exclui perfis da plataforma.',
    selected: true,
    risk: 'critical',
    requiresMfa: true,
  ),
  AccessPermission(
    code: 'support.manage',
    module: 'Suporte',
    screenCode: 'support',
    actionCode: 'manage',
    name: 'Gerenciar suporte',
    description: 'Opera atendimentos internos.',
    grantable: false,
    unavailableReason: 'Você não possui support.manage.',
  ),
];

const _institutionPermissions = [
  AccessPermission(
    code: 'people.read',
    module: 'Pessoas',
    screenCode: 'people',
    actionCode: 'read',
    name: 'Visualizar pessoas',
    selected: true,
  ),
  AccessPermission(
    code: 'people.manage',
    module: 'Pessoas',
    screenCode: 'people',
    actionCode: 'manage',
    name: 'Gerenciar pessoas',
    selected: true,
    risk: 'high',
  ),
  AccessPermission(
    code: 'attendance.read',
    module: 'Frequência',
    screenCode: 'attendance',
    actionCode: 'read',
    name: 'Visualizar frequência',
    selected: true,
  ),
  AccessPermission(
    code: 'chat.moderate',
    module: 'Comunicação',
    screenCode: 'chat',
    actionCode: 'moderate',
    name: 'Moderar conversas',
    risk: 'high',
  ),
];

const demoAccessProfiles = <AccessProfile>[
  AccessProfile(
    id: 'demo-owner',
    domain: AccessProfileDomain.platform,
    code: 'owner',
    name: 'Owner',
    description: 'Autoridade total da plataforma com MFA obrigatório.',
    status: AccessProfileStatus.active,
    maxScope: AccessProfileScope.platform,
    version: 3,
    membershipCount: 1,
    isSystem: true,
    permissions: _platformPermissions,
    localAssignments: [
      AccessProfileAssignment(
        context: AccessAssignmentContext.institution,
        label: 'Colégio Horizonte',
      ),
    ],
  ),
  AccessProfile(
    id: 'demo-support',
    domain: AccessProfileDomain.platform,
    code: 'support',
    name: 'Suporte',
    description: 'Atendimento interno com acesso minimizado.',
    status: AccessProfileStatus.active,
    maxScope: AccessProfileScope.institution,
    version: 1,
    membershipCount: 4,
    isSystem: true,
    permissions: _platformPermissions,
    localAssignments: [
      AccessProfileAssignment(
        context: AccessAssignmentContext.activity,
        label: 'Atendimento de implantação',
      ),
    ],
  ),
  AccessProfile(
    id: 'demo-admin-owner',
    domain: AccessProfileDomain.institution,
    code: 'institution_owner',
    name: 'Administrador geral',
    description: 'Gestão completa de uma instituição.',
    status: AccessProfileStatus.active,
    maxScope: AccessProfileScope.institution,
    version: 2,
    membershipCount: 8,
    isSystem: true,
    permissions: _institutionPermissions,
    localAssignments: [
      AccessProfileAssignment(context: AccessAssignmentContext.unit, label: 'Unidade Centro'),
    ],
  ),
  AccessProfile(
    id: 'demo-coordinator',
    domain: AccessProfileDomain.institution,
    code: 'coordinator',
    name: 'Coordenação',
    description: 'Gestão limitada à unidade atribuída.',
    status: AccessProfileStatus.active,
    maxScope: AccessProfileScope.unit,
    version: 1,
    membershipCount: 16,
    permissions: _institutionPermissions,
    localAssignments: [
      AccessProfileAssignment(context: AccessAssignmentContext.group, label: 'Turma Girassol'),
    ],
  ),
];

const demoPrincipalCapabilities = <PrincipalCapability>[
  PrincipalCapability(
    id: 'demo-view-context',
    code: 'view_context',
    name: 'Visualizar contexto',
    description: 'Visualizar dados autorizados da criança.',
    contextCount: 128,
  ),
  PrincipalCapability(
    id: 'demo-message',
    code: 'message',
    name: 'Conversar',
    description: 'Conversar nos contextos autorizados.',
    contextCount: 96,
  ),
  PrincipalCapability(
    id: 'demo-react',
    code: 'react',
    name: 'Reagir',
    description: 'Reagir a publicações autorizadas.',
    contextCount: 91,
  ),
  PrincipalCapability(
    id: 'demo-authorized-people',
    code: 'manage_authorized_people',
    name: 'Gerenciar pessoas autorizadas',
    description: 'Cadastrar pessoas autorizadas para a criança.',
    contextCount: 72,
  ),
  PrincipalCapability(
    id: 'demo-attendance',
    code: 'manage_attendance_notices',
    name: 'Gerenciar avisos de presença',
    description: 'Informar ausência, atraso e saída antecipada.',
    contextCount: 64,
  ),
];
