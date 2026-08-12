import 'package:coelo_superadmin/features/invites/domain/platform_invite.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exposes only email and copyable link delivery channels', () {
    expect(InviteChannel.values, [InviteChannel.email, InviteChannel.link]);
    expect(InviteChannel.values.map((channel) => channel.databaseValue), ['email', 'link']);
    expect(
      InviteChannel.values.map((channel) => channel.name.toLowerCase()).join(' '),
      isNot(anyOf(contains('mobile'), contains('sms'), contains('celular'))),
    );
  });

  test('keeps invitation status separate from delivery failure', () {
    expect(InviteStatus.values, [
      InviteStatus.pending,
      InviteStatus.accepted,
      InviteStatus.expired,
      InviteStatus.revoked,
    ]);
    expect(InviteStatus.fromDatabase('expired'), InviteStatus.expired);
    expect(InviteDeliveryStatus.fromDatabase('failed'), InviteDeliveryStatus.failed);
  });

  test('calculates immutable server pagination and active filters', () {
    final statuses = {InviteStatus.pending};
    final query = InviteDirectoryQuery(
      search: '  Aurora  ',
      statuses: statuses,
      channels: const {InviteChannel.email},
      institutionIds: const {'institution-1'},
      page: 2,
      pageSize: 20,
    );
    statuses.add(InviteStatus.revoked);

    expect(query.search, '  Aurora  ');
    expect(query.statuses, {InviteStatus.pending});
    expect(query.offset, 20);
    expect(query.hasActiveFilters, isTrue);
  });

  test('classifies loaded directory states without impossible booleans', () {
    const emptyPage = InviteDirectoryResult(items: [], totalCount: 0, page: 1, pageSize: 8);

    expect(
      InviteDirectorySnapshot.loaded(emptyPage, search: '').state,
      InviteDirectoryLoadState.empty,
    );
    expect(
      InviteDirectorySnapshot.loaded(emptyPage, search: 'ana').state,
      InviteDirectoryLoadState.noResults,
    );
  });

  test('requires an exclusive recipient, channels and an idempotency key', () {
    const scope = InviteScope(
      kind: InviteScopeKind.institution,
      institutionId: 'institution-1',
      label: 'Instituição Aurora',
    );

    expect(() => InviteRecipientDraft(), throwsA(isA<AssertionError>()));
    expect(
      () => InviteRecipientDraft(personId: 'person-1', email: 'owner@aurora.test'),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => InviteIssueCommand(
        requestId: '',
        scope: scope,
        profileId: 'profile-1',
        recipient: const InviteRecipientDraft(email: 'owner@aurora.test'),
        channels: const {InviteChannel.email},
      ),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => InviteIssueCommand(
        requestId: 'request-1',
        scope: scope,
        profileId: 'profile-1',
        recipient: const InviteRecipientDraft(email: 'owner@aurora.test'),
        channels: const {},
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
