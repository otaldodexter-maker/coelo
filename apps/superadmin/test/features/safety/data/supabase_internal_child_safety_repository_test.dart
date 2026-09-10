import 'dart:convert';

import 'package:coelo_superadmin/features/safety/data/supabase_internal_child_safety_repository.dart';
import 'package:coelo_superadmin/features/safety/domain/child_safety.dart';
import 'package:coelo_superadmin/features/safety/domain/child_safety_contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late List<Request> requests;
  late Object? response;
  late int status;
  late SupabaseClient client;
  late SupabaseInternalChildSafetyRepository repository;
  setUp(() {
    requests = [];
    response = _success(_directory);
    status = 200;
    client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return Response(
          jsonEncode(response),
          status,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    repository = SupabaseInternalChildSafetyRepository(client);
  });
  tearDown(() async {
    await client.dispose();
  });

  group('review regressions', () {
    for (final code in ['PGRST301', 'PGRST302']) {
      test('transport $code invalidates authorization', () async {
        status = 401;
        response = {'code': code, 'message': 'Synthetic auth failure'};
        await expectLater(
          repository.fetchChild('child-1'),
          throwsA(isA<ChildSafetyUnauthorizedException>()),
        );
      });
    }
    test('nested optional identifier has a typed decoding failure', () async {
      response = _success({
        ..._child,
        'contexts': [
          {..._context, 'unit_id': 7},
        ],
      });
      await expectLater(
        repository.fetchChild('child-1'),
        throwsA(isA<ChildSafetyUnavailableException>()),
      );
    });
    test('malformed nested search context cannot become an empty option', () async {
      response = _success([
        {
          'id': 'child-1',
          'display_name': 'Synthetic child',
          'contexts': [7],
        },
      ]);
      await expectLater(
        repository.searchChildren('synthetic'),
        throwsA(isA<ChildSafetyUnavailableException>()),
      );
    });
    test('malformed directory row cannot become an empty record', () async {
      response = _success({
        ..._directory,
        'items': [7],
      });
      await expectLater(
        repository.fetchDirectory(ChildSafetyDirectoryQuery()),
        throwsA(isA<ChildSafetyUnavailableException>()),
      );
    });
  });

  test('required context identity cannot collapse to missing scope', () async {
    response = _success([
      {
        'id': 'child-1',
        'display_name': 'Synthetic child',
        'contexts': [<String, Object?>{}],
      },
    ]);
    await expectLater(
      repository.searchChildren('synthetic'),
      throwsA(isA<ChildSafetyUnavailableException>()),
    );
    response = _success({
      ..._directory,
      'items': [
        {..._child, ..._context, 'child_id': ''},
      ],
    });
    await expectLater(
      repository.fetchDirectory(ChildSafetyDirectoryQuery()),
      throwsA(isA<ChildSafetyUnavailableException>()),
    );
    response = _success({
      ..._directory,
      'items': [_child],
    });
    await expectLater(
      repository.fetchDirectory(ChildSafetyDirectoryQuery()),
      throwsA(isA<ChildSafetyUnavailableException>()),
    );
  });

  test('directory uses v2 parameters and retains counts while writes stay disabled', () async {
    final cursor = {'name': 'synthetic', 'child_context_id': 'context-1', 'unit_id': 'unit-1'};
    final page = await repository.fetchDirectory(
      ChildSafetyDirectoryQuery(
        search: '  synthetic  ',
        institutionIds: {'institution-1'},
        unitIds: {'unit-1'},
        segment: ChildSafetyDirectorySegment.attention,
        cursor: jsonEncode(cursor),
      ),
    );
    expect(requests.single.url.pathSegments.last, 'superadmin_child_safety_directory_v2');
    expect(jsonDecode(requests.single.body), {
      'p_search': 'synthetic',
      'p_institution_ids': ['institution-1'],
      'p_unit_ids': ['unit-1'],
      'p_segment': 'attention',
      'p_limit': 11,
      'p_cursor': cursor,
    });
    expect(page.totalCount, 1);
    expect(page.records.single.childId, 'child-1');
    expect(page.segmentCounts.attention, 1);
    expect(page.canCreate, isFalse);
    expect(jsonDecode(page.nextCursor!), cursor);
  });

  test('child detail uses v2 and decodes the requested record', () async {
    response = _success(_child);
    final child = await repository.fetchChild('child-1');
    expect(requests.single.url.pathSegments.last, 'superadmin_child_safety_get_v2');
    expect(jsonDecode(requests.single.body), {'p_child_id': 'child-1'});
    expect(child!.childId, 'child-1');
    expect(child.childName, 'Synthetic child');
  });

  test('missing authorizations cannot imply an empty safety record', () async {
    response = _success({..._child}..remove('authorizations'));
    await expectLater(
      repository.fetchChild('child-1'),
      throwsA(isA<ChildSafetyUnavailableException>()),
    );
  });

  test('nominal authorizations retain identity and visible names', () async {
    response = _success({
      ..._child,
      'authorizations': [
        {
          'id': 'authorization-1',
          'child_context_id': 'context-1',
          'unit_id': 'unit-1',
          'name': 'Synthetic adult',
          'relationship_code': 'other',
          'decision_status': 'approved',
          'lifecycle_status': 'active',
          'capability_codes': ['pickup'],
          'version': 1,
        },
      ],
    });
    final child = await repository.fetchChild('child-1');
    expect(child!.authorizations.single.id, 'authorization-1');
    expect(child.authorizations.single.name, 'Synthetic adult');
    expect(child.authorizations.single.unitName, 'Synthetic unit');
  });

  for (final value in <Object?>[
    null,
    {},
    [null],
    ['invalid'],
    [<String, Object?>{}],
  ]) {
    test('malformed authorizations ${jsonEncode(value)} fail closed', () async {
      response = _success({..._child, 'authorizations': value});
      await expectLater(
        repository.fetchChild('child-1'),
        throwsA(isA<ChildSafetyUnavailableException>()),
      );
    });
  }

  test('child search uses v2 and preserves limit and selected context', () async {
    response = _success([
      {
        'id': 'child-1',
        'display_name': 'Synthetic child',
        'contexts': [_context],
      },
    ]);
    final options = await repository.searchChildren('  synthetic  ', limit: 7);
    expect(requests.single.url.pathSegments.last, 'superadmin_child_safety_search_children_v2');
    expect(jsonDecode(requests.single.body), {'p_search': 'synthetic', 'p_limit': 7});
    expect(options.single.childContextId, 'context-1');
  });

  test('valid empty search result remains empty', () async {
    response = _success([]);
    expect(await repository.searchChildren('synthetic'), isEmpty);
  });

  for (final code in [
    'SAI_AUTH_REQUIRED',
    'SAI_SESSION_INVALID',
    'SAI_INTERNAL_CONTEXT_DENIED',
    'SAI_MEMBERSHIP_SUSPENDED',
    'SAI_MEMBERSHIP_REVOKED',
    'SAI_PERMISSION_DENIED',
  ]) {
    test('HTTP 200 denial $code is typed and never decoded as data', () async {
      response = {
        'ok': false,
        'data': _directory,
        'error': {'code': code},
      };
      await expectLater(
        repository.fetchDirectory(ChildSafetyDirectoryQuery()),
        throwsA(isA<ChildSafetyUnauthorizedException>()),
      );
      expect(requests, hasLength(1));
    });
  }
  for (final entry in <String, Matcher>{
    'SAI_INVALID_ARGUMENT': isA<ChildSafetyValidationException>(),
    'SAI_CONCURRENT_CHANGE': isA<ChildSafetyConflictException>(),
    'SAI_INTERNAL_ERROR': isA<ChildSafetyUnavailableException>(),
    'unknown': isA<ChildSafetyUnavailableException>(),
  }.entries) {
    test('business error ${entry.key} is mapped without exposing message', () async {
      response = {
        'ok': false,
        'data': null,
        'error': {'code': entry.key, 'message': 'internal detail'},
      };
      await expectLater(repository.fetchChild('child-1'), throwsA(entry.value));
    });
  }
  for (final payload in <Object?>[
    null,
    <Object?>[],
    <String, Object?>{},
    {'ok': 'true', 'data': <Object?>[]},
    {'ok': true, 'data': null, 'error': null},
    {
      'ok': true,
      'data': <Object?>[],
      'error': {'code': 'unknown'},
    },
    {'ok': false, 'data': <Object?>[], 'error': null},
  ]) {
    test('malformed envelope ${jsonEncode(payload)} fails closed', () async {
      response = payload;
      await expectLater(
        repository.searchChildren('synthetic'),
        throwsA(isA<ChildSafetyUnavailableException>()),
      );
    });
  }
  test('wrong success shape is not converted into an empty search', () async {
    response = _success({});
    await expectLater(
      repository.searchChildren('synthetic'),
      throwsA(isA<ChildSafetyUnavailableException>()),
    );
  });
  test('wrong success shape is not converted into an empty directory', () async {
    response = _success([]);
    await expectLater(
      repository.fetchDirectory(ChildSafetyDirectoryQuery()),
      throwsA(isA<ChildSafetyUnavailableException>()),
    );
  });
  test('different child response cannot be attributed to requested child', () async {
    response = _success({..._child, 'child_id': 'other-child'});
    await expectLater(
      repository.fetchChild('child-1'),
      throwsA(isA<ChildSafetyUnavailableException>()),
    );
  });
  test('invalid cursor fails before any HTTP call', () async {
    await expectLater(
      repository.fetchDirectory(ChildSafetyDirectoryQuery(cursor: '{')),
      throwsA(isA<ChildSafetyValidationException>()),
    );
    expect(requests, isEmpty);
  });
  test('transport authorization denial is typed', () async {
    status = 403;
    response = {'code': '42501', 'message': 'permission denied'};
    await expectLater(
      repository.fetchChild('child-1'),
      throwsA(isA<ChildSafetyUnauthorizedException>()),
    );
  });
  test('RPC unavailable never falls back to legacy', () async {
    status = 404;
    response = {'code': 'PGRST202', 'message': 'function unavailable'};
    await expectLater(
      repository.fetchChild('child-1'),
      throwsA(isA<ChildSafetyUnavailableException>()),
    );
    expect(requests, hasLength(1));
    expect(requests.single.url.pathSegments.last, 'superadmin_child_safety_get_v2');
  });
  test('all unsupported commands fail without HTTP or legacy fallback', () async {
    await expectLater(
      repository.saveAuthorization(
        const SavePickupAuthorizationCommand(
          requestId: 'request-1',
          childId: 'child-1',
          childContextId: 'context-1',
          unitId: 'unit-1',
          personId: 'adult-1',
          relationshipCode: 'other',
          capabilityCodes: {'pickup'},
          requestReason: 'Synthetic reason',
        ),
      ),
      throwsA(isA<ChildSafetyUnavailableException>()),
    );
    await expectLater(
      repository.transitionAuthorization(
        const TransitionPickupAuthorizationCommand(
          requestId: 'request-2',
          childId: 'child-1',
          authorizationId: 'authorization-1',
          status: PickupAuthorizationStatus.approved,
          reason: 'Synthetic reason',
        ),
      ),
      throwsA(isA<ChildSafetyUnavailableException>()),
    );
    await expectLater(
      repository.suspendAuthorization(
        const SuspendPickupAuthorizationCommand(
          requestId: 'request-3',
          childId: 'child-1',
          authorizationId: 'authorization-1',
          reason: 'Synthetic reason',
        ),
      ),
      throwsA(isA<ChildSafetyUnavailableException>()),
    );
    await expectLater(
      repository.requestExport(const ChildSafetyExportCommand(requestId: 'request-4')),
      throwsA(isA<ChildSafetyUnavailableException>()),
    );
    expect(requests, isEmpty);
  });
}

Object _success(Object? data) => {'ok': true, 'data': data, 'error': null};
const _context = {
  'child_context_id': 'context-1',
  'institution_id': 'institution-1',
  'institution_name': 'Synthetic institution',
  'unit_id': 'unit-1',
  'unit_name': 'Synthetic unit',
};
const _child = {
  'child_id': 'child-1',
  'child_name': 'Synthetic child',
  'contexts': [_context],
  'authorizations': <Object?>[],
};
const _directory = {
  'items': [
    {..._child, ..._context},
  ],
  'total_count': 1,
  'segment_counts': {'attention': 1, 'all': 1},
  'can_create': true,
  'next_cursor': {'name': 'synthetic', 'child_context_id': 'context-1', 'unit_id': 'unit-1'},
};
