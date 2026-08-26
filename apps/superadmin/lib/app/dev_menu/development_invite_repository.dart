import '../../features/invites/domain/platform_invite.dart';

enum DevelopmentRepositoryMode { content, empty, failure, unauthorized }

final class DevelopmentInviteRepository implements InviteRepository {
  DevelopmentInviteRepository({
    DateTime Function()? now,
    this.mode = DevelopmentRepositoryMode.content,
  }) : _now = now ?? _utcNow,
       _invites = [_invite()];

  final DateTime Function() _now;
  final DevelopmentRepositoryMode mode;
  final _issueReceipts = <String, InviteCommandResult>{};
  final _receipts = <String, InviteCommandResult>{};
  List<PlatformInvite> _invites;
  var _nextInviteId = 2;

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
  Future<InviteFormOptions> fetchOptions(InviteOptionsQuery query) async => _options;

  @override
  Future<PlatformInvite?> fetchById(String inviteId) async =>
      _invites.where((item) => item.id == inviteId).firstOrNull;

  @override
  Future<InviteCommandResult> issue(InviteIssueCommand command) async {
    final receipt = _issueReceipts[command.requestId];
    if (receipt != null) {
      return InviteCommandResult(invite: receipt.invite, replayed: true, link: receipt.link);
    }
    final occurredAt = _now().toUtc();
    final id = 'dev-invite-${_nextInviteId++}';
    final profileOption = _options.profiles
        .where((option) => option.id == command.profileId)
        .firstOrNull;
    final personOption = command.recipient.personId == null
        ? null
        : _options.recipients
              .where((option) => option.personId == command.recipient.personId)
              .firstOrNull;
    final invite = PlatformInvite(
      id: id,
      scope: command.scope,
      profile: InviteProfileReference(
        id: command.profileId,
        label: profileOption?.label ?? command.profileId,
      ),
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

PlatformInvite _invite({String id = 'dev-invite-1'}) => PlatformInvite(
  id: id,
  scope: _scope,
  profile: const InviteProfileReference(id: 'dev-profile', label: 'Profissional'),
  recipient: const InviteRecipient(label: 'Ana Lima', maskedEmail: 'a***@coelo.local'),
  channels: const {InviteChannel.email},
  status: InviteStatus.pending,
  issuer: const InviteIssuer(personId: 'dev-owner', label: 'Owner Coelo'),
  createdAt: DateTime.utc(2026, 8, 24),
  expiresAt: DateTime.utc(2026, 8, 26),
  emailDeliveryStatus: InviteDeliveryStatus.sent,
  managementVersion: 1,
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

const _scope = InviteScope(
  kind: InviteScopeKind.group,
  institutionId: 'dev-institution',
  unitId: 'dev-unit',
  groupId: 'dev-group',
  label: 'Turma Girassol',
);

const _options = InviteFormOptions(
  scopes: [InviteScopeOption(scope: _scope)],
  profiles: [
    InviteProfileOption(
      id: 'dev-profile',
      label: 'Profissional',
      institutionId: 'dev-institution',
      unitId: 'dev-unit',
      groupId: 'dev-group',
    ),
  ],
  recipients: [InviteRecipientOption(personId: 'dev-person', label: 'Ana Lima')],
);
