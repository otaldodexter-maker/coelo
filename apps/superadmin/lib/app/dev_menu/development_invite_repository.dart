import '../../features/invites/domain/platform_invite.dart';

enum DevelopmentRepositoryMode { content, empty, failure, unauthorized }

final class DevelopmentInviteRepository implements InviteRepository {
  DevelopmentInviteRepository({
    DateTime Function()? now,
    this.mode = DevelopmentRepositoryMode.content,
  }) : _now = now ?? _utcNow,
       _invites = _seedInvites();

  final DateTime Function() _now;
  final DevelopmentRepositoryMode mode;
  final _issueReceipts = <String, InviteCommandResult>{};
  final _receipts = <String, InviteCommandResult>{};
  List<PlatformInvite> _invites;
  var _nextInviteId = 13;

  @override
  Future<InviteDirectoryResult> fetchPage(InviteDirectoryQuery query) async {
    if (mode == DevelopmentRepositoryMode.unauthorized) {
      throw const InviteUnauthorizedException();
    }
    if (mode == DevelopmentRepositoryMode.failure) {
      throw const InviteUnavailableException();
    }
    final search = query.search.trim().toLowerCase();
    final items =
        (mode == DevelopmentRepositoryMode.empty
                ? const <PlatformInvite>[]
                : _invites.where((invite) {
                    final matchesSearch =
                        search.isEmpty ||
                        [
                          invite.id,
                          invite.scope.label,
                          invite.profile.id,
                          invite.profile.label,
                          invite.recipient.personId ?? '',
                          invite.recipient.label ?? '',
                          invite.recipient.maskedEmail ?? '',
                          ...invite.channels.map((channel) => channel.label),
                          ...invite.channels.map((channel) => channel.databaseValue),
                        ].any((value) => value.toLowerCase().contains(search));
                    return matchesSearch &&
                        (query.statuses.isEmpty || query.statuses.contains(invite.status)) &&
                        (query.channels.isEmpty || invite.channels.any(query.channels.contains)) &&
                        (query.institutionIds.isEmpty ||
                            query.institutionIds.contains(invite.scope.institutionId)) &&
                        (query.unitIds.isEmpty || query.unitIds.contains(invite.scope.unitId)) &&
                        (query.groupIds.isEmpty || query.groupIds.contains(invite.scope.groupId)) &&
                        (query.profileIds.isEmpty ||
                            query.profileIds.contains(invite.profile.id)) &&
                        (query.createdFrom == null ||
                            !invite.createdAt.isBefore(query.createdFrom!.toUtc())) &&
                        (query.createdTo == null ||
                            !invite.createdAt.isAfter(query.createdTo!.toUtc()));
                  }))
            .toList()
          ..sort((left, right) {
            final byDate = left.createdAt.compareTo(right.createdAt);
            final comparison = byDate != 0 ? byDate : left.id.compareTo(right.id);
            return query.sortAscending ? comparison : -comparison;
          });
    final offset = query.offset.clamp(0, items.length);
    final end = (offset + query.pageSize).clamp(0, items.length);
    return InviteDirectoryResult(
      items: List.unmodifiable(items.sublist(offset, end)),
      totalCount: items.length,
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  @override
  Future<InviteFormOptions> fetchOptions(InviteOptionsQuery query) async {
    final search = query.search.trim().toLowerCase();
    bool matchesSearch(Iterable<String?> values) =>
        search.isEmpty ||
        values.whereType<String>().any((value) => value.toLowerCase().contains(search));
    return InviteFormOptions(
      scopes: List.unmodifiable(
        _options.scopes
            .where(
              (option) =>
                  _scopeMatchesQuery(option.scope, query) &&
                  matchesSearch([option.id, option.label, option.kind.label]),
            )
            .take(query.pageSize),
      ),
      profiles: List.unmodifiable(
        _options.profiles
            .where(
              (option) =>
                  _profileMatchesQuery(option, query) && matchesSearch([option.id, option.label]),
            )
            .take(query.pageSize),
      ),
      recipients: List.unmodifiable(
        _options.recipients
            .where(
              (option) =>
                  _scopeMatchesQuery(_recipientScopes[option.personId]!, query) &&
                  matchesSearch([option.personId, option.label, option.maskedEmail]),
            )
            .take(query.pageSize),
      ),
    );
  }

  @override
  Future<PlatformInvite?> fetchById(String inviteId) async =>
      _invites.where((item) => item.id == inviteId).firstOrNull;

  @override
  Future<InviteCommandResult> issue(InviteIssueCommand command) async {
    final scopeIsAllowed = _options.scopes.any((option) => _sameScope(option.scope, command.scope));
    final profileOption = _options.profiles
        .where((option) => option.id == command.profileId)
        .firstOrNull;
    final personOption = command.recipient.personId == null
        ? null
        : _options.recipients
              .where((option) => option.personId == command.recipient.personId)
              .firstOrNull;
    final scopeQuery = InviteOptionsQuery(
      institutionId: command.scope.institutionId,
      unitId: command.scope.unitId,
      groupId: command.scope.groupId,
    );
    final profileIsAllowed =
        profileOption != null && _profileMatchesQuery(profileOption, scopeQuery);
    final recipientIsAllowed =
        command.recipient.personId == null ||
        (personOption != null &&
            _scopeMatchesQuery(_recipientScopes[personOption.personId]!, scopeQuery));
    if (!scopeIsAllowed || !profileIsAllowed || !recipientIsAllowed) {
      throw const InviteValidationException();
    }
    final receipt = _issueReceipts[command.requestId];
    if (receipt != null) {
      return InviteCommandResult(invite: receipt.invite, replayed: true, link: receipt.link);
    }
    final occurredAt = _now().toUtc();
    final id = 'dev-invite-${_nextInviteId++}';
    final invite = PlatformInvite(
      id: id,
      scope: command.scope,
      profile: InviteProfileReference(id: command.profileId, label: profileOption.label),
      recipient: command.recipient.personId != null
          ? InviteRecipient(
              personId: command.recipient.personId,
              label: personOption?.label ?? command.recipient.personId,
              maskedEmail: personOption?.maskedEmail,
            )
          : InviteRecipient(
              maskedEmail: maskInviteRecipient(command.recipient.email!, InviteChannel.email),
            ),
      channels: Set.unmodifiable(command.channels),
      status: InviteStatus.pending,
      issuer: const InviteIssuer(personId: 'dev-owner', label: 'Owner Coelo'),
      createdAt: occurredAt,
      expiresAt: occurredAt.add(Duration(hours: command.expiresInHours)),
      emailDeliveryStatus: command.channels.contains(InviteChannel.email)
          ? InviteDeliveryStatus.sent
          : InviteDeliveryStatus.notRequested,
      managementVersion: 1,
      timeline: [InviteTimelineEntry('Convite emitido', occurredAt)],
    );
    _invites = [invite, ..._invites];
    final result = InviteCommandResult(
      invite: invite,
      replayed: false,
      link: command.channels.contains(InviteChannel.link)
          ? Uri.parse('coelo-dev://invite/$id')
          : null,
    );
    _issueReceipts[command.requestId] = result;
    return result;
  }

  @override
  Future<InviteCommandResult> resend(InviteResendCommand command) async {
    final receiptKey = '${command.inviteId}:${command.requestId}';
    final receipt = _receipts[receiptKey];
    if (receipt != null) {
      return InviteCommandResult(invite: receipt.invite, replayed: true);
    }
    final invite = (await fetchById(command.inviteId))!;
    if (invite.managementVersion != command.expectedVersion) {
      throw const InviteConflictException();
    }
    final occurredAt = _now().toUtc();
    final updated = _copyInvite(
      invite,
      status: InviteStatus.pending,
      expiresAt: occurredAt.add(const Duration(hours: 48)),
      revokedAt: null,
      managementVersion: invite.managementVersion + 1,
      timeline: [...invite.timeline, InviteTimelineEntry('Convite reenviado', occurredAt)],
    );
    _replace(updated);
    final result = InviteCommandResult(invite: updated, replayed: false);
    _receipts[receiptKey] = result;
    return result;
  }

  @override
  Future<InviteCommandResult> revoke(InviteRevokeCommand command) async {
    final receiptKey = '${command.inviteId}:${command.requestId}';
    final receipt = _receipts[receiptKey];
    if (receipt != null) {
      return InviteCommandResult(invite: receipt.invite, replayed: true);
    }
    final invite = (await fetchById(command.inviteId))!;
    if (invite.managementVersion != command.expectedVersion) {
      throw const InviteConflictException();
    }
    final occurredAt = _now().toUtc();
    final updated = _copyInvite(
      invite,
      status: InviteStatus.revoked,
      revokedAt: occurredAt,
      managementVersion: invite.managementVersion + 1,
      timeline: [...invite.timeline, InviteTimelineEntry('Convite revogado', occurredAt)],
    );
    _replace(updated);
    final result = InviteCommandResult(invite: updated, replayed: false);
    _receipts[receiptKey] = result;
    return result;
  }

  void _replace(PlatformInvite invite) {
    _invites = [
      for (final item in _invites)
        if (item.id == invite.id) invite else item,
    ];
  }
}

bool _scopeMatchesQuery(InviteScope scope, InviteOptionsQuery query) =>
    (query.institutionId == null || scope.institutionId == query.institutionId) &&
    (query.unitId == null || scope.unitId == query.unitId) &&
    (query.groupId == null || scope.groupId == query.groupId);

bool _profileMatchesQuery(InviteProfileOption profile, InviteOptionsQuery query) =>
    (query.institutionId == null || profile.institutionId == query.institutionId) &&
    (query.unitId == null || profile.unitId == null || profile.unitId == query.unitId) &&
    (query.groupId == null || profile.groupId == null || profile.groupId == query.groupId);

bool _sameScope(InviteScope left, InviteScope right) =>
    left.kind == right.kind &&
    left.institutionId == right.institutionId &&
    left.unitId == right.unitId &&
    left.groupId == right.groupId;

List<PlatformInvite> _seedInvites() => [
  _seedInvite(
    id: 1,
    scope: _girassolScope,
    profile: _horizonteProfessionalProfile,
    name: 'Ana Lima',
    email: 'a***@horizonte.edu.br',
    channels: const {InviteChannel.email},
    status: InviteStatus.pending,
    createdAt: DateTime.utc(2026, 8, 24, 9, 15),
    expiresAt: DateTime.utc(2026, 9, 5, 9, 15),
  ),
  _seedInvite(
    id: 2,
    scope: _girassolScope,
    profile: _horizonteFamilyProfile,
    name: 'Bruno Santos',
    email: 'b***@familia.test',
    channels: const {InviteChannel.email, InviteChannel.link},
    status: InviteStatus.accepted,
    createdAt: DateTime.utc(2026, 8, 22, 14, 30),
    expiresAt: DateTime.utc(2026, 8, 29, 14, 30),
    acceptedAt: DateTime.utc(2026, 8, 23, 8, 10),
  ),
  _seedInvite(
    id: 3,
    scope: _seventhGradeScope,
    profile: _horizonteTeacherProfile,
    name: 'Camila Rocha',
    email: 'c***@horizonte.edu.br',
    channels: const {InviteChannel.link},
    status: InviteStatus.pending,
    createdAt: DateTime.utc(2026, 8, 28, 10),
    expiresAt: DateTime.utc(2026, 9, 4, 10),
  ),
  _seedInvite(
    id: 4,
    scope: _seventhGradeScope,
    profile: _horizonteFamilyProfile,
    name: 'Diego Martins',
    email: 'd***@familia.test',
    channels: const {InviteChannel.email},
    status: InviteStatus.expired,
    createdAt: DateTime.utc(2026, 8, 12, 11, 20),
    expiresAt: DateTime.utc(2026, 8, 19, 11, 20),
  ),
  _seedInvite(
    id: 5,
    scope: _nurseryScope,
    profile: _sementesFamilyProfile,
    name: 'Elisa Nogueira',
    email: 'e***@familia.test',
    channels: const {InviteChannel.email, InviteChannel.link},
    status: InviteStatus.pending,
    createdAt: DateTime.utc(2026, 8, 30, 16, 45),
    expiresAt: DateTime.utc(2026, 9, 6, 16, 45),
  ),
  _seedInvite(
    id: 6,
    scope: _pedagogicalTeamScope,
    profile: _sementesProfessionalProfile,
    name: 'Felipe Alves',
    email: 'f***@sementes.edu.br',
    channels: const {InviteChannel.email},
    status: InviteStatus.revoked,
    createdAt: DateTime.utc(2026, 8, 18, 13),
    expiresAt: DateTime.utc(2026, 8, 25, 13),
    revokedAt: DateTime.utc(2026, 8, 20, 9, 40),
  ),
  _seedInvite(
    id: 7,
    scope: _nurseryScope,
    profile: _sementesTeacherProfile,
    name: 'Gabriela Moraes',
    email: 'g***@sementes.edu.br',
    channels: const {InviteChannel.email, InviteChannel.link},
    status: InviteStatus.accepted,
    createdAt: DateTime.utc(2026, 8, 15, 8, 30),
    expiresAt: DateTime.utc(2026, 8, 22, 8, 30),
    acceptedAt: DateTime.utc(2026, 8, 15, 10, 5),
  ),
  _seedInvite(
    id: 8,
    scope: _horizonteScope,
    profile: _horizonteCoordinationProfile,
    name: 'Helena Costa',
    email: 'h***@horizonte.edu.br',
    channels: const {InviteChannel.email},
    status: InviteStatus.expired,
    createdAt: DateTime.utc(2026, 8, 10, 17),
    expiresAt: DateTime.utc(2026, 8, 17, 17),
  ),
  _seedInvite(
    id: 9,
    scope: _centerUnitScope,
    profile: _horizonteProfessionalProfile,
    name: 'Igor Ribeiro',
    email: 'i***@horizonte.edu.br',
    channels: const {InviteChannel.link},
    status: InviteStatus.pending,
    createdAt: DateTime.utc(2026, 8, 29, 9, 5),
    expiresAt: DateTime.utc(2026, 9, 5, 9, 5),
  ),
  _seedInvite(
    id: 10,
    scope: _vilaNovaUnitScope,
    profile: _sementesCoordinationProfile,
    name: 'Juliana Freitas',
    email: 'j***@sementes.edu.br',
    channels: const {InviteChannel.email, InviteChannel.link},
    status: InviteStatus.accepted,
    createdAt: DateTime.utc(2026, 8, 21, 12),
    expiresAt: DateTime.utc(2026, 8, 28, 12),
    acceptedAt: DateTime.utc(2026, 8, 21, 15, 25),
  ),
  _seedInvite(
    id: 11,
    scope: _girassolScope,
    profile: _horizonteFamilyProfile,
    name: 'Karen Oliveira',
    email: 'k***@familia.test',
    channels: const {InviteChannel.email},
    status: InviteStatus.revoked,
    createdAt: DateTime.utc(2026, 8, 17, 10, 10),
    expiresAt: DateTime.utc(2026, 8, 24, 10, 10),
    revokedAt: DateTime.utc(2026, 8, 18, 8),
  ),
  _seedInvite(
    id: 12,
    scope: _seventhGradeScope,
    profile: _horizonteFamilyProfile,
    name: 'Lucas Pereira',
    email: 'l***@familia.test',
    channels: const {InviteChannel.email, InviteChannel.link},
    status: InviteStatus.pending,
    createdAt: DateTime.utc(2026, 8, 31, 18),
    expiresAt: DateTime.utc(2026, 9, 7, 18),
  ),
];

PlatformInvite _seedInvite({
  required int id,
  required InviteScope scope,
  required InviteProfileReference profile,
  required String name,
  required String email,
  required Set<InviteChannel> channels,
  required InviteStatus status,
  required DateTime createdAt,
  required DateTime expiresAt,
  DateTime? acceptedAt,
  DateTime? revokedAt,
}) => PlatformInvite(
  id: 'dev-invite-$id',
  scope: scope,
  profile: profile,
  recipient: InviteRecipient(label: name, maskedEmail: email),
  channels: channels,
  status: status,
  issuer: id.isEven ? _pedagogicalIssuer : _ownerIssuer,
  createdAt: createdAt,
  expiresAt: expiresAt,
  acceptedAt: acceptedAt,
  revokedAt: revokedAt,
  emailDeliveryStatus: channels.contains(InviteChannel.email)
      ? InviteDeliveryStatus.sent
      : InviteDeliveryStatus.notRequested,
  managementVersion: 1,
  timeline: [
    InviteTimelineEntry('Convite emitido', createdAt),
    if (acceptedAt != null) InviteTimelineEntry('Convite aceito', acceptedAt),
    if (revokedAt != null) InviteTimelineEntry('Convite revogado', revokedAt),
  ],
);

PlatformInvite _copyInvite(
  PlatformInvite invite, {
  required InviteStatus status,
  required int managementVersion,
  required List<InviteTimelineEntry> timeline,
  DateTime? expiresAt,
  DateTime? revokedAt,
}) => PlatformInvite(
  id: invite.id,
  scope: invite.scope,
  profile: invite.profile,
  recipient: invite.recipient,
  channels: invite.channels,
  status: status,
  issuer: invite.issuer,
  createdAt: invite.createdAt,
  expiresAt: expiresAt ?? invite.expiresAt,
  acceptedAt: invite.acceptedAt,
  revokedAt: revokedAt,
  emailDeliveryStatus: invite.emailDeliveryStatus,
  managementVersion: managementVersion,
  timeline: List.unmodifiable(timeline),
);

DateTime _utcNow() => DateTime.now().toUtc();

const _horizonteScope = InviteScope(
  kind: InviteScopeKind.institution,
  institutionId: 'colegio-horizonte',
  label: 'Colégio Horizonte',
);

const _centerUnitScope = InviteScope(
  kind: InviteScopeKind.unit,
  institutionId: 'colegio-horizonte',
  unitId: 'horizonte-centro',
  label: 'Unidade Centro',
);

const _girassolScope = InviteScope(
  kind: InviteScopeKind.group,
  institutionId: 'colegio-horizonte',
  unitId: 'horizonte-centro',
  groupId: 'turma-girassol',
  label: 'Turma Girassol',
);

const _seventhGradeScope = InviteScope(
  kind: InviteScopeKind.group,
  institutionId: 'colegio-horizonte',
  unitId: 'horizonte-centro',
  groupId: 'setimo-ano-a',
  label: '7º ano A',
);

const _vilaNovaUnitScope = InviteScope(
  kind: InviteScopeKind.unit,
  institutionId: 'instituto-sementes',
  unitId: 'sementes-vila-nova',
  label: 'Unidade Vila Nova',
);

const _nurseryScope = InviteScope(
  kind: InviteScopeKind.group,
  institutionId: 'instituto-sementes',
  unitId: 'sementes-vila-nova',
  groupId: 'bercario-azul',
  label: 'Berçário Azul',
);

const _pedagogicalTeamScope = InviteScope(
  kind: InviteScopeKind.group,
  institutionId: 'instituto-sementes',
  unitId: 'sementes-vila-nova',
  groupId: 'equipe-pedagogica',
  label: 'Equipe Pedagógica',
);

const _horizonteProfessionalProfile = InviteProfileReference(
  id: 'horizonte-professional-profile',
  label: 'Profissional',
);
const _horizonteTeacherProfile = InviteProfileReference(
  id: 'horizonte-teacher-profile',
  label: 'Professor(a)',
);
const _horizonteFamilyProfile = InviteProfileReference(
  id: 'horizonte-family-profile',
  label: 'Responsável',
);
const _horizonteCoordinationProfile = InviteProfileReference(
  id: 'horizonte-coordination-profile',
  label: 'Coordenação',
);
const _sementesProfessionalProfile = InviteProfileReference(
  id: 'sementes-professional-profile',
  label: 'Profissional',
);
const _sementesTeacherProfile = InviteProfileReference(
  id: 'sementes-teacher-profile',
  label: 'Professor(a)',
);
const _sementesFamilyProfile = InviteProfileReference(
  id: 'sementes-family-profile',
  label: 'Responsável',
);
const _sementesCoordinationProfile = InviteProfileReference(
  id: 'sementes-coordination-profile',
  label: 'Coordenação',
);
const _ownerIssuer = InviteIssuer(personId: 'owner-coelo', label: 'Owner Coelo');
const _pedagogicalIssuer = InviteIssuer(personId: 'coordinator-marina', label: 'Marina Ferreira');

const _options = InviteFormOptions(
  scopes: [
    InviteScopeOption(scope: _horizonteScope),
    InviteScopeOption(scope: _centerUnitScope),
    InviteScopeOption(scope: _girassolScope),
    InviteScopeOption(scope: _seventhGradeScope),
    InviteScopeOption(scope: _vilaNovaUnitScope),
    InviteScopeOption(scope: _nurseryScope),
    InviteScopeOption(scope: _pedagogicalTeamScope),
  ],
  profiles: [
    InviteProfileOption(
      id: 'horizonte-professional-profile',
      label: 'Profissional',
      institutionId: 'colegio-horizonte',
      unitId: 'horizonte-centro',
    ),
    InviteProfileOption(
      id: 'horizonte-teacher-profile',
      label: 'Professor(a)',
      institutionId: 'colegio-horizonte',
      unitId: 'horizonte-centro',
    ),
    InviteProfileOption(
      id: 'horizonte-family-profile',
      label: 'Responsável',
      institutionId: 'colegio-horizonte',
      unitId: 'horizonte-centro',
    ),
    InviteProfileOption(
      id: 'horizonte-coordination-profile',
      label: 'Coordenação',
      institutionId: 'colegio-horizonte',
      unitId: 'horizonte-centro',
    ),
    InviteProfileOption(
      id: 'sementes-professional-profile',
      label: 'Profissional',
      institutionId: 'instituto-sementes',
      unitId: 'sementes-vila-nova',
    ),
    InviteProfileOption(
      id: 'sementes-teacher-profile',
      label: 'Professor(a)',
      institutionId: 'instituto-sementes',
      unitId: 'sementes-vila-nova',
    ),
    InviteProfileOption(
      id: 'sementes-family-profile',
      label: 'Responsável',
      institutionId: 'instituto-sementes',
      unitId: 'sementes-vila-nova',
    ),
    InviteProfileOption(
      id: 'sementes-coordination-profile',
      label: 'Coordenação',
      institutionId: 'instituto-sementes',
      unitId: 'sementes-vila-nova',
    ),
  ],
  recipients: [
    InviteRecipientOption(
      personId: 'ana-lima',
      label: 'Ana Lima',
      maskedEmail: 'a***@horizonte.edu.br',
    ),
    InviteRecipientOption(
      personId: 'camila-rocha',
      label: 'Camila Rocha',
      maskedEmail: 'c***@horizonte.edu.br',
    ),
    InviteRecipientOption(
      personId: 'gabriela-moraes',
      label: 'Gabriela Moraes',
      maskedEmail: 'g***@sementes.edu.br',
    ),
  ],
);

const _recipientScopes = <String, InviteScope>{
  'ana-lima': _girassolScope,
  'camila-rocha': _seventhGradeScope,
  'gabriela-moraes': _nurseryScope,
};
