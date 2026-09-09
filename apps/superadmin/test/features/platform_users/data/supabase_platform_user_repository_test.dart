import 'dart:async';
import 'dart:convert';

import 'package:coelo_superadmin/features/platform_users/data/supabase_platform_user_repository.dart';
import 'package:coelo_superadmin/features/platform_users/domain/platform_user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final section in ['credential', 'invitation']) {
    test(
      'unknown $section status is rejected instead of displayed as active or accepted',
      () async {
        final client = SupabaseClient(
          'https://example.supabase.co',
          'publishable-key',
          httpClient: MockClient(
            (request) async => Response(
              jsonEncode({
                ..._recordJson,
                section: {...(_recordJson[section] as Map<String, Object?>), 'status': 'unknown'},
              }),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            ),
          ),
        );
        addTearDown(client.dispose);
        final repository = SupabasePlatformUserRepository(client);
        await expectLater(
          repository.fetchById(_identityId),
          throwsA(isA<PlatformUserRuleException>()),
        );
        expect(repository.records, isEmpty);
      },
    );
  }

  test('user detail and status accept canonical casing of a requested UUID', () async {
    const id = 'aaaaaaaa-0000-4000-8000-000000000001';
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient(
        (request) async => Response(
          jsonEncode(
            request.url.path.endsWith('superadmin_internal_user_profiles')
                ? {
                    'items': [_profileJson],
                  }
                : {
                    ..._recordJson,
                    'identity': {...(_recordJson['identity'] as Map<String, dynamic>), 'id': id},
                  },
          ),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);
    final repository = SupabasePlatformUserRepository(client);
    expect((await repository.fetchById(id.toUpperCase()))?.id, id);
    expect((await repository.suspend(id.toUpperCase())).id, id);
  });

  for (final operation in ['detail', 'update', 'status']) {
    test('$operation rejects another identity without replacing the authorized cache', () async {
      var wrongResponse = false;
      final commandBodies = <Map<String, dynamic>>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'publishable-key',
        httpClient: MockClient((request) async {
          final isCommand =
              request.url.path.endsWith('superadmin_internal_user_update') ||
              request.url.path.endsWith('superadmin_internal_user_change_status');
          if (isCommand) commandBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          final payload = request.url.path.endsWith('superadmin_internal_user_profiles')
              ? {
                  'items': [_profileJson],
                }
              : wrongResponse
              ? {
                  ..._recordJson,
                  'identity': {
                    ...(_recordJson['identity'] as Map<String, dynamic>),
                    'id': 'other-internal-identity',
                  },
                }
              : _recordJson;
          return Response(
            jsonEncode(payload),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final repository = SupabasePlatformUserRepository(client);
      final original = (await repository.fetchById(_identityId))!;
      Future<Object?> run() => switch (operation) {
        'detail' => repository.fetchById(_identityId),
        'status' => repository.suspend(_identityId),
        _ => repository.update(
          _identityId,
          PlatformUserDraft(
            identity: original.identity,
            profile: original.profile,
            scope: original.scope,
            scopeIds: original.membership.scopeIds,
          ),
        ),
      };
      wrongResponse = true;
      await expectLater(run(), throwsA(isA<PlatformUserRuleException>()));
      expect(repository.records, [same(original)]);
      expect(repository.findById('other-internal-identity'), isNull);
      wrongResponse = false;
      await run();
      if (operation != 'detail') {
        expect(commandBodies, hasLength(2));
        expect(commandBodies[1]['p_request_id'], commandBodies[0]['p_request_id']);
      }
    });
  }

  for (final operation in ['update', 'status']) {
    for (final change in ['none', 'draft', 'session']) {
      test('$operation retry after a lost response respects change=$change', () async {
        final commandBodies = <Map<String, dynamic>>[];
        final client = SupabaseClient(
          'https://example.supabase.co',
          'publishable-key',
          httpClient: MockClient((request) async {
            final isCommand =
                request.url.path.endsWith('superadmin_internal_user_update') ||
                request.url.path.endsWith('superadmin_internal_user_change_status');
            if (isCommand) {
              commandBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
              if (commandBodies.length == 1) throw ClientException('synthetic lost response');
            }
            final payload = request.url.path.endsWith('superadmin_internal_user_profiles')
                ? {
                    'items': [_profileJson],
                  }
                : _recordJson;
            return Response(
              jsonEncode(payload),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        );
        addTearDown(client.dispose);
        final repository = SupabasePlatformUserRepository(client);
        final current = (await repository.fetchById(_identityId))!;
        Future<PlatformUserRecord> command({bool changed = false}) => operation == 'status'
            ? changed
                  ? repository.reactivate(_identityId)
                  : repository.suspend(_identityId)
            : repository.update(
                _identityId,
                PlatformUserDraft(
                  identity: changed
                      ? current.identity.copyWith(jobTitle: 'Novo cargo sintético')
                      : current.identity,
                  profile: current.profile,
                  scope: current.scope,
                  scopeIds: current.membership.scopeIds,
                ),
              );
        await expectLater(
          command(),
          throwsA(
            isA<PlatformUserRuleException>()
                .having((error) => error.code, 'code', 'backend')
                .having(
                  (error) => error.message,
                  'sanitized message',
                  isNot(contains('synthetic lost response')),
                ),
          ),
        );
        if (change == 'session') {
          repository.clearSessionCache();
          await repository.fetchById(_identityId);
        }
        await command(changed: change == 'draft');
        await command(changed: change == 'draft');
        expect(commandBodies, hasLength(3));
        expect(
          commandBodies[1]['p_request_id'],
          change == 'none'
              ? commandBodies[0]['p_request_id']
              : isNot(commandBodies[0]['p_request_id']),
        );
        expect(commandBodies[2]['p_request_id'], isNot(commandBodies[1]['p_request_id']));
        expect(commandBodies[1]['p_expected_version'], commandBodies[0]['p_expected_version']);
      });
    }
  }

  for (final operation in ['profiles', 'list', 'detail', 'status']) {
    for (final oldDenial in [false, true]) {
      test('late $operation response denial=$oldDenial preserves the new cache', () async {
        var blockNext = false;
        final started = Completer<void>();
        final release = Completer<void>();
        final function = switch (operation) {
          'profiles' => 'superadmin_internal_user_profiles',
          'list' => 'superadmin_internal_users_list',
          'detail' => 'superadmin_internal_user_detail',
          _ => 'superadmin_internal_user_change_status',
        };
        final client = SupabaseClient(
          'https://example.supabase.co',
          'publishable-key',
          httpClient: MockClient((request) async {
            if (blockNext && request.url.path.endsWith(function)) {
              blockNext = false;
              started.complete();
              await release.future;
              if (oldDenial) {
                return Response(
                  jsonEncode({'code': '42501', 'message': 'old private detail'}),
                  403,
                  headers: {'content-type': 'application/json'},
                  request: request,
                );
              }
            }
            final body = request.url.path.endsWith('superadmin_internal_user_profiles')
                ? {
                    'items': [_profileJson],
                  }
                : request.url.path.endsWith('superadmin_internal_users_list')
                ? {
                    'items': [_recordJson],
                    'total': 1,
                  }
                : _recordJson;
            return Response(
              jsonEncode(body),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        );
        addTearDown(client.dispose);
        final repository = SupabasePlatformUserRepository(client);
        await repository.fetchPage(const PlatformUserQuery());
        blockNext = true;
        final Future<Object?> pending = switch (operation) {
          'profiles' => repository.fetchProfiles(),
          'list' => repository.fetchPage(const PlatformUserQuery()),
          'detail' => repository.fetchById(_identityId),
          _ => repository.suspend(_identityId),
        };
        final denied = expectLater(
          pending,
          throwsA(
            isA<PlatformUserRuleException>().having((error) => error.code, 'code', 'unauthorized'),
          ),
        );
        await started.future;
        repository.clearSessionCache();
        await repository.fetchPage(const PlatformUserQuery());
        final currentRecord = repository.records.single;
        final currentProfile = repository.profiles.single;
        release.complete();
        await denied;
        expect(repository.records.single, same(currentRecord));
        expect(repository.profiles.single, same(currentProfile));
      });
    }
  }

  test('clearing session cache removes records and profiles', () async {
    final client = _client([]);
    addTearDown(client.dispose);
    final repository = SupabasePlatformUserRepository(client);
    await repository.fetchPage(const PlatformUserQuery());
    expect(repository.records, isNotEmpty);
    expect(repository.profiles, isNotEmpty);
    repository.clearSessionCache();
    expect(repository.records, isEmpty);
    expect(repository.profiles, isEmpty);
    expect(repository.findById(_identityId), isNull);
  });

  test('pending list cannot repopulate a cleared session cache', () async {
    final pending = Completer<Response>();
    final started = Completer<void>();
    late Request listRequest;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('superadmin_internal_user_profiles')) {
          return Response(
            jsonEncode({
              'items': [_profileJson],
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        listRequest = request;
        started.complete();
        return pending.future;
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabasePlatformUserRepository(client);
    final result = repository.fetchPage(const PlatformUserQuery());
    final denied = expectLater(
      result,
      throwsA(
        isA<PlatformUserRuleException>().having((error) => error.code, 'code', 'unauthorized'),
      ),
    );
    await started.future;
    repository.clearSessionCache();
    pending.complete(
      Response(
        jsonEncode({
          'items': [_recordJson],
          'total': 1,
        }),
        200,
        headers: {'content-type': 'application/json'},
        request: listRequest,
      ),
    );
    await denied;
    expect(repository.records, isEmpty);
    expect(repository.profiles, isEmpty);
  });

  for (final envelope in [true, false]) {
    test('authorization denial clears populated caches envelope=$envelope', () async {
      var deny = false;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'publishable-key',
        httpClient: MockClient((request) async {
          final Object body = deny
              ? (envelope
                    ? {
                        'ok': false,
                        'error': {'code': 'SAI_SESSION_INVALID'},
                      }
                    : {'code': '42501', 'message': 'private detail'})
              : request.url.path.endsWith('superadmin_internal_user_profiles')
              ? {
                  'items': [_profileJson],
                }
              : {
                  'items': [_recordJson],
                  'total': 1,
                };
          return Response(
            jsonEncode(body),
            deny && !envelope ? 403 : 200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final repository = SupabasePlatformUserRepository(client);
      await repository.fetchPage(const PlatformUserQuery());
      deny = true;
      await expectLater(
        repository.fetchPage(const PlatformUserQuery()),
        throwsA(isA<PlatformUserRuleException>()),
      );
      expect(repository.records, isEmpty);
      expect(repository.profiles, isEmpty);
    });
  }

  test('preserves the existing typed MFA error before generic privilege denial', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient(
        (request) async => Response(
          jsonEncode({'code': '42501', 'message': 'private detail', 'details': 'SAI_MFA_REQUIRED'}),
          403,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);
    await expectLater(
      SupabasePlatformUserRepository(client).fetchPage(const PlatformUserQuery()),
      throwsA(isA<PlatformUserRuleException>().having((error) => error.code, 'code', 'mfa')),
    );
  });
  for (final code in ['42501', 'PGRST301', 'PGRST302', 'PGRST303']) {
    test('sanitizes authorization transport error $code', () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'publishable-key',
        httpClient: MockClient(
          (request) async => Response(
            jsonEncode({
              'code': code,
              'message': 'private backend detail',
              'details': 'private context',
            }),
            code == '42501' ? 403 : 401,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        ),
      );
      addTearDown(client.dispose);
      await expectLater(
        SupabasePlatformUserRepository(client).fetchPage(const PlatformUserQuery()),
        throwsA(
          isA<PlatformUserRuleException>()
              .having((error) => error.code, 'code', 'unauthorized')
              .having((error) => error.message, 'message', 'Acesso não autorizado.'),
        ),
      );
    });
  }

  for (final code in ['SAI_AUTH_REQUIRED', 'SAI_SESSION_INVALID']) {
    test('maps session denial envelope $code to unauthorized', () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'publishable-key',
        httpClient: MockClient(
          (request) async => Response(
            jsonEncode({
              'ok': false,
              'data': null,
              'error': {'code': code, 'message': 'private detail'},
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        ),
      );
      addTearDown(client.dispose);
      await expectLater(
        SupabasePlatformUserRepository(client).fetchPage(const PlatformUserQuery()),
        throwsA(
          isA<PlatformUserRuleException>()
              .having((error) => error.code, 'code', 'unauthorized')
              .having((error) => error.message, 'message', 'Acesso não autorizado.'),
        ),
      );
    });
  }

  test('loads the protected directory and keeps the server projection cached', () async {
    final paths = <String>[];
    final client = _client(paths);
    addTearDown(client.dispose);
    final repository = SupabasePlatformUserRepository(client);

    final page = await repository.fetchPage(const PlatformUserQuery());

    expect(page.totalCount, 1);
    expect(page.items.single.fullName, 'Ana Lima');
    expect(page.items.single.membership.scopeIds, isNotEmpty);
    expect(repository.findById(_identityId), same(page.items.single));
    expect(paths, contains(endsWith('/rpc/superadmin_internal_users_list')));
    expect(paths, everyElement(contains('/rest/v1/rpc/superadmin_')));
  });

  test('deep link fetches detail before a directory cache exists', () async {
    final paths = <String>[];
    final client = _client(paths);
    addTearDown(client.dispose);
    final repository = SupabasePlatformUserRepository(client);

    final record = await repository.fetchById(_identityId);

    expect(record?.email, 'ana.lima@coelo.me');
    expect(paths, contains(endsWith('/rpc/superadmin_internal_user_detail')));
  });

  test('update and suspension use guarded versioned RPC commands', () async {
    final requests = <Request>[];
    final client = _client(<String>[], requests: requests);
    addTearDown(client.dispose);
    final repository = SupabasePlatformUserRepository(client);
    final current = await repository.fetchById(_identityId);

    await repository.update(
      _identityId,
      PlatformUserDraft(
        identity: current!.identity.copyWith(jobTitle: 'Líder de operações'),
        profile: current.profile,
        scope: current.scope,
        scopeIds: current.membership.scopeIds,
        scopeNames: current.membership.scopeNames,
      ),
    );
    await repository.suspend(_identityId);

    final update = requests.singleWhere(
      (request) => request.url.path.endsWith('superadmin_internal_user_update'),
    );
    final suspend = requests.singleWhere(
      (request) => request.url.path.endsWith('superadmin_internal_user_change_status'),
    );
    final updateBody = jsonDecode(update.body) as Map<String, dynamic>;
    final suspendBody = jsonDecode(suspend.body) as Map<String, dynamic>;
    expect(updateBody['p_expected_version'], 3);
    expect(updateBody['p_draft']['identity']['job_title'], 'Líder de operações');
    expect(suspendBody['p_status'], 'suspended');
    expect(suspendBody['p_reason'], isNotEmpty);
  });

  test('productive creation and invitation actions stay fail closed', () async {
    final client = _client(<String>[]);
    addTearDown(client.dispose);
    final repository = SupabasePlatformUserRepository(client);
    final record = await repository.fetchById(_identityId);

    expect(
      () => repository.create(
        PlatformUserDraft(identity: record!.identity, profile: record.profile, scope: record.scope),
      ),
      throwsA(
        isA<PlatformUserRuleException>().having(
          (error) => error.code,
          'code',
          'invitation-contract',
        ),
      ),
    );
    expect(
      () => repository.resendInvitation(_identityId),
      throwsA(isA<PlatformUserRuleException>()),
    );
  });

  test('maps a successful HTTP denial envelope without exposing backend details', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient(
        (request) async => Response(
          jsonEncode({
            'ok': false,
            'data': null,
            'error': {
              'code': 'SAI_PERMISSION_DENIED',
              'message': 'Acesso não autorizado.',
              'correlation_id': '97000000-0000-4000-8000-000000000009',
              'http_status': 403,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);
    final repository = SupabasePlatformUserRepository(client);

    await expectLater(
      repository.fetchById(_identityId),
      throwsA(
        isA<PlatformUserRuleException>()
            .having((error) => error.code, 'code', 'unauthorized')
            .having((error) => error.message, 'message', 'Acesso não autorizado.'),
      ),
    );
  });
}

SupabaseClient _client(List<String> paths, {List<Request>? requests}) => SupabaseClient(
  'https://example.supabase.co',
  'publishable-key',
  httpClient: MockClient((request) async {
    paths.add(request.url.path);
    requests?.add(request);
    final body = request.url.path.endsWith('superadmin_internal_user_profiles')
        ? {
            'items': [_profileJson],
            'total': 1,
            'page': 1,
            'page_size': 100,
          }
        : request.url.path.endsWith('superadmin_internal_users_list')
        ? {
            'items': [_recordJson],
            'total': 1,
            'page': 1,
            'page_size': 11,
          }
        : _recordJson;
    return Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }),
);

const _identityId = '30000000-0000-4000-8000-000000000001';
const _profileId = '50000000-0000-4000-8000-000000000001';
const _institutionId = '60000000-0000-4000-8000-000000000001';

const _profileJson = <String, Object?>{
  'id': _profileId,
  'code': 'operations',
  'name': 'Operations',
  'status': 'active',
  'max_scope_kind': 'platform',
  'permissions': ['platform.read', 'platform.member.update'],
};

const _recordJson = <String, Object?>{
  'id': _identityId,
  'version': 3,
  'identity': {
    'id': _identityId,
    'first_name': 'Ana',
    'last_name': 'Lima',
    'display_name': 'Ana Lima',
    'birth_date': '1990-05-12',
    'cpf': '52998224725',
    'professional_email': 'ana.lima@coelo.me',
    'mobile': '11999999999',
    'additional_phone': '',
    'job_title': 'Operações',
    'department': 'Operações',
    'internal_function': 'Atendimento',
    'professional_notes': '',
    'postal_code': '01310100',
    'street': 'Avenida Paulista',
    'number': '1000',
    'complement': '',
    'neighborhood': 'Bela Vista',
    'city': 'São Paulo',
    'state': 'SP',
    'country': 'Brasil',
  },
  'credential': {'status': 'active'},
  'memberships': [
    {
      'id': '70000000-0000-4000-8000-000000000001',
      'status': 'active',
      'scope': 'limited',
      'scope_ids': [_institutionId],
      'scope_names': ['Instituição Aurora'],
      'started_at': '2026-08-01T12:00:00Z',
      'ended_at': null,
      'profile': _profileJson,
    },
  ],
  'invitation': {
    'id': '80000000-0000-4000-8000-000000000001',
    'email': 'ana.lima@coelo.me',
    'status': 'accepted',
    'attempts': 1,
    'updated_at': '2026-08-01T12:00:00Z',
  },
  'history': [],
};
