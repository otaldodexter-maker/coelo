import 'dart:convert';

import 'package:coelo_superadmin/features/institutions/data/supabase_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_item.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_query.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final (field, draft) in <(String, InstitutionRecord)>[
    ('documentType', _draft().copyWith(documentType: 'sentinel-documentType')),
    ('document', _draft().copyWith(document: 'sentinel-document')),
    ('slug', _draft().copyWith(slug: 'sentinel-slug')),
    ('primaryDomain', _draft().copyWith(primaryDomain: 'sentinel-primaryDomain')),
    ('contactPhone', _draft().copyWith(contactPhone: 'sentinel-contactPhone')),
    ('contactMobilePhone', _draft().copyWith(contactMobilePhone: 'sentinel-contactMobilePhone')),
    ('websiteUrl', _draft().copyWith(websiteUrl: 'sentinel-websiteUrl')),
    ('whatsappNumber', _draft().copyWith(whatsappNumber: 'sentinel-whatsappNumber')),
    ('ownerFirstName', _draft().copyWith(ownerFirstName: 'sentinel-ownerFirstName')),
    ('ownerLastName', _draft().copyWith(ownerLastName: 'sentinel-ownerLastName')),
    ('ownerDisplayName', _draft().copyWith(ownerDisplayName: 'sentinel-ownerDisplayName')),
    ('ownerEmail', _draft().copyWith(ownerEmail: 'sentinel-ownerEmail')),
    ('ownerMobilePhone', _draft().copyWith(ownerMobilePhone: 'sentinel-ownerMobilePhone')),
    ('brandDisplayName', _draft().copyWith(brandDisplayName: 'sentinel-brandDisplayName')),
    ('profileBio', _draft().copyWith(profileBio: 'sentinel-profileBio')),
    ('accentColor', _draft().copyWith(accentColor: 'sentinel-accentColor')),
    ('secondaryColor', _draft().copyWith(secondaryColor: 'sentinel-secondaryColor')),
    ('tertiaryColor', _draft().copyWith(tertiaryColor: 'sentinel-tertiaryColor')),
    ('textColor', _draft().copyWith(textColor: 'sentinel-textColor')),
    ('secondaryTextColor', _draft().copyWith(secondaryTextColor: 'sentinel-secondaryTextColor')),
    ('tertiaryTextColor', _draft().copyWith(tertiaryTextColor: 'sentinel-tertiaryTextColor')),
    ('surfaceColor', _draft().copyWith(surfaceColor: 'sentinel-surfaceColor')),
    (
      'subscriptionJustification',
      _draft().copyWith(subscriptionJustification: 'sentinel-subscriptionJustification'),
    ),
    ('typeName', _draft().copyWith(typeName: 'sentinel-typeName')),
  ]) {
    test('rejects unsupported $field without a partial write', () async {
      var writes = 0;
      final repository = _repository((request) async {
        if (request.url.pathSegments.contains('superadmin_institution_edit_core_v2')) {
          writes++;
          return _json(request, _ok({'institution_id': 'institution-1', 'management_version': 8}));
        }
        return _json(request, _ok(_detailRow()));
      });
      await expectLater(
        repository.update(draft, expectedVersion: 7),
        throwsA(isA<InstitutionDirectoryUnsupportedRelationException>()),
      );
      expect(writes, 0);
    });
  }

  test('retry does not discard a newly changed type label', () async {
    var writes = 0;
    final repository = _repository((request) async {
      if (request.url.pathSegments.contains('superadmin_institution_edit_core_v2')) {
        writes++;
        throw ClientException('response lost');
      }
      return _json(request, _ok(_detailRow()));
    });
    await expectLater(
      repository.update(_draft(), expectedVersion: 7),
      throwsA(isA<InstitutionDirectoryUnavailableException>()),
    );
    await expectLater(
      repository.update(_draft().copyWith(typeName: 'Changed'), expectedVersion: 7),
      throwsA(isA<InstitutionDirectoryUnsupportedRelationException>()),
    );
    expect(writes, 1);
  });

  test('does not discard contact edits while reporting core save success', () async {
    var writes = 0;
    final repository = _repository((request) async {
      if (request.url.pathSegments.contains('superadmin_institution_edit_core_v2')) {
        writes++;
        return _json(request, _ok({'institution_id': 'institution-1', 'management_version': 8}));
      }
      return _json(request, _ok(_detailRow()));
    });

    await expectLater(
      repository.update(
        _draft().copyWith(contactEmail: 'changed@example.test'),
        expectedVersion: 7,
      ),
      throwsA(isA<InstitutionDirectoryUnsupportedRelationException>()),
    );
    expect(writes, 0);
  });

  test('keeps existing non-core values while editing approved core fields', () async {
    var writes = 0;
    final row = {
      ..._detailRow(),
      'contact': {'email': 'existing@example.test'},
      'branding': {'display_name': 'Marca existente', 'profile_bio': 'Bio existente'},
    };
    final repository = _repository((request) async {
      if (request.url.pathSegments.contains('superadmin_institution_edit_core_v2')) {
        writes++;
        return _json(request, _ok({'institution_id': 'institution-1', 'management_version': 8}));
      }
      return _json(request, _ok({...row, 'management_version': writes == 0 ? 7 : 8}));
    });
    final draft = InstitutionRecord.fromRpcPayload(row).copyWith(legalName: 'Novo nome legal');
    final saved = await repository.update(draft, expectedVersion: 7);
    expect(writes, 1);
    expect(saved.contactEmail, 'existing@example.test');
    expect(saved.profileBio, 'Bio existente');
  });

  test('terminal reload denial clears the pending edit request', () async {
    final requestIds = <String>[];
    var detailCalls = 0;
    final repository = _repository((request) async {
      if (request.url.pathSegments.contains('superadmin_institution_edit_core_v2')) {
        requestIds.add((jsonDecode(request.body) as Map)['p_request_id'] as String);
        return _json(request, _ok({'institution_id': 'institution-1', 'management_version': 8}));
      }
      if (++detailCalls == 2) {
        return _json(request, {
          'ok': false,
          'error': {'code': 'SAI_PERMISSION_DENIED'},
        });
      }
      return _json(request, _ok(_detailRow(version: 8)));
    });
    await expectLater(
      repository.update(_draft(), expectedVersion: 7),
      throwsA(isA<InstitutionDirectoryUnauthorizedException>()),
    );
    await repository.update(_draft(), expectedVersion: 7);
    expect(requestIds, hasLength(2));
    expect(requestIds.last, isNot(requestIds.first));
  });

  test('retry after accepted edit and transient reload failure retains request ID', () async {
    final requestIds = <String>[];
    var detailCalls = 0;
    final repository = _repository((request) async {
      if (request.url.pathSegments.contains('superadmin_institution_edit_core_v2')) {
        requestIds.add((jsonDecode(request.body) as Map)['p_request_id'] as String);
        return _json(request, _ok({'institution_id': 'institution-1', 'management_version': 8}));
      }
      if (++detailCalls == 2) throw ClientException('connection interrupted');
      return _json(request, _ok(_detailRow(version: 8)));
    });
    await expectLater(
      repository.update(_draft(), expectedVersion: 7),
      throwsA(isA<InstitutionDirectoryUnavailableException>()),
    );
    final saved = await repository.update(_draft(), expectedVersion: 7);
    expect(saved.version, 8);
    expect(requestIds, hasLength(2));
    expect(requestIds.last, requestIds.first);
  });

  test('lists through the internal v2 envelope with server pagination', () async {
    Request? captured;
    final repository = _repository((request) async {
      captured = request;
      return _json(
        request,
        _ok({
          'items': [_directoryRow('institution-1')],
          'total_count': 1,
        }),
      );
    });

    final page = await repository.fetchPage(
      InstitutionDirectoryQuery(
        page: 2,
        search: 'Aurora',
        statuses: {InstitutionStatus.active},
        states: {'SP'},
      ),
    );

    expect(captured!.url.pathSegments, contains('superadmin_institution_directory_v2'));
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['p_offset'], 22);
    expect(body['p_limit'], 11);
    expect(body['p_filters'], {
      'search': 'Aurora',
      'statuses': ['active'],
      'states': ['SP'],
    });
    expect(page.items.single.publicName, 'Instituição institution-1');
    expect(page.totalCount, 1);
  });

  test('splits the optional 500 item page into backend-safe chunks', () async {
    final limits = <int>[];
    final offsets = <int>[];
    final repository = _repository((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      limits.add(body['p_limit'] as int);
      offsets.add(body['p_offset'] as int);
      final offset = body['p_offset'] as int;
      final rows = offset == 0
          ? List.generate(100, (index) => _directoryRow('institution-$index'))
          : <Map<String, Object?>>[];
      return _json(request, _ok({'items': rows, 'total_count': 100}));
    });

    final page = await repository.fetchPage(InstitutionDirectoryQuery(pageSize: 500));

    expect(limits, [100, 100]);
    expect(offsets, [0, 100]);
    expect(page.items, hasLength(100));
    expect(page.pageSize, 500);
  });

  test('reads detail through the approved internal v2 gateway', () async {
    Request? captured;
    final repository = _repository((request) async {
      captured = request;
      return _json(request, _ok(_detailRow()));
    });

    final record = await repository.fetchById('institution-1');

    expect(captured!.url.pathSegments, contains('superadmin_institution_detail_v2'));
    expect(record.id, 'institution-1');
    expect(record.version, 7);
    expect(record.city, 'São Paulo');
  });

  test('loads cascading filters through the internal options gateway', () async {
    Request? captured;
    final repository = _repository((request) async {
      captured = request;
      return _json(
        request,
        _ok({
          'plans': [
            {'id': 'plan-1', 'label': 'Essencial'},
          ],
          'types': [
            {'id': 'type-1', 'label': 'Escola'},
          ],
          'states': [
            {'id': 'SP', 'label': 'SP'},
          ],
          'cities': [
            {'id': 'São Paulo', 'label': 'São Paulo'},
          ],
          'districts': [
            {'id': 'Centro', 'label': 'Centro'},
          ],
        }),
      );
    });

    final options = await repository.fetchFilterOptions(states: {'SP'}, cities: {'São Paulo'});

    expect(captured!.url.pathSegments, contains('superadmin_institution_filter_options_v2'));
    expect(options.plans.single.label, 'Essencial');
    expect(options.districts.single.id, 'Centro');
  });

  test('updates approved core fields then reloads authoritative detail', () async {
    final calls = <Request>[];
    final repository = _repository((request) async {
      calls.add(request);
      if (request.url.pathSegments.contains('superadmin_institution_edit_core_v2')) {
        return _json(request, _ok({'institution_id': 'institution-1', 'management_version': 8}));
      }
      return _json(request, _ok(_detailRow(version: 8)));
    });

    final saved = await repository.update(_draft(), expectedVersion: 7);

    expect(calls, hasLength(3));
    final body = jsonDecode(calls[1].body) as Map<String, dynamic>;
    expect(body['p_expected_version'], 7);
    final payload = Map<String, dynamic>.from(body['p_payload'] as Map);
    expect(payload.keys.toSet(), {
      'public_name',
      'trade_name',
      'legal_name',
      'timezone',
      'locale',
      'institution_type_id',
      'address',
    });
    expect((payload['address'] as Map)['postal_code'], '01310100');
    expect(saved.version, 8);
  });

  test('creates through the internal v2 gateway then reloads authoritative detail', () async {
    final calls = <Request>[];
    final repository = _repository((request) async {
      calls.add(request);
      if (request.url.pathSegments.contains('superadmin_institution_create_v2')) {
        return _json(request, _ok({'institution_id': 'institution-9', 'management_version': 1}));
      }
      return _json(request, _ok({..._detailRow(version: 1), 'id': 'institution-9'}));
    });

    final saved = await repository.create(_draft().copyWith(slug: 'aurora'));

    expect(calls, hasLength(2));
    expect(calls[0].url.pathSegments, contains('superadmin_institution_create_v2'));
    final body = jsonDecode(calls[0].body) as Map<String, dynamic>;
    expect(body['p_request_id'], isNotEmpty);
    final payload = Map<String, dynamic>.from(body['p_payload'] as Map);
    expect(payload.keys.toSet(), {
      'public_name',
      'trade_name',
      'legal_name',
      'timezone',
      'locale',
      'institution_type_id',
      'address',
      'slug',
    });
    expect(payload['slug'], 'aurora');
    expect((jsonDecode(calls[1].body) as Map)['p_institution_id'], 'institution-9');
    expect(saved.id, 'institution-9');
    expect(saved.version, 1);
  });

  test('omits a blank address on create and sends a typed type by name', () async {
    final calls = <Request>[];
    final repository = _repository((request) async {
      calls.add(request);
      if (request.url.pathSegments.contains('superadmin_institution_create_v2')) {
        return _json(request, _ok({'institution_id': 'institution-9', 'management_version': 1}));
      }
      return _json(request, _ok({..._detailRow(version: 1), 'id': 'institution-9'}));
    });
    final blankAddress = _draft().copyWith(
      slug: 'aurora',
      postalCode: '',
      state: '',
      city: '',
      district: '',
      street: '',
      addressNumber: '',
      complement: '',
    );

    await repository.create(blankAddress);
    final payload = Map<String, dynamic>.from(
      (jsonDecode(calls[0].body) as Map)['p_payload'] as Map,
    );
    expect(payload.containsKey('address'), isFalse);

    calls.clear();
    // Tipo digitado no assistente: vai pelo nome (180360), nao pelo id local.
    await repository.create(
      _draft().copyWith(slug: 'aurora', typeId: 'local-type-creche', typeName: 'Creche'),
    );
    final typed = Map<String, dynamic>.from((jsonDecode(calls[0].body) as Map)['p_payload'] as Map);
    expect(typed.containsKey('institution_type_id'), isFalse);
    expect(typed['institution_type_name'], 'Creche');
  });

  test('maps v2 authorization errors on create and detail', () async {
    final repository = _repository((request) async {
      return _json(request, {
        'ok': false,
        'data': null,
        'error': {'code': 'SAI_PERMISSION_DENIED', 'message': 'Acesso não autorizado.'},
      });
    });

    await expectLater(
      repository.create(_draft().copyWith(slug: 'aurora')),
      throwsA(isA<InstitutionDirectoryUnauthorizedException>()),
    );
    await expectLater(
      repository.fetchById('institution-1'),
      throwsA(isA<InstitutionDirectoryUnauthorizedException>()),
    );
  });
}

SupabaseInstitutionDirectoryRepository _repository(Future<Response> Function(Request) handler) {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'publishable-key',
    httpClient: MockClient(handler),
  );
  addTearDown(client.dispose);
  return SupabaseInstitutionDirectoryRepository(client);
}

Response _json(Request request, Object? body) => Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
  request: request,
);

Map<String, Object?> _ok(Object? data) => {'ok': true, 'data': data, 'error': null};

Map<String, Object?> _directoryRow(String id) => {
  'id': id,
  'public_name': 'Instituição $id',
  'status': 'active',
  'units_count': 1,
  'groups_count': 2,
};

Map<String, Object?> _detailRow({int version = 7}) => {
  'id': 'institution-1',
  'public_name': 'Instituição Aurora',
  'status': 'active',
  'management_version': version,
  'institution_type': {'id': '11111111-1111-4111-8111-111111111111', 'name': 'Escola'},
  'address': {'country': 'Brasil', 'city': 'São Paulo', 'postal_code': '01310100'},
  'subscription': {'plan_code': 'essential', 'status': 'active'},
};

InstitutionRecord _draft() => InstitutionRecord.fromRpcPayload(_detailRow()).copyWith(
  tradeName: 'Aurora',
  legalName: 'Aurora LTDA',
  timezone: 'America/Sao_Paulo',
  locale: 'pt-BR',
  postalCode: '01310-100',
);
