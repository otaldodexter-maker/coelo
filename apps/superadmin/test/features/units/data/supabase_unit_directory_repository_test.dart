import 'dart:convert';

import 'package:coelo_superadmin/features/units/data/supabase_unit_directory_repository.dart';
import 'package:coelo_superadmin/features/units/data/unavailable_unit_composition.dart';
import 'package:coelo_superadmin/features/units/domain/unit_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('unit create intent reuses receipt after committed response is lost', () async {
    final requests = <String>[];
    final receipts = <String>{};
    var loseResponse = true;
    final client = _client((request) async {
      if (request.url.path.endsWith('/list_units_for_superadmin')) {
        return _json({
          'items': [_unitRow()],
          'total_count': 1,
        }, request);
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final id = body['p_request_id'] as String;
      requests.add(id);
      receipts.add(id);
      if (loseResponse) {
        loseResponse = false;
        throw ClientException('response lost after commit');
      }
      return _json({..._unitRow(), 'management_version': 1}, request);
    });
    addTearDown(client.dispose);
    final repo = SupabaseUnitDirectoryRepository(client);
    final record = (await repo.fetchPage(
      UnitDirectoryQuery(),
    )).items.single.record.copyWith(managementVersion: 0);
    await expectLater(repo.upsert(record), throwsA(isA<UnavailableUnitDirectoryException>()));
    await repo.upsert(record);
    expect(requests, hasLength(2));
    expect(receipts, hasLength(1));
    await repo.upsert(record);
    expect(receipts, hasLength(2), reason: 'confirmed intent is cleared');
  });
  test('unit create intent changes with payload and separates independent drafts', () async {
    final requests = <String>[];
    final client = _client((request) async {
      if (request.url.path.endsWith('/list_units_for_superadmin')) {
        return _json({
          'items': [_unitRow()],
          'total_count': 1,
        }, request);
      }
      requests.add((jsonDecode(request.body) as Map<String, dynamic>)['p_request_id'] as String);
      throw ClientException('ambiguous');
    });
    addTearDown(client.dispose);
    final repo = SupabaseUnitDirectoryRepository(client);
    final record = (await repo.fetchPage(
      UnitDirectoryQuery(),
    )).items.single.record.copyWith(managementVersion: 0);
    for (final draft in [
      record,
      record.copyWith(name: 'Changed'),
      record.copyWith(id: 'other-draft'),
    ]) {
      await expectLater(repo.upsert(draft), throwsA(isA<UnavailableUnitDirectoryException>()));
    }
    expect(requests.toSet(), hasLength(3));
  });
  test('uses the protected unit directory RPC with server pagination and search', () async {
    Request? captured;
    final client = _client((request) async {
      captured = request;
      return _json({
        'items': [_unitRow()],
        'total_count': 1,
      }, request);
    });
    addTearDown(client.dispose);

    final page = await SupabaseUnitDirectoryRepository(
      client,
    ).fetchPage(UnitDirectoryQuery(search: 'centro', page: 2, pageSize: 20));

    expect(captured!.url.path, endsWith('/rpc/list_units_for_superadmin'));
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['p_search'], 'centro');
    expect(body['p_offset'], 40);
    expect(body['p_limit'], 20);
    expect(page.totalCount, 1);
    expect(page.items.single.name, 'Unidade Centro');
    expect(page.items.single.record.managementVersion, 4);
  });

  test('loads form context and maps the remote unit aggregate', () async {
    final client = _client(
      (request) async => _json({
        'unit': _unitRow(),
        'not_found': false,
        'institutions': [
          {
            'institution_id': '11111111-1111-4111-8111-111111111111',
            'institution_name': 'Casa Nuvem',
            'institution_type': {'id': 'type-1', 'label': 'Escola'},
            'effective_plan': {'id': 'plan-1', 'code': 'essential', 'label': 'Essencial'},
          },
        ],
      }, request),
    );
    addTearDown(client.dispose);

    final form = await SupabaseUnitDirectoryRepository(
      client,
    ).loadForm(unitId: '22222222-2222-4222-8222-222222222222');

    expect(form.institutions.single.publicName, 'Casa Nuvem');
    expect(form.record!.city, 'Salvador');
    expect(form.record!.contactEmail, 'centro@coelo.me');
  });

  test('handle publico vem de public_profile e nunca sai no payload', () async {
    // create_unit_for_superadmin deriva o handle no servidor (letras e numeros
    // do slug mais sufixo do id) quando o payload nao traz 'handle', e
    // update_unit_for_superadmin rejeita a chave 'handle'. O cliente envia so o
    // slug, como digitado (com hifens), e le o handle final para exibir.
    Request? captured;
    final unit = {
      ..._unitRow(),
      'slug': 'unidade-centro-r04',
      'public_profile': {'handle': 'unidadecentror04_f5284f2f', 'discovery_enabled': false},
    };
    final client = _client((request) async {
      captured = request;
      if (request.url.path.endsWith('/update_unit_for_superadmin')) {
        return _json(unit, request);
      }
      return _json({
        'unit': unit,
        'not_found': false,
        'institutions': [
          {
            'institution_id': '11111111-1111-4111-8111-111111111111',
            'institution_name': 'Casa Nuvem',
            'institution_type': {'id': 'type-1', 'label': 'Escola'},
            'effective_plan': {'id': 'plan-1', 'code': 'essential', 'label': 'Essencial'},
          },
        ],
      }, request);
    });
    addTearDown(client.dispose);
    final repository = SupabaseUnitDirectoryRepository(client);

    final form = await repository.loadForm(unitId: '22222222-2222-4222-8222-222222222222');
    expect(form.record!.slug, 'unidade-centro-r04');
    expect(form.record!.handle, 'unidadecentror04_f5284f2f');

    await repository.upsert(form.record!);
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    final payload = body['p_payload'] as Map<String, dynamic>;
    expect(payload['slug'], 'unidade-centro-r04');
    expect(payload.containsKey('handle'), isFalse);
  });

  test('registro sem public_profile fica com handle vazio', () async {
    final client = _client(
      (request) async => _json({
        'items': [_unitRow()],
        'total_count': 1,
      }, request),
    );
    addTearDown(client.dispose);

    final page = await SupabaseUnitDirectoryRepository(client).fetchPage(UnitDirectoryQuery());

    expect(page.items.single.record.handle, isEmpty);
  });

  test('recibo de outra unidade na atualizacao nao entra no cache', () async {
    // Sem conferencia de identidade, uma resposta que nao corresponde a unidade
    // pedida entraria no cache como se fosse o registro salvo. O repositorio de
    // Instituicoes ja faz essa conferencia; este nao fazia.
    final client = _client((request) async {
      if (request.url.path.endsWith('/list_units_for_superadmin')) {
        return _json({
          'items': [_unitRow()],
          'total_count': 1,
        }, request);
      }
      final outra = Map<String, Object?>.from(_unitRow());
      outra['id'] = '33333333-3333-4333-8333-333333333333';
      return _json(outra, request);
    });
    addTearDown(client.dispose);
    final repository = SupabaseUnitDirectoryRepository(client);
    final page = await repository.fetchPage(UnitDirectoryQuery());

    await expectLater(
      repository.upsert(page.items.single.record),
      throwsA(isA<UnavailableUnitDirectoryException>()),
    );
  });

  test('updates through the authoritative RPC with optimistic version', () async {
    Request? captured;
    final client = _client((request) async {
      captured = request;
      return _json(
        request.url.path.endsWith('/list_units_for_superadmin')
            ? {
                'items': [_unitRow()],
                'total_count': 1,
              }
            : _unitRow(),
        request,
      );
    });
    addTearDown(client.dispose);
    final repository = SupabaseUnitDirectoryRepository(client);
    final page = await repository.fetchPage(UnitDirectoryQuery());

    await repository.upsert(page.items.single.record);

    expect(captured!.url.path, endsWith('/rpc/update_unit_for_superadmin'));
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['p_expected_version'], 4);
    expect(body['p_unit_id'], '22222222-2222-4222-8222-222222222222');
  });

  test('RPC inexistente no banco vira indisponibilidade, nao excecao crua', () async {
    // As cinco RPCs do diretorio de Unidades nao sao criadas por nenhum arquivo de
    // packages/coelo_database, medido em 2026-09-10 e fixado por
    // test/contracts/rpc_contract_test.dart. Enquanto a bifurcacao estiver aberta
    // — instaladas fora do versionamento, ou inexistentes — importa saber o que o
    // cliente faz se elas NAO existirem. O PostgREST responde 404 com PGRST202
    // quando nao encontra a funcao, e este teste prova que o repositorio fecha:
    // _mapError manda qualquer codigo que nao seja de autorizacao para
    // indisponibilidade, entao a tela mostra indisponibilidade honesta em vez de
    // receber excecao crua. O custo e que PGRST202 chega ao usuario com a mesma
    // aparencia de queda de rede, e e por isso que a pergunta de catalogo precisa
    // ser respondida em vez de esperada.
    final client = _client(
      (request) async => Response(
        jsonEncode({
          'code': 'PGRST202',
          'message': 'Could not find the function public.list_units_for_superadmin',
          'hint': null,
          'details': null,
        }),
        404,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    );
    addTearDown(client.dispose);
    final repo = SupabaseUnitDirectoryRepository(client);

    await expectLater(
      repo.fetchPage(UnitDirectoryQuery()),
      throwsA(isA<UnavailableUnitDirectoryException>()),
    );
    await expectLater(repo.loadForm(), throwsA(isA<UnavailableUnitDirectoryException>()));
    await expectLater(repo.fetchFilterOptions(), throwsA(isA<UnavailableUnitDirectoryException>()));
    // E o que importa para quem le o erro: nao e negacao de autorizacao, entao a
    // tela nao pode dizer ao usuario que ele nao tem permissao.
    await expectLater(
      repo.fetchPage(UnitDirectoryQuery()),
      throwsA(isNot(isA<UnitDirectoryUnauthorizedException>())),
    );

    // Controle positivo no mesmo teste, senao "tudo vira indisponibilidade"
    // passaria tambem: com 42501 o mesmo repositorio distingue e devolve negacao.
    final denied = _client(
      (request) async => Response(
        jsonEncode({'code': '42501', 'message': 'permission denied'}),
        403,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    );
    addTearDown(denied.dispose);
    await expectLater(
      SupabaseUnitDirectoryRepository(denied).fetchPage(UnitDirectoryQuery()),
      throwsA(isA<UnitDirectoryUnauthorizedException>()),
    );
  });
}

Map<String, Object?> _unitRow() => {
  'id': '22222222-2222-4222-8222-222222222222',
  'institution_id': '11111111-1111-4111-8111-111111111111',
  'institution_name': 'Casa Nuvem',
  'name': 'Unidade Centro',
  'slug': 'unidade-centro',
  'unit_status': 'active',
  'unit_type': {'id': 'type-1', 'label': 'Escola'},
  'address': {'country': 'BR', 'state': 'BA', 'city': 'Salvador'},
  'contact': {'email': 'centro@coelo.me'},
  'branding': {'display_name': 'Centro', 'inherit_institution_branding': true},
  'effective_plan': {'id': 'plan-1', 'code': 'essential', 'label': 'Essencial', 'inherited': true},
  'groups_count': 3,
  'activities_count': 2,
  'management_version': 4,
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
