import 'dart:convert';

import 'package:coelo_superadmin/features/invites/data/supabase_invite_repository.dart';
import 'package:coelo_superadmin/features/invites/domain/platform_invite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const canonicalToken = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  test('sends filters and pagination to the directory RPC and parses rows', () async {
    Request? captured;
    final client = _client((request) async {
      captured = request;
      return _json({
        'items': [_inviteJson()],
        'total_count': 21,
      }, request);
    });
    addTearDown(client.dispose);

    final page = await SupabaseInviteRepository(client).fetchPage(
      InviteDirectoryQuery(
        search: '  aurora ',
        statuses: const {InviteStatus.pending},
        channels: const {InviteChannel.email, InviteChannel.link},
        institutionIds: const {'institution-1'},
        unitIds: const {'unit-1'},
        groupIds: const {'group-1'},
        profileIds: const {'profile-1'},
        page: 2,
        pageSize: 20,
        sortAscending: false,
      ),
    );

    expect(captured!.url.path, endsWith('/rpc/superadmin_invite_directory'));
    expect(jsonDecode(captured!.body), {
      'p_search': 'aurora',
      'p_statuses': ['pending'],
      'p_channels': containsAll(['email', 'link']),
      'p_institution_ids': ['institution-1'],
      'p_unit_ids': ['unit-1'],
      'p_group_ids': ['group-1'],
      'p_profile_ids': ['profile-1'],
      'p_created_from': null,
      'p_created_to': null,
      'p_limit': 20,
      'p_offset': 20,
      'p_sort': 'created_at',
      'p_sort_ascending': false,
    });
    expect(page.totalCount, 21);
    expect(page.items.single.id, 'invite-1');
    expect(page.items.single.scope.kind, InviteScopeKind.group);
    expect(page.items.single.profile.label, 'Profissional');
    expect(page.items.single.recipient.maskedEmail, 'a***@aurora.test');
    expect(page.items.single.channels, {InviteChannel.email, InviteChannel.link});
    expect(page.items.single.emailDeliveryStatus, InviteDeliveryStatus.sent);
    expect(page.items.single.managementVersion, 7);
  });

  test('loads authorised hierarchical scope, profile and recipient options', () async {
    Request? captured;
    final client = _client((request) async {
      captured = request;
      return _json({
        'scopes': [
          {
            'scope_kind': 'unit',
            'scope_id': 'unit-1',
            'label': 'Unidade Centro',
            'institution_id': 'institution-1',
            'unit_id': 'unit-1',
            'group_id': null,
          },
        ],
        'profiles': [
          {
            'profile_id': 'profile-1',
            'label': 'Administrador',
            'institution_id': 'institution-1',
            'unit_id': 'unit-1',
            'group_id': null,
          },
        ],
        'recipients': [
          {'person_id': 'person-1', 'label': 'Ana Lima', 'masked_email': 'a***@aurora.test'},
        ],
      }, request);
    });
    addTearDown(client.dispose);

    final options = await SupabaseInviteRepository(client).fetchOptions(
      const InviteOptionsQuery(
        search: 'ana',
        institutionId: 'institution-1',
        unitId: 'unit-1',
        pageSize: 25,
      ),
    );

    expect(captured!.url.path, endsWith('/rpc/superadmin_invite_options'));
    expect(jsonDecode(captured!.body), {
      'p_search': 'ana',
      'p_institution_id': 'institution-1',
      'p_unit_id': 'unit-1',
      'p_group_id': null,
      'p_limit': 25,
    });
    expect(options.scopes.single.kind, InviteScopeKind.unit);
    expect(options.profiles.single.id, 'profile-1');
    expect(options.recipients.single.personId, 'person-1');
  });

  test('uses get RPC and maps a missing invite to null without leaking details', () async {
    final client = _client(
      (request) async => Response(
        jsonEncode({
          'code': 'P0002',
          'message': 'cross-tenant object does not exist',
          'details': 'private detail',
          'hint': null,
        }),
        404,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    );
    addTearDown(client.dispose);

    final invite = await SupabaseInviteRepository(client).fetchById('other-tenant-invite');

    expect(invite, isNull);
  });

  test('issues through an idempotent command and returns a safe copyable link', () async {
    Request? captured;
    final client = _client((request) async {
      captured = request;
      return _json({
        'invite': _inviteJson(),
        'link': 'https://app.coelo.me/convites/$canonicalToken',
        'replayed': false,
      }, request);
    });
    addTearDown(client.dispose);
    final command = InviteIssueCommand(
      requestId: 'request-1',
      scope: InviteScope(
        kind: InviteScopeKind.group,
        institutionId: 'institution-1',
        unitId: 'unit-1',
        groupId: 'group-1',
        label: 'Turma Girassol',
      ),
      profileId: 'profile-1',
      recipient: InviteRecipientDraft(personId: 'person-1'),
      channels: {InviteChannel.email, InviteChannel.link},
      expiresInHours: 72,
    );

    final result = await SupabaseInviteRepository(client).issue(command);

    expect(captured!.url.path, endsWith('/rpc/superadmin_invite_issue'));
    expect(jsonDecode(captured!.body), {
      'p_request_id': 'request-1',
      'p_institution_id': 'institution-1',
      'p_unit_id': 'unit-1',
      'p_group_id': 'group-1',
      'p_profile_id': 'profile-1',
      'p_target_person_id': 'person-1',
      'p_recipient_email': null,
      'p_channels': containsAll(['email', 'link']),
      'p_expires_in_hours': 72,
    });
    expect(result.link, Uri.parse('https://app.coelo.me/convites/$canonicalToken'));
    expect(result.replayed, isFalse);
  });

  test('preserves replay receipts and allows a command result without a link', () async {
    final client = _client(
      (request) async => _json({
        'invite': _inviteJson(channels: ['email']),
        'link': null,
        'replayed': true,
      }, request),
    );
    addTearDown(client.dispose);

    final result = await SupabaseInviteRepository(client).resend(
      const InviteResendCommand(inviteId: 'invite-1', requestId: 'request-2', expectedVersion: 7),
    );

    expect(result.replayed, isTrue);
    expect(result.link, isNull);
    expect(result.invite.channels, {InviteChannel.email});
  });

  test('uses idempotent resend and revoke RPC parameters', () async {
    final requests = <Request>[];
    final client = _client((request) async {
      requests.add(request);
      return _json({'invite': _inviteJson(), 'link': null, 'replayed': false}, request);
    });
    addTearDown(client.dispose);
    final repository = SupabaseInviteRepository(client);

    await repository.resend(
      const InviteResendCommand(inviteId: 'invite-1', requestId: 'resend-1', expectedVersion: 7),
    );
    await repository.revoke(
      const InviteRevokeCommand(
        inviteId: 'invite-1',
        requestId: 'revoke-1',
        expectedVersion: 7,
        reason: 'Solicitação administrativa',
      ),
    );

    expect(requests[0].url.path, endsWith('/rpc/superadmin_invite_resend'));
    expect(jsonDecode(requests[0].body), {
      'p_invite_id': 'invite-1',
      'p_request_id': 'resend-1',
      'p_expected_version': 7,
    });
    expect(requests[1].url.path, endsWith('/rpc/superadmin_invite_revoke'));
    expect(jsonDecode(requests[1].body), {
      'p_invite_id': 'invite-1',
      'p_request_id': 'revoke-1',
      'p_expected_version': 7,
      'p_reason': 'Solicitação administrativa',
    });
  });

  test('maps authorization and command not-found failures to safe types', () async {
    Future<void> expectCode(String code, Matcher matcher) async {
      final client = _client(
        (request) async => Response(
          jsonEncode({
            'code': code,
            'message': 'sensitive database message',
            'details': 'tenant-private details',
            'hint': null,
          }),
          code == '42501' ? 403 : 404,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      );
      addTearDown(client.dispose);
      final repository = SupabaseInviteRepository(client);
      await expectLater(
        repository.revoke(
          const InviteRevokeCommand(
            inviteId: 'invite-other',
            requestId: 'request-3',
            expectedVersion: 7,
            reason: 'Solicitação administrativa',
          ),
        ),
        throwsA(matcher),
      );
    }

    await expectCode('42501', isA<InviteUnauthorizedException>());
    await expectCode('P0002', isA<InviteNotFoundException>());
  });

  test('rejects a dangerous link returned by the server', () async {
    final client = _client(
      (request) async => _json({
        'invite': _inviteJson(),
        'link': 'javascript:alert(1)',
        'replayed': false,
      }, request),
    );
    addTearDown(client.dispose);

    expect(
      () => SupabaseInviteRepository(client).resend(
        const InviteResendCommand(inviteId: 'invite-1', requestId: 'request-4', expectedVersion: 7),
      ),
      throwsA(isA<InviteUnavailableException>()),
    );
  });

  test('accepts only the canonical invitation link origin and path', () async {
    final invalidLinks = <String>[
      'https://evil.test/convites/$canonicalToken',
      'https://evil@app.coelo.me/convites/$canonicalToken',
      'https://app.coelo.me:443/convites/$canonicalToken',
      'https://app.coelo.me/convite/$canonicalToken',
      'https://app.coelo.me/convites/not-a-token',
      'https://app.coelo.me/convites/$canonicalToken?next=https://evil.test',
      'https://app.coelo.me/convites/$canonicalToken#fragment',
    ];

    for (final link in invalidLinks) {
      final client = _client(
        (request) async =>
            _json({'invite': _inviteJson(), 'link': link, 'replayed': false}, request),
      );
      addTearDown(client.dispose);

      await expectLater(
        SupabaseInviteRepository(client).resend(
          const InviteResendCommand(
            inviteId: 'invite-1',
            requestId: 'request-hostile-link',
            expectedVersion: 7,
          ),
        ),
        throwsA(isA<InviteUnavailableException>()),
        reason: link,
      );
    }
  });

  test('rejects malformed row collections instead of dropping data', () async {
    for (final items in <Object?>[
      {'invite_id': 'invite-1'},
      [_inviteJson(), false],
    ]) {
      final client = _client((request) async => _json({'items': items, 'total_count': 1}, request));
      addTearDown(client.dispose);

      await expectLater(
        SupabaseInviteRepository(client).fetchPage(InviteDirectoryQuery()),
        throwsA(isA<InviteUnavailableException>()),
      );
    }
  });

  test('rejects non-integer and negative integer fields', () async {
    for (final count in <Object?>['1', 1.5, -1]) {
      final client = _client(
        (request) async => _json({'items': <Object?>[], 'total_count': count}, request),
      );
      addTearDown(client.dispose);

      await expectLater(
        SupabaseInviteRepository(client).fetchPage(InviteDirectoryQuery()),
        throwsA(isA<InviteUnavailableException>()),
      );
    }

    for (final version in <Object?>['7', 7.5, 0, -1]) {
      final client = _client((request) async {
        final invite = _inviteJson()..['management_version'] = version;
        return _json(invite, request);
      });
      addTearDown(client.dispose);

      await expectLater(
        SupabaseInviteRepository(client).fetchById('invite-1'),
        throwsA(isA<InviteUnavailableException>()),
      );
    }
  });

  test('rejects malformed required, optional and list strings', () async {
    for (final mutate in <void Function(Map<String, Object?>)>[
      (invite) => invite['recipient_label'] = false,
      (invite) => invite['recipient_label'] = '',
      (invite) => invite['channels'] = ['email', 7],
      (invite) => invite['channels'] = <Object?>[],
    ]) {
      final client = _client((request) async {
        final invite = _inviteJson();
        mutate(invite);
        return _json(invite, request);
      });
      addTearDown(client.dispose);

      await expectLater(
        SupabaseInviteRepository(client).fetchById('invite-1'),
        throwsA(isA<InviteUnavailableException>()),
      );
    }
  });

  test('unavailable repository fails closed for reads and commands', () async {
    const repository = UnavailableInviteRepository();

    await expectLater(
      repository.fetchPage(InviteDirectoryQuery()),
      throwsA(isA<InviteUnavailableException>()),
    );
    await expectLater(repository.fetchById('invite-1'), throwsA(isA<InviteUnavailableException>()));
    await expectLater(
      repository.revoke(
        const InviteRevokeCommand(
          inviteId: 'invite-1',
          requestId: 'request-5',
          expectedVersion: 7,
          reason: 'Solicitação administrativa',
        ),
      ),
      throwsA(isA<InviteUnavailableException>()),
    );
  });
}

Map<String, Object?> _inviteJson({List<String> channels = const ['email', 'link']}) => {
  'invite_id': 'invite-1',
  'status': 'pending',
  'channels': channels,
  'scope_kind': 'group',
  'institution_id': 'institution-1',
  'unit_id': 'unit-1',
  'group_id': 'group-1',
  'scope_label': 'Turma Girassol',
  'profile_id': 'profile-1',
  'profile_label': 'Profissional',
  'target_person_id': 'person-1',
  'recipient_label': 'Ana Lima',
  'recipient_masked': 'a***@aurora.test',
  'issuer_person_id': 'issuer-1',
  'issuer_label': 'Owner Coelo',
  'email_delivery_status': 'sent',
  'management_version': 7,
  'created_at': '2026-08-11T12:00:00Z',
  'expires_at': '2026-08-14T12:00:00Z',
  'accepted_at': null,
  'revoked_at': null,
  'timeline': [
    {'label': 'Convite emitido', 'occurred_at': '2026-08-11T12:00:00Z'},
  ],
};

SupabaseClient _client(Future<Response> Function(Request request) handler) => SupabaseClient(
  'https://example.supabase.co',
  'publishable-key',
  httpClient: MockClient(handler),
);

Response _json(Object? body, Request request) => Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
  request: request,
);
