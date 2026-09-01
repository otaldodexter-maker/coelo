import 'package:coelo_superadmin/features/invites/domain/platform_invite.dart';

final class TestInviteRepository implements InviteRepository {
  TestInviteRepository({List<PlatformInvite>? invites, InviteFormOptions? options, this.failure})
    : invites = invites ?? [testInvite()],
      options = options ?? testInviteOptions();

  List<PlatformInvite> invites;
  InviteFormOptions options;
  Object? failure;
  InviteDirectoryQuery? lastQuery;
  InviteOptionsQuery? lastOptionsQuery;
  InviteIssueCommand? lastIssue;
  InviteResendCommand? lastResend;
  InviteRevokeCommand? lastRevoke;
  Uri? nextLink = Uri.parse('https://app.coelo.me/convites/token-once');

  void _throwIfNeeded() {
    final value = failure;
    if (value != null) throw value;
  }

  @override
  Future<InviteDirectoryResult> fetchPage(InviteDirectoryQuery query) async {
    _throwIfNeeded();
    lastQuery = query;
    final visible = invites.where((invite) {
      final search = query.search.trim().toLowerCase();
      return (search.isEmpty || invite.recipientMasked.toLowerCase().contains(search)) &&
          (query.statuses.isEmpty || query.statuses.contains(invite.status)) &&
          (query.channels.isEmpty || query.channels.any(invite.channels.contains));
    }).toList();
    return InviteDirectoryResult(
      items: visible,
      totalCount: visible.length,
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  @override
  Future<InviteFormOptions> fetchOptions(InviteOptionsQuery query) async {
    _throwIfNeeded();
    lastOptionsQuery = query;
    return options;
  }

  @override
  Future<PlatformInvite?> fetchById(String inviteId) async {
    _throwIfNeeded();
    return invites.where((value) => value.id == inviteId).firstOrNull;
  }

  @override
  Future<InviteCommandResult> issue(InviteIssueCommand command) async {
    _throwIfNeeded();
    lastIssue = command;
    final invite = testInvite(
      recipient: command.recipient.email == null ? 'Ana Lima' : 'a***@aurora.test',
      channels: command.channels,
    );
    invites = [invite, ...invites];
    return InviteCommandResult(invite: invite, replayed: false, link: nextLink);
  }

  @override
  Future<InviteCommandResult> resend(InviteResendCommand command) async {
    _throwIfNeeded();
    lastResend = command;
    final previous = invites.firstWhere((value) => value.id == command.inviteId);
    final updated = testInvite(
      id: previous.id,
      status: InviteStatus.pending,
      channels: previous.channels,
      managementVersion: previous.managementVersion + 1,
    );
    invites = [updated, ...invites.where((value) => value.id != updated.id)];
    return InviteCommandResult(invite: updated, replayed: false, link: nextLink);
  }

  @override
  Future<InviteCommandResult> revoke(InviteRevokeCommand command) async {
    _throwIfNeeded();
    lastRevoke = command;
    final previous = invites.firstWhere((value) => value.id == command.inviteId);
    final updated = testInvite(
      id: previous.id,
      status: InviteStatus.revoked,
      channels: previous.channels,
      managementVersion: previous.managementVersion + 1,
    );
    invites = [updated, ...invites.where((value) => value.id != updated.id)];
    return InviteCommandResult(invite: updated, replayed: false);
  }
}

PlatformInvite testInvite({
  String id = '11111111-1111-4111-8111-111111111111',
  String recipient = 'a***@aurora.test',
  InviteStatus status = InviteStatus.pending,
  Set<InviteChannel> channels = const {InviteChannel.email, InviteChannel.link},
  int managementVersion = 1,
  DateTime? expiresAt,
}) => PlatformInvite(
  id: id,
  scope: const InviteScope(
    kind: InviteScopeKind.group,
    institutionId: '22222222-2222-4222-8222-222222222222',
    unitId: '33333333-3333-4333-8333-333333333333',
    groupId: '44444444-4444-4444-8444-444444444444',
    label: 'Turma Girassol',
  ),
  profile: const InviteProfileReference(
    id: '55555555-5555-4555-8555-555555555555',
    label: 'Profissional',
  ),
  recipient: InviteRecipient(
    label: recipient,
    maskedEmail: recipient.contains('@') ? recipient : null,
  ),
  channels: channels,
  status: status,
  issuer: const InviteIssuer(kind: InviteIssuerKind.superadminInternal, label: 'Owner Coelo'),
  createdAt: DateTime.utc(2026, 8, 11, 12),
  expiresAt: expiresAt ?? DateTime.utc(2026, 8, 14, 12),
  emailDeliveryStatus: channels.contains(InviteChannel.email)
      ? InviteDeliveryStatus.queued
      : InviteDeliveryStatus.notRequested,
  managementVersion: managementVersion,
  timeline: [InviteTimelineEntry('Convite emitido', DateTime.utc(2026, 8, 11, 12))],
);

InviteFormOptions testInviteOptions() => const InviteFormOptions(
  scopes: [
    InviteScopeOption(
      scope: InviteScope(
        kind: InviteScopeKind.group,
        institutionId: '22222222-2222-4222-8222-222222222222',
        unitId: '33333333-3333-4333-8333-333333333333',
        groupId: '44444444-4444-4444-8444-444444444444',
        label: 'Turma Girassol',
      ),
    ),
  ],
  profiles: [
    InviteProfileOption(
      id: '55555555-5555-4555-8555-555555555555',
      label: 'Profissional',
      institutionId: '22222222-2222-4222-8222-222222222222',
      unitId: '33333333-3333-4333-8333-333333333333',
      groupId: '44444444-4444-4444-8444-444444444444',
    ),
  ],
  recipients: [
    InviteRecipientOption(
      personId: '77777777-7777-4777-8777-777777777777',
      label: 'Ana Lima',
      maskedEmail: 'a***@aurora.test',
    ),
  ],
);
