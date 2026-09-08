import 'dart:convert';
import 'dart:io';

import 'package:coelo_superadmin/features/units/data/supabase_unit_directory_repository.dart';
import 'package:coelo_superadmin/features/units/domain/unit_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// `units.status` is not absent. It has no control and no function, and it
/// travels anyway.
///
/// I had recorded it as "no activate, deactivate or archive action anywhere,
/// and no transition RPC". The first half is right: the commands gateway
/// declares thirteen methods and none of them is a transition, and the screen
/// offers nothing. The second half missed something - the generic unit save
/// carries `unit_status` in its payload, so a status change rides along with an
/// ordinary edit.
///
/// Where it rides to is nowhere: `update_unit_for_superadmin` and
/// `create_unit_for_superadmin` have no definition in this repository, which is
/// the OQ-032 hole. And production never gets that far, because
/// `structureMutationsEnabled` is false and the router refuses the location
/// before the screen is built.
///
/// Three fences, then, and the middle one is the one I had wrong.
const _migration = '../../packages/coelo_database/migrations';
const _gateway = 'lib/features/units/domain/unit_backend_commands.dart';

Map<String, Object?> _unitRow({String status = 'archived'}) => {
  'id': '22222222-2222-4222-8222-222222222222',
  'institution_id': '11111111-1111-4111-8111-111111111111',
  'institution_name': 'Casa Nuvem',
  'name': 'Unidade Centro',
  'slug': 'unidade-centro',
  'unit_status': status,
  'unit_type': {'id': 'type-1', 'label': 'Escola'},
  'address': {'country': 'BR', 'state': 'BA', 'city': 'Salvador'},
  'contact': {'email': 'centro@coelo.me'},
  'branding': {'display_name': 'Centro', 'inherit_institution_branding': true},
  'effective_plan': {'id': 'plan-1', 'code': 'essential', 'label': 'Essencial', 'inherited': true},
  'groups_count': 3,
  'activities_count': 2,
  'management_version': 4,
};

void main() {
  test('the ordinary save carries the status, so an edit is a transition', () async {
    Request? captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        final body = request.url.path.endsWith('/list_units_for_superadmin')
            ? {
                'items': [_unitRow()],
                'total_count': 1,
              }
            : _unitRow();
        if (!request.url.path.endsWith('/list_units_for_superadmin')) captured = request;
        return Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final repository = SupabaseUnitDirectoryRepository(client);
    final page = await repository.fetchPage(UnitDirectoryQuery());
    await repository.upsert(page.items.single.record);

    final params = jsonDecode(captured!.body) as Map<String, dynamic>;
    final payload = (params['p_payload'] as Map).cast<String, Object?>();
    expect(
      payload['unit_status'],
      'archived',
      reason: 'the status is part of the save, not a separate act; a form that '
          'lets it be edited is a transition control whether or not it looks like one',
    );
    expect(params['p_expected_version'], 4);
  });

  test('the commands gateway offers no transition of its own', () {
    // The interface is the contract: if a transition is ever added, it has to
    // pass through here, and this list has to change with it.
    final source = File(_gateway).readAsStringSync();
    final start = source.indexOf('abstract interface class UnitBackendCommandsGateway {');
    expect(start, isNot(-1));
    final body = source.substring(start, source.indexOf('\n}', start));
    final methods = RegExp(r'\b([a-z][A-Za-z]+)\(').allMatches(body).map((m) => m.group(1)!).toSet();

    for (final verb in ['archive', 'activate', 'deactivate', 'suspend', 'setStatus', 'status']) {
      expect(
        methods.where((method) => method.toLowerCase().contains(verb.toLowerCase())),
        isEmpty,
        reason: 'a $verb command appeared; units.status is no longer only a payload field',
      );
    }
    expect(methods, contains('transferInstitution'), reason: 'the gateway was found and read');
  });

  test('the save it rides on has no function to land on', () {
    // Same hole as the rest of Unidades. Named here so the status question is
    // not read as a separate gap.
    final defined = <String>{};
    for (final file in Directory(_migration).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.sql')) continue;
      for (final match in RegExp(
        r'create (?:or replace )?function\s+(?:public|app_private)\.([a-z0-9_]+)\s*\(',
      ).allMatches(file.readAsStringSync())) {
        defined.add(match.group(1)!);
      }
    }
    expect(defined, isNot(contains('update_unit_for_superadmin')));
    expect(defined, isNot(contains('create_unit_for_superadmin')));
    expect(defined.length, greaterThan(100), reason: 'the migrations were actually read');
  });
}
