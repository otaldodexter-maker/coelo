import 'package:coelo_superadmin/app/dev_menu/development_invite_repository.dart';
import 'package:coelo_superadmin/features/invites/domain/platform_invite.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 24, 12);

  test('starts with a coherent linked invite directory for pagination', () async {
    final repository = DevelopmentInviteRepository(now: () => now);
    final page = await repository.fetchPage(InviteDirectoryQuery(pageSize: 20));
    final options = await repository.fetchOptions(const InviteOptionsQuery());

    expect(page.totalCount, greaterThanOrEqualTo(12));
    expect(page.items.map((invite) => invite.scope.institutionId).toSet().length, greaterThan(1));
    expect(page.items.map((invite) => invite.status).toSet(), containsAll(InviteStatus.values));
    expect(page.items.every((invite) => invite.timeline.isNotEmpty), isTrue);
    expect(page.items.every((invite) => invite.profile.label != invite.profile.id), isTrue);
    expect(
      page.items.every(
        (invite) => options.profiles.any(
          (profile) =>
              profile.id == invite.profile.id &&
              profile.institutionId == invite.scope.institutionId,
        ),
      ),
      isTrue,
    );
  });

  test('issue preserves command data and replays without duplicating', () async {
    final repository = DevelopmentInviteRepository(now: () => now);
    final command = InviteIssueCommand(
      requestId: 'issue-complete',
      scope: _unitScope,
      profileId: 'family-profile',
      recipient: const InviteRecipientDraft(email: 'maria@example.test'),
      channels: const {InviteChannel.email, InviteChannel.link},
      expiresInHours: 72,
    );

    final issued = await repository.issue(command);
    final replayed = await repository.issue(command);
    final page = await repository.fetchPage(InviteDirectoryQuery());

    expect(issued.replayed, isFalse);
    expect(replayed.replayed, isTrue);
    expect(replayed.invite.id, issued.invite.id);
    expect(page.items.where((item) => item.id == issued.invite.id), hasLength(1));
    expect(issued.invite.scope, same(command.scope));
    expect(issued.invite.profile.id, command.profileId);
    expect(
      issued.invite.recipient.maskedEmail,
      maskInviteRecipient('maria@example.test', InviteChannel.email),
    );
    expect(issued.invite.channels, command.channels);
    expect(issued.invite.createdAt, now);
    expect(issued.invite.expiresAt, now.add(const Duration(hours: 72)));
    expect(issued.invite.managementVersion, 1);
  });

  test('directory applies search status channel context profile and date filters', () async {
    var clock = DateTime.utc(2026, 8, 25, 8);
    final repository = DevelopmentInviteRepository(now: () => clock);
    final family = await repository.issue(
      InviteIssueCommand(
        requestId: 'issue-family',
        scope: _unitScope,
        profileId: 'family-profile',
        recipient: const InviteRecipientDraft(email: 'maria@example.test'),
        channels: const {InviteChannel.email, InviteChannel.link},
      ),
    );
    clock = clock.add(const Duration(hours: 1));
    final revoked = await repository.issue(
      InviteIssueCommand(
        requestId: 'issue-revoked',
        scope: _otherScope,
        profileId: 'teacher-profile',
        recipient: const InviteRecipientDraft(personId: 'teacher-person'),
        channels: const {InviteChannel.link},
      ),
    );
    await repository.revoke(
      InviteRevokeCommand(
        inviteId: revoked.invite.id,
        requestId: 'revoke-filter',
        expectedVersion: revoked.invite.managementVersion,
        reason: 'Teste de filtro',
      ),
    );

    final filtered = await repository.fetchPage(
      InviteDirectoryQuery(
        search: 'unidade família',
        statuses: const {InviteStatus.pending},
        channels: const {InviteChannel.email, InviteChannel.link},
        institutionIds: const {'institution-family'},
        unitIds: const {'unit-family'},
        profileIds: const {'family-profile'},
        createdFrom: DateTime.utc(2026, 8, 25, 7, 59),
        createdTo: DateTime.utc(2026, 8, 25, 8, 1),
      ),
    );
    final groupFiltered = await repository.fetchPage(
      InviteDirectoryQuery(groupIds: const {'group-other'}, statuses: const {InviteStatus.revoked}),
    );

    expect(filtered.items.map((item) => item.id), [family.invite.id]);
    expect(filtered.totalCount, 1);
    expect(groupFiltered.items.map((item) => item.id), [revoked.invite.id]);
  });

  test('directory sorts deterministically and paginates after filtering', () async {
    var clock = DateTime.utc(2026, 8, 25, 8);
    final repository = DevelopmentInviteRepository(now: () => clock);
    for (var index = 0; index < 9; index++) {
      await repository.issue(
        InviteIssueCommand(
          requestId: 'issue-page-$index',
          scope: _groupScope,
          profileId: 'dev-profile',
          recipient: InviteRecipientDraft(email: 'person$index@example.test'),
          channels: const {InviteChannel.email},
        ),
      );
      clock = clock.add(const Duration(minutes: 1));
    }

    final first = await repository.fetchPage(InviteDirectoryQuery(pageSize: 8));
    final second = await repository.fetchPage(InviteDirectoryQuery(page: 2, pageSize: 8));
    final ascending = await repository.fetchPage(
      InviteDirectoryQuery(pageSize: 20, sortAscending: true),
    );

    expect(first.totalCount, 21);
    expect(first.items, hasLength(8));
    expect(second.items, hasLength(8));
    expect(first.items.first.createdAt.isAfter(first.items.last.createdAt), isTrue);
    expect(ascending.items.first.id, 'dev-invite-8');
  });

  test('exposes controlled empty unauthorized and failure states', () async {
    final empty = DevelopmentInviteRepository(mode: DevelopmentRepositoryMode.empty);
    final denied = DevelopmentInviteRepository(mode: DevelopmentRepositoryMode.unauthorized);
    final failed = DevelopmentInviteRepository(mode: DevelopmentRepositoryMode.failure);

    expect((await empty.fetchPage(InviteDirectoryQuery())).items, isEmpty);
    await expectLater(
      denied.fetchPage(InviteDirectoryQuery()),
      throwsA(isA<InviteUnauthorizedException>()),
    );
    await expectLater(
      failed.fetchPage(InviteDirectoryQuery()),
      throwsA(isA<InviteUnavailableException>()),
    );
  });

  test('resend persists renewed expiry and version in the session', () async {
    final repository = DevelopmentInviteRepository(now: () => now);
    final result = await repository.resend(
      const InviteResendCommand(
        inviteId: 'dev-invite-1',
        requestId: 'resend-1',
        expectedVersion: 1,
      ),
    );

    expect(result.invite.status, InviteStatus.pending);
    expect(result.invite.managementVersion, 2);
    expect(result.invite.expiresAt, now.add(const Duration(hours: 48)));
    expect(await repository.fetchById('dev-invite-1'), same(result.invite));
  });

  test('revoke persists status and version when the invite is reopened', () async {
    final repository = DevelopmentInviteRepository(now: () => now);
    final result = await repository.revoke(
      const InviteRevokeCommand(
        inviteId: 'dev-invite-1',
        requestId: 'revoke-1',
        expectedVersion: 1,
        reason: 'Acesso cancelado na demonstracao',
      ),
    );

    expect(result.invite.status, InviteStatus.revoked);
    expect(result.invite.managementVersion, 2);
    expect(result.invite.revokedAt, now);
    expect(await repository.fetchById('dev-invite-1'), same(result.invite));
  });

  test('a new repository starts a clean invite session', () async {
    final first = DevelopmentInviteRepository(now: () => now);
    await first.revoke(
      const InviteRevokeCommand(
        inviteId: 'dev-invite-1',
        requestId: 'revoke-1',
        expectedVersion: 1,
        reason: 'Acesso cancelado na demonstracao',
      ),
    );

    final initial = await DevelopmentInviteRepository(now: () => now).fetchById('dev-invite-1');
    expect(initial?.status, InviteStatus.pending);
    expect(initial?.managementVersion, 1);
    expect(initial?.revokedAt, isNull);
  });

  test('resend rejects stale versions without mutating the session', () async {
    final repository = DevelopmentInviteRepository(now: () => now);
    await expectLater(
      repository.resend(
        const InviteResendCommand(
          inviteId: 'dev-invite-1',
          requestId: 'resend-stale',
          expectedVersion: 99,
        ),
      ),
      throwsA(isA<InviteConflictException>()),
    );
    expect((await repository.fetchById('dev-invite-1'))?.managementVersion, 1);
  });

  test('revoke rejects stale versions without mutating the session', () async {
    final repository = DevelopmentInviteRepository(now: () => now);
    await expectLater(
      repository.revoke(
        const InviteRevokeCommand(
          inviteId: 'dev-invite-1',
          requestId: 'revoke-stale',
          expectedVersion: 0,
          reason: 'Versao antiga',
        ),
      ),
      throwsA(isA<InviteConflictException>()),
    );
    expect((await repository.fetchById('dev-invite-1'))?.status, InviteStatus.pending);
  });

  test('command receipts replay without a second mutation', () async {
    final repository = DevelopmentInviteRepository(now: () => now);
    const command = InviteResendCommand(
      inviteId: 'dev-invite-1',
      requestId: 'resend-replay',
      expectedVersion: 1,
    );
    final first = await repository.resend(command);
    final replay = await repository.resend(command);

    expect(first.replayed, isFalse);
    expect(replay.replayed, isTrue);
    expect(replay.invite.managementVersion, first.invite.managementVersion);
    expect(replay.invite.timeline, hasLength(first.invite.timeline.length));
  });

  test('the same request id remains independent across invites', () async {
    final repository = DevelopmentInviteRepository(now: () => now);
    final issued = await repository.issue(
      InviteIssueCommand(
        requestId: 'issue-2',
        scope: _groupScope,
        profileId: 'dev-profile',
        recipient: InviteRecipientDraft(personId: 'dev-person'),
        channels: {InviteChannel.email},
      ),
    );
    final first = await repository.resend(
      const InviteResendCommand(
        inviteId: 'dev-invite-1',
        requestId: 'shared-request',
        expectedVersion: 1,
      ),
    );
    final second = await repository.resend(
      InviteResendCommand(
        inviteId: issued.invite.id,
        requestId: 'shared-request',
        expectedVersion: issued.invite.managementVersion,
      ),
    );

    expect(first.replayed, isFalse);
    expect(second.replayed, isFalse);
    expect(second.invite.id, isNot(first.invite.id));
  });
}

const _groupScope = InviteScope(
  kind: InviteScopeKind.group,
  institutionId: 'dev-institution',
  unitId: 'dev-unit',
  groupId: 'dev-group',
  label: 'Turma Girassol',
);

const _unitScope = InviteScope(
  kind: InviteScopeKind.unit,
  institutionId: 'institution-family',
  unitId: 'unit-family',
  label: 'Unidade Família',
);

const _otherScope = InviteScope(
  kind: InviteScopeKind.group,
  institutionId: 'institution-other',
  unitId: 'unit-other',
  groupId: 'group-other',
  label: 'Turma Horizonte',
);
