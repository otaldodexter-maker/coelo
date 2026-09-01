import 'dart:convert';

import 'package:coelo_superadmin/features/units/data/supabase_unit_directory_repository.dart';
import 'package:coelo_superadmin/features/units/domain/unit_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
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
