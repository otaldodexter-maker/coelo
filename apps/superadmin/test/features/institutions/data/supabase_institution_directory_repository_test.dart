import 'dart:convert';

import 'package:coelo_superadmin/features/institutions/data/supabase_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_item.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_query.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_record.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_people.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final pageSize in InstitutionDirectoryQuery.allowedPageSizes) {
    test('requests the exact PostgREST range for page size $pageSize', () async {
      Request? capturedRequest;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'publishable-key',
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return Response(
            jsonEncode(<Map<String, Object?>>[]),
            200,
            headers: {
              'content-range': '${pageSize * 2}-${pageSize * 3 - 1}/0',
              'content-type': 'application/json',
            },
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final repository = SupabaseInstitutionDirectoryRepository(client);

      final page = await repository.fetchPage(
        InstitutionDirectoryQuery(page: 2, pageSize: pageSize),
      );

      expect(capturedRequest?.url.queryParameters['offset'], '${pageSize * 2}');
      expect(capturedRequest?.url.queryParameters['limit'], '$pageSize');
      expect(page.pageSize, pageSize);
    });
  }

  test('maps RPC institution payload including nested aggregates and null-safe defaults', () async {
    Request? capturedRequest;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        capturedRequest = request;
        if (request.method != 'POST' ||
            !request.url.pathSegments.any(
              (segment) => segment == 'get_institution_for_superadmin',
            )) {
          return Response('[]', 404, request: request);
        }
        return Response(
          jsonEncode({
            'id': 'institution-1',
            'public_name': 'Instituicao RPC',
            'trade_name': 'RPC',
            'legal_name': 'Instituicao RPC LTDA',
            'document_ref': '12.345.678/0001-99',
            'document_type': 'CNPJ',
            'slug': 'instituicao-rpc',
            'primary_domain': 'rpc.coelo.me',
            'status': 'active',
            'locale': 'pt-BR',
            'timezone': 'America/Sao_Paulo',
            'management_version': 17,
            'institution_type': {'id': 'institution-type-1', 'name': 'Escola'},
            'owner_first_name': 'Ana',
            'owner_last_name': 'Silva',
            'owner_display_name': 'Ana Silva',
            'owner_email': 'ana@coelo.me',
            'owner_mobile_phone': '+55 11 90000-0000',
            'address': {'postal_code': '01310-100', 'state': 'SP', 'number': '120'},
            'contact': {
              'email': 'contato@rpc.coelo.me',
              'website_url': 'https://rpc.coelo.me',
              'whatsapp_number': '+55 11 97777-0000',
            },
            'branding': {
              'display_name': 'RPC Brand',
              'accent_color': '#123456',
              'secondary_color': '#234567',
              'tertiary_color': '#345678',
              'text_color': '#456789',
              'secondary_text_color': '#56789A',
              'tertiary_text_color': '#6789AB',
              'surface_color': '#789ABC',
              'secondary_surface_color': '#89ABCD',
              'profile_bio': 'Uma escola acolhedora.',
              'profile_links': [
                {'label': 'Portal', 'url': 'https://portal.example'},
              ],
              'logo_media_asset_id': 'logo-asset-1',
              'cover_media_asset_id': null,
            },
            'subscription': {
              'plan_code': 'professional',
              'status': 'trial',
              'starts_at': '2026-01-10T00:00:00Z',
              'trial_ends_at': '2026-02-10T00:00:00Z',
              'paused_at': '2026-02-11T00:00:00Z',
              'cancelled_at': '2026-02-12T00:00:00Z',
              'justification': 'Contrato aprovado',
              'manual_reason': 'fallback legado',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseInstitutionDirectoryRepository(client);

    final record = await repository.fetchById('institution-1');

    expect(capturedRequest!.url.pathSegments, contains('get_institution_for_superadmin'));
    final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
    expect(body['p_institution_id'], 'institution-1');
    expect(record.id, 'institution-1');
    expect(record.plan, InstitutionPlan.professional);
    expect(record.subscriptionStatus, InstitutionSubscriptionStatus.trial);
    expect(record.subscriptionStart.year, 2026);
    expect(record.subscriptionPausedAt, DateTime.parse('2026-02-11T00:00:00Z'));
    expect(record.subscriptionCancelledAt, DateTime.parse('2026-02-12T00:00:00Z'));
    expect(record.version, 17);
    expect(record.street, '');
    expect(record.addressNumber, '120');
    expect(record.subscriptionJustification, 'Contrato aprovado');
    expect(record.websiteUrl, 'https://rpc.coelo.me');
    expect(record.whatsappNumber, '+55 11 97777-0000');
    expect(record.accentColor, '#123456');
    expect(record.secondaryColor, '#234567');
    expect(record.tertiaryColor, '#345678');
    expect(record.textColor, '#456789');
    expect(record.secondaryTextColor, '#56789A');
    expect(record.tertiaryTextColor, '#6789AB');
    expect(record.surfaceColor, '#789ABC');
    expect(record.secondarySurfaceColor, '#F4F5F5');
    expect(record.profileBio, 'Uma escola acolhedora.');
    expect(record.profileLinks.single.label, 'Portal');
    expect(record.profileLinks.single.url, 'https://portal.example');
    expect(record.hasSimulatedLogo, isTrue);
    expect(record.hasSimulatedCover, isFalse);
  });
  test('maps unknown enums and nullable fields without crashing', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        return Response(
          jsonEncode({
            'id': 'institution-2',
            'public_name': 'Ambiente',
            'status': 'status-desconhecido',
            'institution_type': {'id': null, 'name': 'Tipo Novo'},
            'subscription': {'plan_code': 'plan-desconhecido', 'status': 'estado-desconhecido'},
            'address': {'postal_code': null},
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseInstitutionDirectoryRepository(client);

    final record = await repository.fetchById('institution-2');

    expect(record.status, InstitutionStatus.draft);
    expect(record.plan, InstitutionPlan.custom);
    expect(record.version, 0);
    expect(record.trialEnd, isNull);
    expect(InstitutionSubscriptionStatus.trial.label, 'Período de teste');
  });
  test('keeps state options unfiltered and cascades distinct location options', () async {
    final capturedUris = <Uri>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        capturedUris.add(request.url);
        final table = request.url.pathSegments.last;
        final locations = [
          {'state': 'SP', 'city': 'Campinas', 'district': 'Centro'},
          {'state': 'SP', 'city': 'Campinas', 'district': 'Centro'},
          {'state': 'PR', 'city': 'Curitiba', 'district': 'Batel'},
        ];
        final body = switch (table) {
          'plans' || 'institution_types' => <Map<String, String>>[],
          'institution_directory_locations' =>
            request.url.queryParameters['select'] == 'state'
                ? locations
                : locations
                      .where(
                        (location) => location['state'] == 'SP' && location['city'] == 'Campinas',
                      )
                      .toList(growable: false),
          _ => <Map<String, String>>[],
        };
        return Response(
          jsonEncode(body),
          200,
          headers: {'content-range': '0-0/1', 'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseInstitutionDirectoryRepository(client);

    final options = await repository.fetchFilterOptions(states: {'SP'}, cities: {'Campinas'});

    final stateRequest = capturedUris.singleWhere(
      (uri) =>
          uri.pathSegments.last == 'institution_directory_locations' &&
          uri.queryParameters['select'] == 'state',
    );
    final dependentRequest = capturedUris.singleWhere(
      (uri) =>
          uri.pathSegments.last == 'institution_directory_locations' &&
          uri.queryParameters['select'] == 'state,city,district',
    );
    expect(stateRequest.queryParameters['state'], isNull);
    expect(stateRequest.queryParameters['city'], isNull);
    expect(dependentRequest.queryParameters['state'], contains('SP'));
    expect(dependentRequest.queryParameters['city'], contains('Campinas'));
    expect(options.states.map((option) => option.label), ['PR', 'SP']);
    expect(options.cities.map((option) => option.label), ['Campinas']);
    expect(options.districts.map((option) => option.label), ['Centro']);
  });

  test('sends multiselect filters as PostgREST IN clauses', () async {
    Uri? capturedUri;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        capturedUri = request.url;
        return Response(
          jsonEncode([
            {
              'id': 'institution-1',
              'public_name': 'Institui\u00e7\u00e3o Aurora',
              'status': 'active',
              'units_count': 1,
              'groups_count': 2,
            },
          ]),
          200,
          headers: {'content-range': '0-0/1', 'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseInstitutionDirectoryRepository(client);

    await repository.fetchPage(
      InstitutionDirectoryQuery(
        statuses: {InstitutionStatus.active, InstitutionStatus.onboarding},
        typeIds: {'school', 'therapy'},
        states: {'SP', 'PR'},
        cities: {'Campinas', 'Curitiba'},
        districts: {'Cambu\u00ed', 'Batel'},
      ),
    );

    final parameters = capturedUri!.queryParameters;
    expect(
      parameters['status'],
      allOf(startsWith('in.('), contains('active'), contains('onboarding')),
    );
    expect(
      parameters['institution_type_id'],
      allOf(startsWith('in.('), contains('school'), contains('therapy')),
    );
    expect(parameters['state'], allOf(startsWith('in.('), contains('SP'), contains('PR')));
    expect(
      parameters['city'],
      allOf(startsWith('in.('), contains('Campinas'), contains('Curitiba')),
    );
    expect(
      parameters['district'],
      allOf(startsWith('in.('), contains('Cambu\u00ed'), contains('Batel')),
    );
  });

  test('uses allowlisted sort and query page size in PostgREST', () async {
    Request? capturedRequest;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        capturedRequest = request;
        return Response(
          '[]',
          200,
          headers: {'content-range': '*/0', 'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseInstitutionDirectoryRepository(client);

    await repository.fetchPage(
      InstitutionDirectoryQuery(
        page: 1,
        pageSize: 8,
        sortColumn: InstitutionDirectorySortColumn.unitsCount,
        sortAscending: false,
      ),
    );

    final order = capturedRequest!.url.queryParameters['order'];
    expect(order, startsWith('units_count.desc'));
    expect(order, contains('id.asc'));
    expect(capturedRequest!.url.queryParameters['offset'], '8');
    expect(capturedRequest!.url.queryParameters['limit'], '8');
  });

  test('create calls RPC with payload and request id', () async {
    Request? capturedRequest;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        capturedRequest = request;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['p_request_id'], isNotNull);
        expect(body['p_payload'], isA<Map>());
        return Response(
          jsonEncode({
            'id': 'created-1',
            'public_name': 'Nova',
            'legal_name': 'Nova LTDA',
            'document_ref': '99.999.999/0001-00',
            'document_type': 'CNPJ',
            'status': 'active',
            'locale': 'pt-BR',
            'timezone': 'America/Sao_Paulo',
            'subscription': {'plan_code': 'essential', 'status': 'active', 'starts_at': null},
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseInstitutionDirectoryRepository(client);

    await repository.create(_institutionDraftForRpc());

    final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
    final payload = Map<String, dynamic>.from(body['p_payload'] as Map);
    expect(capturedRequest!.url.pathSegments, contains('create_institution_for_superadmin'));
    expect(payload.keys.toSet(), {
      'public_name',
      'trade_name',
      'legal_name',
      'slug',
      'primary_domain',
      'document_ref',
      'document_type',
      'status',
      'timezone',
      'locale',
      'institution_type_name',
      'address',
      'contact',
      'branding',
      'subscription',
    });
    expect(payload['institution_type_name'], 'Escola');
    expect(payload.containsKey('id'), isFalse);

    final address = Map<String, dynamic>.from(payload['address'] as Map);
    expect(address.keys.toSet(), {
      'postal_code',
      'country',
      'state',
      'city',
      'district',
      'street',
      'number',
      'complement',
    });
    expect(address['number'], '100');
    expect(address.containsKey('address_number'), isFalse);

    final contact = Map<String, dynamic>.from(payload['contact'] as Map);
    expect(contact.keys.toSet(), {
      'email',
      'phone',
      'mobile_phone',
      'website_url',
      'whatsapp_number',
    });
    expect(contact['website_url'], 'https://rpc.coelo.me');
    expect(contact['whatsapp_number'], '+55 11 97777-0000');

    final branding = Map<String, dynamic>.from(payload['branding'] as Map);
    expect(branding.keys.toSet(), {
      'display_name',
      'accent_color',
      'secondary_color',
      'tertiary_color',
      'text_color',
      'secondary_text_color',
      'tertiary_text_color',
      'surface_color',
      'profile_bio',
      'profile_links',
    });
    expect(branding['profile_bio'], 'Perfil institucional');
    expect(branding['profile_links'], [
      {'label': 'Portal', 'url': 'https://portal.example'},
    ]);

    final subscription = Map<String, dynamic>.from(payload['subscription'] as Map);
    expect(subscription.keys.toSet(), {
      'plan_code',
      'status',
      'starts_at',
      'trial_ends_at',
      'manual_reason',
      'paused_at',
      'cancelled_at',
    });
    expect(subscription['paused_at'], '2026-03-01T00:00:00.000Z');
    expect(subscription['cancelled_at'], '2026-03-02T00:00:00.000Z');
    expect(
      (body['p_request_id'] as String),
      matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
    );
    expect(body['p_payload']['legal_representatives'], isNull);
  });

  test('serializes canceled subscription with the PostgreSQL enum spelling', () {
    final payload = _institutionDraftForRpc(
      slug: 'rpc',
    ).copyWith(subscriptionStatus: InstitutionSubscriptionStatus.canceled).toRpcPayload();

    expect((payload['subscription'] as Map<String, dynamic>)['status'], 'cancelled');
  });

  test('update calls RPC with expected version and request id', () async {
    Request? capturedRequest;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        capturedRequest = request;
        return Response(
          jsonEncode({
            'id': 'created-1',
            'public_name': 'Nova',
            'legal_name': 'Nova LTDA',
            'management_version': 7,
            'subscription': {'plan_code': 'essential', 'status': 'active', 'starts_at': null},
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseInstitutionDirectoryRepository(client);

    await repository.update(
      _institutionDraftForRpc(id: 'created-1', version: 6),
      expectedVersion: 6,
    );

    final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
    expect(capturedRequest!.url.pathSegments, contains('update_institution_for_superadmin'));
    expect(body['p_institution_id'], 'created-1');
    expect(body['p_expected_version'], 6);
    expect(
      (body['p_request_id'] as String),
      matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
    );
  });

  test('blocks relationship payloads before RPC call on create/update', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        fail('RPC should not be called when payload has unsupported relations');
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseInstitutionDirectoryRepository(client);
    final blocked = _institutionDraftForRpc(
      administrators: const [
        InstitutionAdministratorDraft(
          id: 'admin-1',
          person: InstitutionPersonDraft(
            firstName: 'Ana',
            lastName: 'Lima',
            displayName: 'Ana Lima',
          ),
          handle: '@ana-lima',
          level: InstitutionAdministratorLevel.adminMaster,
          invitationStatus: InstitutionInvitationStatus.accepted,
          invitationHistory: [],
        ),
      ],
    );

    await expectLater(
      repository.create(blocked),
      throwsA(isA<InstitutionDirectoryUnsupportedRelationException>()),
    );
    await expectLater(
      repository.update(blocked.copyWith(id: 'created-1'), expectedVersion: 1),
      throwsA(isA<InstitutionDirectoryUnsupportedRelationException>()),
    );
  });

  test('maps unauthorized, not found, conflict, validation and unavailable from RPC', () async {
    const unauthorizedError = PostgrestException(message: 'forbidden', code: '42501');
    const notFoundError = PostgrestException(message: 'missing', code: 'P0002');
    const conflictError = PostgrestException(message: 'conflict', code: '40001');
    const validationError = PostgrestException(message: 'invalid', code: '22023');

    final unauthorizedClient = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        throw unauthorizedError;
      }),
    );
    addTearDown(unauthorizedClient.dispose);

    final notFoundClient = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        throw notFoundError;
      }),
    );
    addTearDown(notFoundClient.dispose);

    final conflictClient = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        throw conflictError;
      }),
    );
    addTearDown(conflictClient.dispose);

    final validationClient = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        throw validationError;
      }),
    );
    addTearDown(validationClient.dispose);

    final unavailableClient = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        throw ClientException('offline', request.url);
      }),
    );
    addTearDown(unavailableClient.dispose);

    await expectLater(
      SupabaseInstitutionDirectoryRepository(unauthorizedClient).fetchById('id'),
      throwsA(isA<InstitutionDirectoryUnauthorizedException>()),
    );
    await expectLater(
      SupabaseInstitutionDirectoryRepository(notFoundClient).fetchById('id'),
      throwsA(isA<InstitutionDirectoryNotFoundException>()),
    );
    await expectLater(
      SupabaseInstitutionDirectoryRepository(
        conflictClient,
      ).update(_institutionDraftForRpc(id: 'created-1'), expectedVersion: 1),
      throwsA(isA<InstitutionDirectoryConflictException>()),
    );
    await expectLater(
      SupabaseInstitutionDirectoryRepository(validationClient).fetchById('id'),
      throwsA(isA<InstitutionDirectoryValidationException>()),
    );
    await expectLater(
      SupabaseInstitutionDirectoryRepository(unavailableClient).fetchById('id'),
      throwsA(isA<InstitutionDirectoryUnavailableException>()),
    );
  });

  for (final code in const ['PGRST000', 'PGRST001', 'PGRST002']) {
    test('maps official unavailable code $code', () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'publishable-key',
        httpClient: MockClient((request) async {
          throw PostgrestException(message: 'unavailable', code: code);
        }),
      );
      addTearDown(client.dispose);

      await expectLater(
        SupabaseInstitutionDirectoryRepository(client).fetchById('id'),
        throwsA(isA<InstitutionDirectoryUnavailableException>()),
      );
    });
  }

  test('reuses request id after ClientException and clears it after success', () async {
    final requestIds = <String>[];
    var attempt = 0;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        requestIds.add(body['p_request_id'] as String);
        attempt++;
        if (attempt == 1) {
          throw ClientException('offline', request.url);
        }
        return _successfulRpcResponse(request);
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseInstitutionDirectoryRepository(client);
    final draft = _institutionDraftForRpc();

    await expectLater(
      repository.create(draft),
      throwsA(isA<InstitutionDirectoryUnavailableException>()),
    );
    await repository.create(draft);
    await repository.create(draft);

    expect(requestIds[1], requestIds[0]);
    expect(requestIds[2], isNot(requestIds[1]));
  });

  test('changed payload gets a new request id after transport failure', () async {
    final requestIds = <String>[];
    var attempt = 0;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        requestIds.add(body['p_request_id'] as String);
        attempt++;
        if (attempt == 1) {
          throw ClientException('offline', request.url);
        }
        return _successfulRpcResponse(request);
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseInstitutionDirectoryRepository(client);
    final draft = _institutionDraftForRpc();

    await expectLater(
      repository.create(draft),
      throwsA(isA<InstitutionDirectoryUnavailableException>()),
    );
    await repository.create(draft.copyWith(publicName: 'Outro nome'));

    expect(requestIds[1], isNot(requestIds[0]));
  });

  for (final code in const ['PGRST000', 'PGRST001', 'PGRST002']) {
    test('reuses update request id after transient $code', () async {
      final requestIds = <String>[];
      var attempt = 0;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'publishable-key',
        httpClient: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          requestIds.add(body['p_request_id'] as String);
          attempt++;
          if (attempt == 1) {
            throw PostgrestException(message: 'unavailable', code: code);
          }
          return _successfulRpcResponse(request);
        }),
      );
      addTearDown(client.dispose);
      final repository = SupabaseInstitutionDirectoryRepository(client);
      final draft = _institutionDraftForRpc(id: 'created-1', version: 6);

      await expectLater(
        repository.update(draft, expectedVersion: 6),
        throwsA(isA<InstitutionDirectoryUnavailableException>()),
      );
      await repository.update(draft, expectedVersion: 6);

      expect(requestIds[1], requestIds[0]);
    });
  }

  test('definitive error clears pending request id', () async {
    final requestIds = <String>[];
    var attempt = 0;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        requestIds.add(body['p_request_id'] as String);
        attempt++;
        if (attempt == 1) {
          throw ClientException('offline', request.url);
        }
        if (attempt == 2) {
          throw const PostgrestException(message: 'invalid', code: '22023');
        }
        return _successfulRpcResponse(request);
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseInstitutionDirectoryRepository(client);
    final draft = _institutionDraftForRpc();

    await expectLater(
      repository.create(draft),
      throwsA(isA<InstitutionDirectoryUnavailableException>()),
    );
    await expectLater(
      repository.create(draft),
      throwsA(isA<InstitutionDirectoryValidationException>()),
    );
    await repository.create(draft);

    expect(requestIds[1], requestIds[0]);
    expect(requestIds[2], isNot(requestIds[1]));
  });

  test('does not classify invented PostgREST code as unavailable', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        throw const PostgrestException(message: 'unexpected', code: 'PGRST0002');
      }),
    );
    addTearDown(client.dispose);

    await expectLater(
      SupabaseInstitutionDirectoryRepository(client).fetchById('id'),
      throwsA(isA<InstitutionDirectoryUnexpectedException>()),
    );
  });
}

InstitutionRecord _institutionDraftForRpc({
  String id = 'institution-1',
  String slug = 'instituicao-rpc',
  int version = 1,
  List<InstitutionLegalRepresentative> legalRepresentatives = const [],
  List<InstitutionAdministratorDraft> administrators = const [],
}) {
  return InstitutionRecord(
    id: id,
    publicName: 'Instituicao RPC',
    tradeName: 'RPC',
    legalName: 'RPC LTDA',
    typeId: '',
    typeName: 'Escola',
    documentType: 'CNPJ',
    document: '99.999.999/0001-00',
    slug: slug,
    primaryDomain: 'rpc.coelo.me',
    status: InstitutionStatus.active,
    locale: 'pt-BR',
    timezone: 'America/Sao_Paulo',
    postalCode: '01310-100',
    country: 'Brasil',
    state: 'SP',
    city: 'Sao Paulo',
    district: 'Centro',
    street: 'Rua RPC',
    addressNumber: '100',
    complement: '',
    contactEmail: 'contato@rpc.coelo.me',
    contactPhone: '+55 11 3333-0000',
    contactMobilePhone: '+55 11 99999-0000',
    ownerFirstName: 'Ana',
    ownerLastName: 'Silva',
    ownerDisplayName: 'Ana Silva',
    ownerEmail: 'ana@rpc.coelo.me',
    ownerMobilePhone: '+55 11 98888-0000',
    plan: InstitutionPlan.essential,
    subscriptionStatus: InstitutionSubscriptionStatus.active,
    subscriptionStart: DateTime(2026, 1, 1),
    trialEnd: null,
    subscriptionPausedAt: DateTime.utc(2026, 3, 1),
    subscriptionCancelledAt: DateTime.utc(2026, 3, 2),
    subscriptionJustification: '',
    brandDisplayName: 'RPC',
    hasSimulatedLogo: true,
    hasSimulatedCover: false,
    accentColor: '#D63C00',
    secondaryColor: '#3F4549',
    units: const [],
    tertiaryColor: '#112233',
    textColor: '#223344',
    secondaryTextColor: '#334455',
    tertiaryTextColor: '#445566',
    surfaceColor: '#556677',
    secondarySurfaceColor: '#F4F5F5',
    profileBio: 'Perfil institucional',
    profileLinks: const [InstitutionProfileLink(label: 'Portal', url: 'https://portal.example')],
    websiteUrl: 'https://rpc.coelo.me',
    whatsappNumber: '+55 11 97777-0000',
    legalRepresentatives: legalRepresentatives,
    administrators: administrators,
    version: version,
  );
}

Response _successfulRpcResponse(Request request) {
  return Response(
    jsonEncode({
      'id': 'saved-1',
      'public_name': 'Instituição salva',
      'status': 'active',
      'management_version': 7,
      'subscription': {'plan_code': 'essential', 'status': 'active', 'starts_at': null},
    }),
    200,
    headers: {'content-type': 'application/json'},
    request: request,
  );
}
