import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/features/forms/data/forms_backend_gateway.dart';
import 'package:coelo_superadmin/features/forms/data/supabase_superadmin_forms_directory_reader.dart';
import 'package:flutter_test/flutter_test.dart';

const _id = 'e0000000-0000-4000-8000-000000000001';
const _institution = 'e0000000-0000-4000-8000-000000000002';
const _stamp = '2026-09-07T12:30:00.123456+00:00';

Map<String, Object?> _item() => {
  'id': _id,
  'title': 'Pesquisa sintética',
  'kind': 'quick_poll',
  'status': 'published',
  'operational_status': 'active',
  'identity_mode': 'anonymous',
  'updated_at': _stamp,
  'management_version': 3,
};

Map<String, Object?> _success({bool more = false}) => {
  'ok': true,
  'data': {
    'items': [_item()],
    'has_more': more,
    'next_cursor': more ? {'updated_at': _stamp, 'id': _id} : null,
  },
  'error': null,
};

Matcher _failure(FormApiFailureKind kind) => isA<FormApiException>()
    .having((e) => e.kind, 'kind', kind)
    .having((e) => e.message, 'sanitized', isNot(contains('private-secret')))
    .having((e) => e.details, 'no backend details', isEmpty);

void main() {
  test('calls only the internal directory RPC and decodes its explicit projection', () async {
    final backend = _Backend(_success());
    final page = await SupabaseSuperadminFormsDirectoryReader(backend).listDirectory(
      FormDirectoryQuery(
        institutionId: _institution,
        search: r'100%_literal\',
        statuses: {FormStatus.published},
        operationalStatuses: {FormOperationalStatus.active},
        kinds: {FormKind.quickPoll},
        startsOnOrAfter: DateTime(2026, 9, 1),
        endsOnOrBefore: DateTime(2026, 9, 7),
      ),
    );
    expect(backend.names, ['superadmin_forms_directory_v2']);
    expect(backend.parameters, {
      'p_query': {
        'institution_id': _institution,
        'search': r'100%_literal\',
        'statuses': ['published'],
        'operational_statuses': ['active'],
        'kinds': ['quick_poll'],
        'starts_on_or_after': '2026-09-01',
        'ends_on_or_before': '2026-09-07',
        'cursor_updated_at': null,
        'cursor_id': null,
        'limit': 25,
      },
    });
    final item = page.items.single;
    expect(item.id, _id);
    expect(item.title, 'Pesquisa sintética');
    expect(item.kind, FormKind.quickPoll);
    expect(item.status, FormStatus.published);
    expect(item.operationalStatus, FormOperationalStatus.active);
    expect(item.identityMode, FormIdentityMode.anonymous);
    expect(item.managementVersion, 3);
    expect(item.updatedAt, DateTime.parse(_stamp));
    expect(page.nextCursor, isNull);
  });

  test(
    'round trips timestamp precision and UUID cursor without context or mutation calls',
    () async {
      final backend = _Backend(_success(more: true));
      final reader = SupabaseSuperadminFormsDirectoryReader(backend);
      final first = await reader.listDirectory(const FormDirectoryQuery(limit: 1));
      expect(
        const FormCursorCodec().decode(first.nextCursor!),
        const FormCursor(sortKey: _stamp, id: _id),
      );
      backend.response = _success();
      await reader.listDirectory(FormDirectoryQuery(cursor: first.nextCursor, limit: 1));
      final query = backend.parameters!['p_query']! as Map;
      expect(query['cursor_updated_at'], _stamp);
      expect(query['cursor_id'], _id);
      expect(query, isNot(contains('offset')));
      expect(backend.names, everyElement('superadmin_forms_directory_v2'));
    },
  );

  for (final code in [
    'SAI_AUTH_REQUIRED',
    'SAI_SESSION_INVALID',
    'SAI_INTERNAL_CONTEXT_DENIED',
    'SAI_MEMBERSHIP_SUSPENDED',
    'SAI_MEMBERSHIP_REVOKED',
    'SAI_PERMISSION_DENIED',
    'SAI_MFA_REQUIRED',
  ]) {
    test('rejects $code without exposing an accompanying projection', () async {
      final backend = _Backend({
        'ok': false,
        'data': (_success()['data']),
        'error': {'code': code, 'message': 'private-secret', 'details': 'private-secret'},
      });
      await expectLater(
        SupabaseSuperadminFormsDirectoryReader(backend).listDirectory(const FormDirectoryQuery()),
        throwsA(_failure(FormApiFailureKind.unauthorized)),
      );
      expect(backend.names, ['superadmin_forms_directory_v2']);
    });
  }

  for (final (code, kind) in [
    ('SAI_INVALID_ARGUMENT', FormApiFailureKind.validation),
    ('SAI_INTERNAL_ERROR', FormApiFailureKind.unavailable),
    ('private-secret', FormApiFailureKind.unavailable),
  ]) {
    test('sanitizes envelope failure $code', () async {
      final backend = _Backend({
        'ok': false,
        'data': null,
        'error': {'code': code, 'message': 'private-secret'},
      });
      await expectLater(
        SupabaseSuperadminFormsDirectoryReader(backend).listDirectory(const FormDirectoryQuery()),
        throwsA(_failure(kind)),
      );
    });
  }

  for (final (code, kind) in [
    ('42501', FormApiFailureKind.unauthorized),
    ('PGRST301', FormApiFailureKind.unauthorized),
    ('22023', FormApiFailureKind.validation),
    ('PGRST202', FormApiFailureKind.unavailable),
    ('unknown', FormApiFailureKind.unavailable),
  ]) {
    test('sanitizes transport failure $code', () async {
      final backend = _Backend(null)
        ..error = FormsBackendFailure(code: code, message: 'private-secret');
      await expectLater(
        SupabaseSuperadminFormsDirectoryReader(backend).listDirectory(const FormDirectoryQuery()),
        throwsA(_failure(kind)),
      );
    });
  }

  test('revocation after page one is not served from cached results', () async {
    final backend = _Backend(_success(more: true));
    final reader = SupabaseSuperadminFormsDirectoryReader(backend);
    final page = await reader.listDirectory(const FormDirectoryQuery(limit: 1));
    backend.response = {
      'ok': false,
      'data': null,
      'error': {'code': 'SAI_SESSION_INVALID'},
    };
    await expectLater(
      reader.listDirectory(FormDirectoryQuery(cursor: page.nextCursor, limit: 1)),
      throwsA(_failure(FormApiFailureKind.unauthorized)),
    );
    expect(backend.names, hasLength(2));
  });

  for (final query in [
    const FormDirectoryQuery(limit: 0),
    const FormDirectoryQuery(limit: 101),
    const FormDirectoryQuery(institutionId: 'invalid'),
    FormDirectoryQuery(search: 'x' * 501),
    FormDirectoryQuery(startsOnOrAfter: DateTime(2026, 9, 8), endsOnOrBefore: DateTime(2026, 9, 7)),
    const FormDirectoryQuery(cursor: 'not-a-cursor'),
    FormDirectoryQuery(cursor: 'x' * 1025),
    FormDirectoryQuery(
      cursor: const FormCursorCodec().encode(const FormCursor(sortKey: _stamp, id: 'invalid')),
    ),
    FormDirectoryQuery(
      cursor: const FormCursorCodec().encode(const FormCursor(sortKey: 'infinity', id: _id)),
    ),
    FormDirectoryQuery(
      cursor: const FormCursorCodec().encode(
        const FormCursor(sortKey: '2026-02-30T12:00:00Z', id: _id),
      ),
    ),
    FormDirectoryQuery(
      cursor: const FormCursorCodec().encode(
        const FormCursor(sortKey: '2026-09-07T12:00:00+99:99', id: _id),
      ),
    ),
  ].indexed) {
    test('rejects invalid query ${query.$1} before RPC', () async {
      final backend = _Backend(_success());
      await expectLater(
        SupabaseSuperadminFormsDirectoryReader(backend).listDirectory(query.$2),
        throwsA(_failure(FormApiFailureKind.validation)),
      );
      expect(backend.names, isEmpty);
    });
  }

  final malformed = <Object?>[
    null,
    [],
    {
      'items': [_item()],
    },
    {'ok': 'true', 'data': _success()['data'], 'error': null},
    {
      'ok': true,
      'data': _success()['data'],
      'error': {'code': 'SAI_PERMISSION_DENIED'},
    },
    {
      'ok': true,
      'data': {'items': 'invalid', 'has_more': false, 'next_cursor': null},
      'error': null,
    },
    for (final change in <Map<String, Object?>>[
      {'kind': 'future'},
      {'status': 'future'},
      {'operational_status': 'future'},
      {'identity_mode': 'future'},
      {'management_version': 0},
      {'management_version': '3'},
      {'id': 'invalid'},
      {'updated_at': 'infinity'},
      {'updated_at': '2026-02-30T12:00:00Z'},
      {'updated_at': '2026-09-07T12:00:00+99:99'},
      {'title': null},
      {'private-secret': 'private-secret'},
    ])
      {
        'ok': true,
        'data': {
          'items': [
            {..._item(), ...change},
          ],
          'has_more': false,
          'next_cursor': null,
        },
        'error': null,
      },
    {
      'ok': true,
      'data': {
        'items': [_item()],
        'has_more': true,
        'next_cursor': null,
      },
      'error': null,
    },
    {
      'ok': true,
      'data': {
        'items': [_item()],
        'has_more': false,
        'next_cursor': {'updated_at': _stamp, 'id': _id},
      },
      'error': null,
    },
    {
      'ok': true,
      'data': {
        'items': [_item()],
        'has_more': true,
        'next_cursor': {'updated_at': _stamp, 'id': _institution},
      },
      'error': null,
    },
    {
      'ok': true,
      'data': {
        'items': <Object?>[],
        'has_more': true,
        'next_cursor': {'updated_at': _stamp, 'id': _id},
      },
      'error': null,
    },
    {
      'ok': true,
      'data': {
        'items': [_item(), _item()],
        'has_more': false,
        'next_cursor': null,
      },
      'error': null,
    },
  ];
  for (final (index, response) in malformed.indexed) {
    test('rejects malformed projection $index instead of manufacturing defaults', () async {
      final backend = _Backend(response);
      await expectLater(
        SupabaseSuperadminFormsDirectoryReader(
          backend,
        ).listDirectory(const FormDirectoryQuery(limit: 1)),
        throwsA(_failure(FormApiFailureKind.unavailable)),
      );
    });
  }

  test('accepts an empty final page', () async {
    final backend = _Backend({
      'ok': true,
      'data': {'items': <Object?>[], 'has_more': false, 'next_cursor': null},
      'error': null,
    });
    final page = await SupabaseSuperadminFormsDirectoryReader(
      backend,
    ).listDirectory(const FormDirectoryQuery());
    expect(page.items, isEmpty);
    expect(page.nextCursor, isNull);
  });

  test('rejects duplicate identities even within the page limit', () async {
    final backend = _Backend({
      'ok': true,
      'data': {
        'items': [_item(), _item()],
        'has_more': false,
        'next_cursor': null,
      },
      'error': null,
    });
    await expectLater(
      SupabaseSuperadminFormsDirectoryReader(
        backend,
      ).listDirectory(const FormDirectoryQuery(limit: 2)),
      throwsA(_failure(FormApiFailureKind.unavailable)),
    );
  });
}

final class _Backend implements FormsBackendGateway {
  _Backend(this.response);
  Object? response;
  Object? error;
  final names = <String>[];
  Map<String, Object?>? parameters;

  @override
  Future<Object?> rpc(String functionName, Map<String, Object?> parameters) async {
    names.add(functionName);
    this.parameters = parameters;
    if (error != null) throw error!;
    return response;
  }

  @override
  Future<Object?> media(Map<String, Object?> envelope) => throw StateError('No media in directory');
}
