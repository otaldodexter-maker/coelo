import 'dart:convert';

import 'package:coelo_superadmin/features/units/data/supabase_structure_handle_availability.dart';
import 'package:coelo_superadmin/features/units/domain/unit_handle_availability.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  SupabaseStructureHandleAvailability checker(Future<Response> Function(Request) handler) {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient(handler),
    );
    addTearDown(client.dispose);
    return SupabaseStructureHandleAvailability(client);
  }

  Response json(Request request, Object? body) => Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json'},
    request: request,
  );

  test('calls superadmin_structure_handle_availability_v1 and maps the envelope', () async {
    Map<String, Object?>? params;
    final availability = checker((request) async {
      expect(request.url.pathSegments.last, 'superadmin_structure_handle_availability_v1');
      params = Map<String, Object?>.from(jsonDecode(request.body) as Map);
      return json(request, {
        'ok': true,
        'data': {'kind': 'unit', 'normalized': 'centro.escola', 'available': true, 'reason': null},
        'error': null,
      });
    });
    final result = await availability.check('unit', '@Centro.Escola', excludeId: 'u-1');
    expect(params, {'p_kind': 'unit', 'p_handle': '@Centro.Escola', 'p_exclude_id': 'u-1'});
    expect(result.reason, UnitHandleAvailabilityReason.available);
    expect(result.normalized, 'centro.escola');
  });

  for (final (reason, expected) in [
    ('HANDLE_TAKEN', UnitHandleAvailabilityReason.taken),
    ('HANDLE_INVALID', UnitHandleAvailabilityReason.invalid),
    ('HANDLE_EMPTY', UnitHandleAvailabilityReason.empty),
  ]) {
    test('maps $reason', () async {
      final availability = checker(
        (request) async => json(request, {
          'ok': true,
          'data': {'kind': 'unit', 'normalized': 'x', 'available': false, 'reason': reason},
          'error': null,
        }),
      );
      expect((await availability.check('unit', 'x')).reason, expected);
    });
  }

  test('denied envelope and transport failure become unavailable, never throw', () async {
    final denied = checker(
      (request) async => json(request, {
        'ok': false,
        'data': null,
        'error': {'code': 'SAI_PERMISSION_DENIED', 'message': 'x', 'http_status': 403},
      }),
    );
    expect((await denied.check('unit', 'x')).reason, UnitHandleAvailabilityReason.unavailable);
    final offline = checker((_) async => throw ClientException('offline'));
    expect((await offline.check('unit', 'x')).reason, UnitHandleAvailabilityReason.unavailable);
  });
}
