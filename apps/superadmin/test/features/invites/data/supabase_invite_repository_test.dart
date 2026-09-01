import 'dart:convert';

import 'package:coelo_superadmin/features/invites/data/supabase_invite_repository.dart';
import 'package:coelo_superadmin/features/invites/domain/platform_invite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('uses only the internal v2 directory RPC and maps minimized issuers', () async {
    Request? captured;
    final client = _client((request) async {
      captured = request;
      return _success(request, {
        'items': [_invite()],
        'total_count': 14,
      });
    });
    addTearDown(client.dispose);

    final page = await SupabaseInviteRepository(client).fetchPage(
      InviteDirectoryQuery(
        search: 'Aurora',
        statuses: const {InviteStatus.pending},
        channels: const {InviteChannel.email},
        institutionIds: const {'10000000-0000-4000-8000-000000000001'},
        page: 2,
        pageSize: 8,
      ),
    );

    expect(captured!.url.path, endsWith('/rpc/superadmin_invite_directory_v2'));
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['p_offset'], 8);
    expect(body['p_statuses'], ['pending']);
    expect(body['p_channels'], ['email']);
    expect(page.totalCount, 14);
    expect(page.items.single.issuer.kind, InviteIssuerKind.superadminInternal);
    expect(page.items.single.issuer.label, 'Usuário interno');
    expect(captured!.body, isNot(contains('service_role')));
    expect(captured!.body, isNot(contains('issuer_id')));
  });

  test('maps legacy rows without inventing channel, profile or issuer ids', () async {
    final client = _client(
      (request) async => _success(
        request,
        _invite(
          channels: const [],
          issuerKind: 'legacy_person',
          issuerDisplay: 'Emissor institucional',
          profileId: 'legacy',
          managementVersion: 0,
        ),
      ),
    );
    addTearDown(client.dispose);

    final invite = await SupabaseInviteRepository(client).fetchById('invite-id');

    expect(invite!.channels, isEmpty);
    expect(invite.channelLabel, 'Não informado');
    expect(invite.profile.id, 'legacy');
    expect(invite.managementVersion, 0);
    expect(invite.issuer.kind, InviteIssuerKind.legacyPerson);
  });

  test('issue sends intent and unwraps a one-time safe link', () async {
    Request? captured;
    final client = _client((request) async {
      captured = request;
      return _success(request, {
        'invite': _invite(),
        'replayed': false,
        'link': 'https://app.coelo.me/convites/${'a' * 64}',
      });
    });
    addTearDown(client.dispose);

    final result = await SupabaseInviteRepository(client).issue(
      InviteIssueCommand(
        requestId: '20000000-0000-4000-8000-000000000001',
        scope: const InviteScope(
          kind: InviteScopeKind.institution,
          institutionId: '10000000-0000-4000-8000-000000000001',
          label: 'Colégio Aurora',
        ),
        profileId: '30000000-0000-4000-8000-000000000001',
        recipient: const InviteRecipientDraft(email: 'familia@invalid.test'),
        channels: const {InviteChannel.email, InviteChannel.link},
      ),
    );

    expect(captured!.url.path, endsWith('/rpc/superadmin_invite_issue_v2'));
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['p_request_id'], '20000000-0000-4000-8000-000000000001');
    expect(body['p_recipient_email'], 'familia@invalid.test');
    expect(body['p_channels'], containsAll(['email', 'link']));
    expect(result.link!.host, 'app.coelo.me');
    expect(result.replayed, isFalse);
  });

  test('resend and revoke preserve versioned request contracts', () async {
    final requests = <Request>[];
    final client = _client((request) async {
      requests.add(request);
      return _success(request, {'invite': _invite(), 'replayed': false, 'link': null});
    });
    addTearDown(client.dispose);
    final repository = SupabaseInviteRepository(client);

    await repository.resend(
      const InviteResendCommand(
        inviteId: 'invite-id',
        requestId: 'request-resend',
        expectedVersion: 4,
      ),
    );
    await repository.revoke(
      const InviteRevokeCommand(
        inviteId: 'invite-id',
        requestId: 'request-revoke',
        expectedVersion: 4,
        reason: 'Solicitação cancelada',
      ),
    );

    expect(requests[0].url.path, endsWith('/rpc/superadmin_invite_resend_v2'));
    expect(jsonDecode(requests[0].body), containsPair('p_expected_version', 4));
    expect(requests[1].url.path, endsWith('/rpc/superadmin_invite_revoke_v2'));
    expect(jsonDecode(requests[1].body), containsPair('p_reason', 'Solicitação cancelada'));
  });

  test('maps stable envelope denials, conflicts and invalid payloads', () async {
    for (final entry in <String, Matcher>{
      'SAI_MFA_REQUIRED': isA<InviteUnauthorizedException>(),
      'SAI_PERMISSION_DENIED': isA<InviteUnauthorizedException>(),
      'SAI_CONCURRENT_CHANGE': isA<InviteConflictException>(),
      'SAI_INVALID_ARGUMENT': isA<InviteValidationException>(),
      'SAI_INTERNAL_ERROR': isA<InviteUnavailableException>(),
    }.entries) {
      final client = _client((request) async => _error(request, entry.key));
      await expectLater(
        SupabaseInviteRepository(client).fetchById('invite-id'),
        throwsA(entry.value),
        reason: entry.key,
      );
      client.dispose();
    }
  });

  test('rejects identifier-bearing issuer payloads and unsafe links', () async {
    final identifierClient = _client(
      (request) async => _success(request, {
        ..._invite(),
        'issuer': {
          'kind': 'superadmin_internal',
          'display': 'Usuário interno',
          'internal_identity_id': 'secret',
        },
      }),
    );
    addTearDown(identifierClient.dispose);
    await expectLater(
      SupabaseInviteRepository(identifierClient).fetchById('invite-id'),
      throwsA(isA<InviteUnavailableException>()),
    );

    final linkClient = _client(
      (request) async => _success(request, {
        'invite': _invite(),
        'replayed': false,
        'link': 'https://evil.invalid/convites/${'a' * 64}',
      }),
    );
    addTearDown(linkClient.dispose);
    await expectLater(
      SupabaseInviteRepository(linkClient).resend(
        const InviteResendCommand(inviteId: 'invite-id', requestId: 'request', expectedVersion: 4),
      ),
      throwsA(isA<InviteUnavailableException>()),
    );
  });
}

SupabaseClient _client(Future<Response> Function(Request request) handler) => SupabaseClient(
  'https://example.supabase.co',
  'publishable-key',
  httpClient: MockClient(handler),
);

Response _success(Request request, Object data) => Response(
  jsonEncode({'ok': true, 'data': data, 'error': null}),
  200,
  headers: {'content-type': 'application/json'},
  request: request,
);

Response _error(Request request, String code) => Response(
  jsonEncode({
    'ok': false,
    'data': null,
    'error': {
      'code': code,
      'message': 'Mensagem segura.',
      'correlation_id': '40000000-0000-4000-8000-000000000001',
      'http_status': 403,
    },
  }),
  200,
  headers: {'content-type': 'application/json'},
  request: request,
);

Map<String, Object?> _invite({
  List<String> channels = const ['email', 'link'],
  String issuerKind = 'superadmin_internal',
  String issuerDisplay = 'Usuário interno',
  String profileId = '30000000-0000-4000-8000-000000000001',
  int managementVersion = 4,
}) => {
  'id': '50000000-0000-4000-8000-000000000001',
  'scope_kind': 'institution',
  'institution_id': '10000000-0000-4000-8000-000000000001',
  'unit_id': null,
  'group_id': null,
  'scope_label': 'Colégio Aurora',
  'profile_id': profileId,
  'profile_label': 'Responsável',
  'recipient_label': null,
  'recipient_masked': 'f***@invalid.test',
  'channels': channels,
  'status': 'pending',
  'issuer': {'kind': issuerKind, 'display': issuerDisplay},
  'created_at': '2026-09-01T12:00:00Z',
  'expires_at': '2026-09-03T12:00:00Z',
  'accepted_at': null,
  'revoked_at': null,
  'email_delivery_status': 'not_requested',
  'management_version': managementVersion,
  'timeline': [
    {'label': 'Convite criado', 'occurred_at': '2026-09-01T12:00:00Z'},
  ],
};
