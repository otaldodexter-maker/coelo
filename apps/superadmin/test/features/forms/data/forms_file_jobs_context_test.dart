import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_superadmin/features/forms/data/forms_backend_gateway.dart';
import 'package:coelo_superadmin/features/forms/data/forms_file_jobs_reader.dart';
import 'package:coelo_superadmin/features/forms/data/supabase_forms_api.dart';
import 'package:flutter_test/flutter_test.dart';

const _form = '11111111-1111-4111-8111-111111111111';
const _job = '22222222-2222-4222-8222-222222222222';

void main() {
  test('export-only context uses one file-jobs RPC and exposes immutable page', () async {
    final backend = _Backend(_success(_context()));
    final FormsFileJobsReader reader = SupabaseFormsApi(backend);
    final result = await reader.listFileJobsContext(formId: _form, limit: 8);
    expect(result.formId, _form);
    expect(result.managementVersion, 4);
    expect(result.page.items.single.id, _job);
    expect(result.page.items.single.status, FormFileJobStatus.succeeded);
    expect(result.page.items.single.downloadAvailable, isTrue);
    expect(result.page.items.single.downloadPath, isNull);
    expect(() => result.page.items.clear(), throwsUnsupportedError);
    expect(backend.calls.single.$1, 'superadmin_forms_file_jobs_v2');
    expect(backend.calls.single.$2, {
      'p_query': {'form_id': _form, 'cursor_created_at': null, 'cursor_id': null, 'limit': 8},
    });
  });

  test('context cursor round-trips through the same existing pagination contract', () async {
    final backend = _Backend(_success(_context(hasMore: true)));
    final api = SupabaseFormsApi(backend);
    final first = await api.listFileJobsContext(formId: _form, limit: 8);
    expect(first.page.nextCursor, isNotNull);
    backend.response = _success(_context(items: const []));
    final second = await api.listFileJobsContext(
      formId: _form,
      limit: 8,
      cursor: first.page.nextCursor,
    );
    expect(second.page.items, isEmpty);
    expect(second.page.nextCursor, isNull);
    expect(backend.calls, hasLength(2));
    expect(backend.calls.last.$2, {
      'p_query': {
        'form_id': _form,
        'cursor_created_at': '2026-09-08T12:00:00Z',
        'cursor_id': _job,
        'limit': 8,
      },
    });
  });

  test('legacy listFileJobs still parses an old page without fetching context', () async {
    final payload = _context()
      ..remove('form_id')
      ..remove('management_version');
    final backend = _Backend(_success(payload));
    final FormCursorPage<FormFileJob> page = await SupabaseFormsApi(
      backend,
    ).listFileJobs(formId: _form);
    expect(page.items.single.id, _job);
    expect(backend.calls, hasLength(1));
    expect(backend.calls.single.$1, 'superadmin_forms_file_jobs_v2');
  });

  test('legacy and context reads share the same job parser', () async {
    final backend = _Backend(_success(_context()));
    final api = SupabaseFormsApi(backend);
    final old = await api.listFileJobs(formId: _form);
    final context = await api.listFileJobsContext(formId: _form);
    final a = old.items.single;
    final b = context.page.items.single;
    expect(
      (a.id, a.status, a.progress, a.downloadAvailable, a.downloadPath, a.errorCode),
      (b.id, b.status, b.progress, b.downloadAvailable, b.downloadPath, b.errorCode),
    );
    expect(backend.calls, hasLength(2));
  });

  for (final patch in <Map<String, Object?>>[
    {'form_id': null},
    {'form_id': ''},
    {'form_id': _job},
    {'form_id': 1},
    {'management_version': null},
    {'management_version': 0},
    {'management_version': -1},
    {'management_version': 1.5},
    {'management_version': 1.0},
    {'management_version': '4'},
  ]) {
    test('rejects mismatched or malformed context $patch', () async {
      await _reject(_success({..._context(), ...patch}));
    });
  }

  test('missing candidate fields never falls back to overview or editor access', () async {
    final payload = _context()
      ..remove('form_id')
      ..remove('management_version');
    final backend = _Backend(_success(payload));
    await expectLater(SupabaseFormsApi(backend).listFileJobsContext(formId: _form), _unavailable);
    expect(backend.calls, hasLength(1));
  });

  for (final patch in <Map<String, Object?>>[
    {'has_more': true, 'next_cursor': null},
    {
      'has_more': false,
      'next_cursor': {'created_at': '2026-09-08T12:00:00Z', 'id': _job},
    },
    {
      'has_more': true,
      'items': <Object?>[],
      'next_cursor': {'created_at': '2026-09-08T12:00:00Z', 'id': _job},
    },
    {
      'has_more': true,
      'next_cursor': {'created_at': '', 'id': _job},
    },
    {
      'has_more': true,
      'next_cursor': {'created_at': '2026-09-08T12:00:00Z', 'id': ''},
    },
    {
      'has_more': true,
      'next_cursor': {'created_at': '2026-09-08T12:00:00Z', 'id': _job, 'offset': 2},
    },
    {
      'items': [
        {'id': _job, 'status': 'unknown', 'progress': 0},
      ],
    },
  ]) {
    test('uses existing strict page and cursor checks $patch', () async {
      await _reject(_success({..._context(), ...patch}));
    });
  }

  test('invalid caller cursor is rejected before any RPC', () async {
    final backend = _Backend(_success(_context()));
    await expectLater(
      SupabaseFormsApi(backend).listFileJobsContext(formId: _form, cursor: 'not-a-cursor'),
      _unavailable,
    );
    expect(backend.calls, isEmpty);
  });

  test('denial wins over a valid-looking context and keeps errors sanitized', () async {
    final backend = _Backend({
      'ok': false,
      'data': _context(),
      'error': {'code': 'SAI_PERMISSION_DENIED', 'message': 'private other-tenant diagnostics'},
    });
    await expectLater(
      SupabaseFormsApi(backend).listFileJobsContext(formId: _form),
      throwsA(
        isA<FormApiException>()
            .having((error) => error.kind, 'kind', FormApiFailureKind.unauthorized)
            .having((error) => error.message, 'message', isNot(contains('other-tenant'))),
      ),
    );
    expect(backend.calls, hasLength(1));
  });
}

final _unavailable = throwsA(
  isA<FormApiException>().having((error) => error.kind, 'kind', FormApiFailureKind.unavailable),
);

Future<void> _reject(Object? envelope) async {
  await expectLater(
    SupabaseFormsApi(_Backend(envelope)).listFileJobsContext(formId: _form),
    _unavailable,
  );
}

Map<String, Object?> _success(Map<String, Object?> payload) => {
  'ok': true,
  'data': payload,
  'error': null,
};

Map<String, Object?> _context({bool hasMore = false, List<Map<String, Object?>>? items}) => {
  'form_id': _form,
  'management_version': 4,
  'items':
      items ??
      [
        {
          'id': _job,
          'status': 'succeeded',
          'progress': 1,
          'download_available': true,
          'download_path': 'https://private.invalid/capability',
          'error_code': null,
        },
      ],
  'has_more': hasMore,
  'next_cursor': hasMore ? {'created_at': '2026-09-08T12:00:00Z', 'id': _job} : null,
};

final class _Backend implements FormsBackendGateway {
  _Backend(this.response);
  Object? response;
  final calls = <(String, Map<String, Object?>)>[];
  @override
  Future<Object?> rpc(String functionName, Map<String, Object?> parameters) async {
    calls.add((functionName, parameters));
    if (functionName != 'superadmin_forms_file_jobs_v2') {
      throw StateError('Unexpected permission dependency');
    }
    return response;
  }

  @override
  Future<Object?> media(Map<String, Object?> envelope) => throw StateError('Unexpected media call');
}
