import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_superadmin/features/forms/data/forms_authoring_api.dart';
import 'package:coelo_superadmin/features/forms/data/forms_backend_gateway.dart';
import 'package:coelo_superadmin/features/forms/data/supabase_forms_authoring_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses only the nominal institution endpoint and preserves the second page', () async {
    final backend = _Gateway();
    final api = SupabaseFormsAuthoringApi(backend);
    backend.result = _ok({
      'items': [for (var i = 1; i <= 20; i++) _institution(i)],
      'has_more': true,
      'next_cursor': {'name_key': 'name 20', 'id': _id(20)},
    });
    final first = await api.listInstitutions(const FormsAuthoringInstitutionQuery());
    expect(first.items.length, 20);
    expect(first.hasMore, isTrue);
    expect(backend.calls.single.$1, 'superadmin_forms_authoring_institutions_v2');
    backend.result = _ok({
      'items': [_institution(21)],
      'has_more': false,
      'next_cursor': null,
    });
    final second = await api.listInstitutions(
      FormsAuthoringInstitutionQuery(cursor: first.nextCursor),
    );
    expect(second.items.single.id, _id(21));
    expect(second.hasMore, isFalse);
    expect((backend.calls.last.$2['p_query']! as Map)['cursor'], {
      'name_key': 'name 20',
      'id': _id(20),
    });
  });

  test('empty authorized results are not an unavailable context', () async {
    final backend = _Gateway()
      ..result = _ok({'items': <Object?>[], 'has_more': false, 'next_cursor': null});
    final page = await SupabaseFormsAuthoringApi(
      backend,
    ).listInstitutions(const FormsAuthoringInstitutionQuery(search: 'no match'));
    expect(page.items, isEmpty);
    expect(page.hasMore, isFalse);
  });

  for (final query in [
    const FormsAuthoringInstitutionQuery(limit: 0),
    const FormsAuthoringInstitutionQuery(limit: 51),
    FormsAuthoringInstitutionQuery(search: 'x' * 161),
    FormsAuthoringInstitutionQuery(
      cursor: FormsAuthoringInstitutionCursor(nameKey: 'x' * 1025, id: _id(1)),
    ),
    const FormsAuthoringInstitutionQuery(
      cursor: FormsAuthoringInstitutionCursor(nameKey: 'a', id: 'not-uuid'),
    ),
  ]) {
    test(
      'invalid nominal query is rejected before a backend call: ${query.limit}/${query.search.length}/${query.cursor?.id}',
      () async {
        final backend = _Gateway();
        await expectLater(
          SupabaseFormsAuthoringApi(backend).listInstitutions(query),
          throwsA(_failure(FormApiFailureKind.validation)),
        );
        expect(backend.calls, isEmpty);
      },
    );
  }

  final malformedPages = <String, Map<String, Object?>>{
    'cursor with no items': {
      'items': [],
      'has_more': true,
      'next_cursor': {'name_key': 'x', 'id': _id(1)},
    },
    'cursor after end': {
      'items': [_institution(1)],
      'has_more': false,
      'next_cursor': {'name_key': 'name 1', 'id': _id(1)},
    },
    'wrong last ID': {
      'items': [_institution(1)],
      'has_more': true,
      'next_cursor': {'name_key': 'name 1', 'id': _id(2)},
    },
    'partial cursor': {
      'items': [_institution(1)],
      'has_more': true,
      'next_cursor': {'id': _id(1)},
    },
    'duplicate IDs': {
      'items': [_institution(1), _institution(1)],
      'has_more': false,
      'next_cursor': null,
    },
    'too many items': {
      'items': [for (var i = 1; i <= 21; i++) _institution(i)],
      'has_more': false,
      'next_cursor': null,
    },
    'nullable flag': {'items': [], 'has_more': null, 'next_cursor': null},
    'string flag': {'items': [], 'has_more': 'false', 'next_cursor': null},
    'extra private field': {
      'items': [
        {..._institution(1), 'document_ref': 'must not escape'},
      ],
      'has_more': false,
      'next_cursor': null,
    },
    'null name': {
      'items': [
        {'id': _id(1), 'public_name': null},
      ],
      'has_more': false,
      'next_cursor': null,
    },
    'missing cursor field': {'items': [], 'has_more': false},
  };
  for (final entry in malformedPages.entries) {
    test('rejects malformed institution page: ${entry.key}', () async {
      final backend = _Gateway()..result = _ok(entry.value);
      await expectLater(
        SupabaseFormsAuthoringApi(backend).listInstitutions(const FormsAuthoringInstitutionQuery()),
        throwsA(_failure(FormApiFailureKind.unavailable)),
      );
    });
  }

  for (final manage in [true, false]) {
    test('opens nominal editor with manage=$manage without requesting a catalog', () async {
      final backend = _Gateway()..result = _ok(_editor(manage: manage));
      final editor = await SupabaseFormsAuthoringApi(backend).getEditor(_id(101));
      expect(editor.canManage, manage);
      expect(editor.institution.id, editor.definition.institutionId);
      expect(backend.calls.map((call) => call.$1), ['superadmin_forms_editor_v2']);
    });
  }

  for (final entry in <String, Map<String, Object?>>{
    'foreign institution': {..._editor(), 'institution': _institution(2)},
    'foreign form': {
      ..._editor(),
      'definition': {..._definition(), 'id': _id(999)},
    },
    'missing manage': {..._editor(), 'capabilities': <String, Object?>{}},
    'string manage': {
      ..._editor(),
      'capabilities': {'manage': 'true'},
    },
    'out of slice grant': {
      ..._editor(),
      'capabilities': {'manage': true, 'publish': false},
    },
    'application projection': {
      ..._editor(),
      'application': {'id': _id(500)},
    },
  }.entries) {
    test('rejects malformed nominal editor: ${entry.key}', () async {
      final backend = _Gateway()..result = _ok(entry.value);
      await expectLater(
        SupabaseFormsAuthoringApi(backend).getEditor(_id(101)),
        throwsA(_failure(FormApiFailureKind.unavailable)),
      );
    });
  }

  test('save sends only the nominal allowlist and returns the receipt without reload', () async {
    final backend = _Gateway()..result = _ok(_definition());
    final input = FormDefinitionDto.fromJson(_definition()).toDomain();
    final saved = await SupabaseFormsAuthoringApi(
      backend,
    ).saveDraft(FormCommand(requestId: _id(201), expectedVersion: 0, payload: input));
    expect(saved.title, 'Receipt original');
    expect(backend.calls.length, 1);
    expect(backend.calls.single.$1, 'superadmin_forms_save_draft_v2');
    expect(backend.calls.single.$2, {
      'p_request_id': _id(201),
      'p_expected_version': 0,
      'p_payload': {
        'id': _id(101),
        'institution_id': _id(1),
        'kind': 'form',
        'identity_mode': 'identified',
        'response_unit': 'person',
        'title': 'Receipt original',
        'description': null,
        'sections': <Object?>[],
      },
    });
  });

  for (final returnedVersion in [1, 3]) {
    test('rejects receipt version $returnedVersion for expected version 1', () async {
      final backend = _Gateway()
        ..result = _ok({..._definition(), 'management_version': returnedVersion});
      await expectLater(
        SupabaseFormsAuthoringApi(backend).saveDraft(
          FormCommand(
            requestId: _id(201),
            expectedVersion: 1,
            payload: FormDefinitionDto.fromJson(_definition()).toDomain(),
          ),
        ),
        throwsA(_failure(FormApiFailureKind.unavailable)),
      );
      expect(backend.calls.length, 1);
    });
  }

  test('old replay returns its version 2 snapshot without fetching a later version', () async {
    final backend = _Gateway()..result = _ok({..._definition(), 'management_version': 2});
    final saved = await SupabaseFormsAuthoringApi(backend).saveDraft(
      FormCommand(
        requestId: _id(201),
        expectedVersion: 1,
        payload: FormDefinitionDto.fromJson(_definition()).toDomain(),
      ),
    );
    expect(saved.managementVersion, 2);
    expect(saved.title, 'Receipt original');
    expect(backend.calls.length, 1);
  });

  for (final code in [
    'SAI_PERMISSION_DENIED',
    'SAI_SESSION_INVALID',
    'SAI_CONCURRENT_CHANGE',
    'SAI_INVALID_ARGUMENT',
    'unexpected',
  ]) {
    test('nominal error $code discards even supplied data and never falls back', () async {
      final backend = _Gateway()
        ..result = {
          'ok': false,
          'data': _editor(),
          'error': {'code': code, 'message': 'unsafe raw backend text'},
        };
      final kind = switch (code) {
        'SAI_CONCURRENT_CHANGE' => FormApiFailureKind.conflict,
        'SAI_INVALID_ARGUMENT' => FormApiFailureKind.validation,
        'unexpected' => FormApiFailureKind.unavailable,
        _ => FormApiFailureKind.unauthorized,
      };
      await expectLater(
        SupabaseFormsAuthoringApi(backend).getEditor(_id(101)),
        throwsA(
          _failure(
            kind,
          ).having((error) => error.message, 'safe message', isNot(contains('unsafe'))),
        ),
      );
      expect(backend.calls.length, 1);
    });
  }
}

TypeMatcher<FormApiException> _failure(FormApiFailureKind kind) =>
    isA<FormApiException>().having((error) => error.kind, 'kind', kind);
String _id(int value) => '8f032000-0000-4000-8000-${value.toString().padLeft(12, '0')}';
Map<String, Object?> _institution(int value) => {'id': _id(value), 'public_name': 'Name $value'};
Map<String, Object?> _definition() => {
  'id': _id(101),
  'institution_id': _id(1),
  'kind': 'form',
  'identity_mode': 'identified',
  'response_unit': 'person',
  'title': 'Receipt original',
  'description': null,
  'status': 'draft',
  'management_version': 1,
  'sections': [],
};
Map<String, Object?> _editor({bool manage = true}) => {
  'definition': _definition(),
  'application': null,
  'institution': _institution(1),
  'capabilities': {'manage': manage},
};
Map<String, Object?> _ok(Object? data) => {'ok': true, 'data': data, 'error': null};

final class _Gateway implements FormsBackendGateway {
  Object? result;
  final calls = <(String, Map<String, Object?>)>[];
  @override
  Future<Object?> rpc(String functionName, Map<String, Object?> parameters) async {
    calls.add((functionName, parameters));
    return result;
  }

  @override
  Future<Object?> media(Map<String, Object?> envelope) =>
      throw StateError('No media in authoring context.');
}
