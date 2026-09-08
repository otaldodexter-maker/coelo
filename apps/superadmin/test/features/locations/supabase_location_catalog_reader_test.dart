import 'dart:async';
import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/locations/data/supabase_location_catalog_reader.dart';
import 'package:coelo_superadmin/features/locations/domain/location_catalog_reader.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_directory_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const institution = '10000000-0000-0000-0000-000000000001';
const otherInstitution = '10000000-0000-0000-0000-000000000002';
const unit = '20000000-0000-0000-0000-000000000001';
const location = '30000000-0000-0000-0000-000000000001';
final scope = LocationScope.institution(institutionId: institution);

Map<String, Object?> entry({String owner = institution, String? unitId}) => {
  'id': location,
  'scope_kind': unitId == null ? 'institution' : 'unit',
  'institution_id': owner,
  'unit_id': unitId,
  'name': 'Sala',
  'description': null,
  'kind': 'internal',
  'floor': null,
  'address': null,
  'visibility': 'team',
  'status': 'active',
  'management_version': 1,
  'created_at': '2026-09-08T00:00:00Z',
  'updated_at': '2026-09-08T00:00:00Z',
};
Map<String, Object?> ok(Object? data) => {'ok': true, 'data': data, 'error': null};
Map<String, Object?> page({String owner = institution, String? unitId}) => ok({
  'items': [entry(owner: owner, unitId: unitId)],
  'total_count': 1,
});
Map<String, Object?> denial(String code) => {
  'ok': false,
  'data': null,
  'error': {
    'code': code,
    'message': 'RAW PRIVATE ERROR',
    'correlation_id': location,
    'http_status': 403,
  },
};

void main() {
  test('maximum codepoint search and offset are preserved without unicode trim', () async {
    final query = '\u00a0${'😀' * 118}\u00a0';
    final reader = SupabaseLocationCatalogReader.withRpc((_, params) async {
      expect(params['p_search'], query);
      expect(params['p_offset'], 10000);
      expect(params['p_limit'], 100);
      return ok({'items': <Object?>[], 'total_count': 0});
    });
    await reader.fetchDirectory(
      LocationDirectoryRequest(scope: scope, search: query, limit: 100, offset: 10000),
    );
  });
  test('page exceeding requested size is unavailable', () async {
    final reader = SupabaseLocationCatalogReader.withRpc(
      (_, _) async => ok({
        'items': [
          entry(),
          {...entry(), 'id': unit},
        ],
        'total_count': 2,
      }),
    );
    await expectLater(
      reader.fetchDirectory(LocationDirectoryRequest(scope: scope, limit: 1)),
      throwsA(isA<LocationCatalogUnavailableException>()),
    );
  });
  test('non-authorization Postgrest error does not expose details', () async {
    final reader = SupabaseLocationCatalogReader.withRpc(
      (_, _) async =>
          throw const PostgrestException(message: 'RAW SQL', details: 'PRIVATE', code: 'XX000'),
    );
    await expectLater(
      reader.fetchDetail(location),
      throwsA(isA<LocationCatalogUnavailableException>()),
    );
  });
  test('same owner revision ignores late denied envelope after new success', () async {
    final replies = <Completer<Object?>>[];
    final reader = SupabaseLocationCatalogReader.withRpc((_, _) {
      final reply = Completer<Object?>();
      replies.add(reply);
      return reply.future;
    });
    final controller = LocationDirectoryController(
      reader: reader,
      scope: scope,
      sessionAvailable: true,
    );
    final old = controller.load();
    final newer = controller.load(contextRevision: 1);
    replies.last.complete(page());
    await newer;
    replies.first.complete(denial('SAI_MEMBERSHIP_REVOKED'));
    await old;
    expect(controller.state, LocationReadState.ready);
    expect(controller.data!.items.single.id, location);
    controller.dispose();
  });
  test('current revoked envelope removes previously loaded data', () async {
    var calls = 0;
    final reader = SupabaseLocationCatalogReader.withRpc(
      (_, _) async => calls++ == 0 ? page() : denial('SAI_MEMBERSHIP_REVOKED'),
    );
    final controller = LocationDirectoryController(
      reader: reader,
      scope: scope,
      sessionAvailable: true,
    );
    await controller.load();
    expect(controller.data, isNotNull);
    await controller.load();
    expect(controller.state, LocationReadState.denied);
    expect(controller.data, isNull);
    controller.dispose();
  });
  test('institution directory sends exact six parameters with independent owner', () async {
    final reader = SupabaseLocationCatalogReader.withRpc((name, params) async {
      expect(name, 'superadmin_location_directory_v2');
      expect(params, {
        'p_scope_kind': 'institution',
        'p_institution_id': institution,
        'p_unit_id': null,
        'p_search': 'Sala',
        'p_limit': 20,
        'p_offset': 40,
      });
      return page();
    });
    final result = await reader.fetchDirectory(
      LocationDirectoryRequest(scope: scope, search: '  Sala  ', limit: 20, offset: 40),
    );
    expect(result.items.single.id, location);
  });
  test('unit directory preserves real unit and institution without inheritance', () async {
    final reader = SupabaseLocationCatalogReader.withRpc((name, params) async {
      expect(params['p_scope_kind'], 'unit');
      expect(params['p_unit_id'], unit);
      expect(params['p_institution_id'], institution);
      expect(params['p_search'], isNull);
      expect(params['p_limit'], 11);
      return page(unitId: unit);
    });
    await reader.fetchDirectory(
      LocationDirectoryRequest(
        scope: LocationScope.unit(institutionId: institution, unitId: unit),
        search: '   ',
      ),
    );
  });
  test('detail sends only nominal ID and uses strict DTO', () async {
    final reader = SupabaseLocationCatalogReader.withRpc((name, params) async {
      expect(name, 'superadmin_location_detail_v2');
      expect(params, {'p_location_id': location});
      return ok(entry());
    });
    expect((await reader.fetchDetail(location)).name, 'Sala');
  });
  for (final code in [
    'SAI_AUTH_REQUIRED',
    'SAI_SESSION_INVALID',
    'SAI_INTERNAL_CONTEXT_DENIED',
    'SAI_MEMBERSHIP_SUSPENDED',
    'SAI_MEMBERSHIP_REVOKED',
    'SAI_PERMISSION_DENIED',
    'SAI_MFA_REQUIRED',
  ]) {
    test('both readers map $code to safe denied exception', () async {
      final reader = SupabaseLocationCatalogReader.withRpc((_, _) async => denial(code));
      await expectLater(
        reader.fetchDetail(location),
        throwsA(isA<LocationCatalogAccessDeniedException>()),
      );
      await expectLater(
        reader.fetchDirectory(LocationDirectoryRequest(scope: scope)),
        throwsA(isA<LocationCatalogAccessDeniedException>()),
      );
    });
  }
  for (final code in ['42501', 'PGRST301', 'PGRST302']) {
    test('Postgrest $code is denied without exposing raw error', () async {
      final reader = SupabaseLocationCatalogReader.withRpc(
        (_, _) async => throw PostgrestException(message: 'RAW PRIVATE ERROR', code: code),
      );
      await expectLater(
        reader.fetchDetail(location),
        throwsA(isA<LocationCatalogAccessDeniedException>()),
      );
    });
  }
  for (final value in [
    null,
    <String, Object?>{},
    {'ok': true, 'data': <String, Object?>{}, 'error': null},
    denial('SAI_INTERNAL_ERROR'),
  ]) {
    test('invalid or non-auth envelope is safely unavailable $value', () async {
      final reader = SupabaseLocationCatalogReader.withRpc((_, _) async => value);
      await expectLater(
        reader.fetchDetail(location),
        throwsA(isA<LocationCatalogUnavailableException>()),
      );
    });
  }
  test('raw transport errors are not retained in safe exception', () async {
    final reader = SupabaseLocationCatalogReader.withRpc(
      (_, _) async => throw StateError('RAW PRIVATE ERROR'),
    );
    try {
      await reader.fetchDetail(location);
      fail('must reject');
    } on LocationCatalogUnavailableException catch (error) {
      expect(error.toString(), isNot(contains('RAW PRIVATE ERROR')));
    }
  });
  test('mismatched owner or detail ID is unavailable', () async {
    final reader = SupabaseLocationCatalogReader.withRpc(
      (name, _) async =>
          name.contains('directory') ? page(owner: otherInstitution) : ok({...entry(), 'id': unit}),
    );
    await expectLater(
      reader.fetchDetail(location),
      throwsA(isA<LocationCatalogUnavailableException>()),
    );
    await expectLater(
      reader.fetchDirectory(LocationDirectoryRequest(scope: scope)),
      throwsA(isA<LocationCatalogUnavailableException>()),
    );
  });
  test('invalid request fields never invoke transport', () async {
    var calls = 0;
    final reader = SupabaseLocationCatalogReader.withRpc((_, _) async {
      calls++;
      return page();
    });
    for (final request in [
      LocationDirectoryRequest(scope: scope, limit: 0),
      LocationDirectoryRequest(scope: scope, limit: 101),
      LocationDirectoryRequest(scope: scope, offset: -1),
      LocationDirectoryRequest(scope: scope, offset: 10001),
      LocationDirectoryRequest(scope: scope, search: 'x' * 121),
      LocationDirectoryRequest(scope: scope, search: 'bad\nquery'),
      LocationDirectoryRequest(scope: scope, search: String.fromCharCode(0xd800)),
      LocationDirectoryRequest(scope: LocationScope.institution(institutionId: 'invalid')),
    ]) {
      await expectLater(
        reader.fetchDirectory(request),
        throwsA(isA<LocationCatalogUnavailableException>()),
      );
    }
    await expectLater(
      reader.fetchDetail('invalid'),
      throwsA(isA<LocationCatalogUnavailableException>()),
    );
    expect(calls, 0);
  });
  test('controller discards old adapter result after scope replacement', () async {
    final replies = <Completer<Object?>>[];
    final reader = SupabaseLocationCatalogReader.withRpc((_, _) {
      final reply = Completer<Object?>();
      replies.add(reply);
      return reply.future;
    });
    final controller = LocationDirectoryController(
      reader: reader,
      scope: scope,
      sessionAvailable: true,
    );
    final old = controller.load();
    final current = controller.load(
      scope: LocationScope.institution(institutionId: otherInstitution),
    );
    replies.last.complete(page(owner: otherInstitution));
    await current;
    replies.first.complete(page());
    await old;
    expect(controller.data!.items.single.scope.institutionId, otherInstitution);
    controller.dispose();
  });
  test('session loss clears adapter result and ignores late success', () async {
    final reply = Completer<Object?>();
    var calls = 0;
    final reader = SupabaseLocationCatalogReader.withRpc((_, _) {
      calls++;
      return reply.future;
    });
    final controller = LocationDirectoryController(
      reader: reader,
      scope: scope,
      sessionAvailable: true,
    );
    final old = controller.load();
    await controller.load(sessionAvailable: false);
    reply.complete(page());
    await old;
    expect(controller.state, LocationReadState.denied);
    expect(controller.data, isNull);
    expect(calls, 1);
    controller.dispose();
  });
}
