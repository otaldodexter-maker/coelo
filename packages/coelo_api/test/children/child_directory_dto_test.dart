import 'package:coelo_api/children.dart';
import 'package:test/test.dart';

const contextId = '10000000-0000-0000-0000-000000000001';
const personId = '20000000-0000-0000-0000-000000000001';
const institutionId = '30000000-0000-0000-0000-000000000001';
const otherId = '40000000-0000-0000-0000-000000000001';
Map<String, Object?> item() => {
  'context_id': contextId,
  'person_id': personId,
  'person_name': 'Criança Sintética',
  'institution_id': institutionId,
  'institution_name': 'Instituição Sintética',
};
Map<String, Object?> response(List<Object?> items, {Object? cursor}) => {
  'ok': true,
  'data': {'items': items, 'next_cursor': cursor},
  'error': null,
};
void main() {
  test('does not infer unicode name normalization', () {
    final page = decodeChildDirectory(
      response([
        {...item(), 'person_name': '\u00a0'},
      ]),
      request: ChildDirectoryRequest(),
    );
    expect(page.items.single.personName, '\u00a0');
  });
  test('invalid error envelopes never become a safe denial', () {
    final error = <String, Object?>{
      'code': 'SAI_PERMISSION_DENIED',
      'message': 'RAW',
      'correlation_id': contextId,
      'http_status': 403,
    };
    for (final payload in [
      {'ok': false, 'data': item(), 'error': error},
      {
        'ok': false,
        'data': null,
        'error': {...error, 'http_status': 403.0},
      },
      {
        'ok': false,
        'data': null,
        'error': {...error, 'code': 'SAI_INTERNAL_ERROR'},
      },
      {
        'ok': false,
        'data': null,
        'error': {...error, 'correlation_id': 'bad'},
      },
      {
        'ok': false,
        'data': null,
        'error': {...error, 'private': 'RAW'},
      },
    ]) {
      expect(
        () => decodeChildDirectory(payload, request: ChildDirectoryRequest()),
        throwsFormatException,
      );
    }
  });
  test('malformed scalar and cursor payloads are rejected', () {
    for (final payload in [
      response([
        {...item(), 'person_name': 'bad\nname'},
      ]),
      response([
        {...item(), 'person_name': String.fromCharCode(0xd800)},
      ]),
      response([item()], cursor: {'name': 'name'}),
      response([item()], cursor: {'name': 1, 'context_id': contextId}),
      {
        'ok': true,
        'data': {'items': 'not a list', 'next_cursor': null},
        'error': null,
      },
    ]) {
      expect(
        () => decodeChildDirectory(payload, request: ChildDirectoryRequest(limit: 1)),
        throwsFormatException,
      );
    }
  });
  test('decoded page copies source and terminal full page has no next cursor', () {
    final raw = item();
    final source = <Object?>[raw];
    final page = decodeChildDirectory(response(source), request: ChildDirectoryRequest(limit: 1));
    raw['person_name'] = 'changed';
    source.clear();
    expect(page.items.single.personName, 'Criança Sintética');
    expect(page.nextCursor, isNull);
  });
  test('cursor budget is UTF8 bytes and never truncates cadastral names', () {
    expect(
      ChildDirectoryRequest(
        after: ChildDirectoryCursor(name: 'é' * 4096, contextId: contextId),
      ).toRpcParams()['p_after_name'],
      'é' * 4096,
    );
    expect(
      () => ChildDirectoryRequest(
        after: ChildDirectoryCursor(name: 'é' * 4097, contextId: contextId),
      ).toRpcParams(),
      throwsFormatException,
    );
    final page = decodeChildDirectory(
      response([
        {...item(), 'person_name': 'a' * 9000},
      ]),
      request: ChildDirectoryRequest(),
    );
    expect(page.items.single.personName.length, 9000);
    expect(
      () => decodeChildDirectory(
        response([item()], cursor: {'name': 'é' * 4097, 'context_id': contextId}),
        request: ChildDirectoryRequest(limit: 1),
      ),
      throwsFormatException,
    );
  });
  test('rejects non-advancing identical next cursor', () {
    expect(
      () => decodeChildDirectory(
        response([item()], cursor: {'name': 'name', 'context_id': contextId}),
        request: ChildDirectoryRequest(
          limit: 1,
          after: ChildDirectoryCursor(name: 'name', contextId: contextId),
        ),
      ),
      throwsFormatException,
    );
  });
  test('request defaults and explicit cursor are nominal', () {
    expect(ChildDirectoryRequest().toRpcParams(), {
      'p_institution_id': null,
      'p_after_name': null,
      'p_after_context_id': null,
      'p_limit': 20,
    });
    expect(
      ChildDirectoryRequest(
        institutionId: institutionId,
        limit: 1,
        after: ChildDirectoryCursor(name: 'server lower', contextId: contextId),
      ).toRpcParams(),
      {
        'p_institution_id': institutionId,
        'p_after_name': 'server lower',
        'p_after_context_id': contextId,
        'p_limit': 1,
      },
    );
  });
  for (final limit in [0, -1, 51]) {
    test(
      'rejects invalid limit $limit',
      () => expect(() => ChildDirectoryRequest(limit: limit).toRpcParams(), throwsFormatException),
    );
  }
  test('accepts maximum request and rejects invalid identifiers/cursor', () {
    expect(ChildDirectoryRequest(limit: 50).toRpcParams()['p_limit'], 50);
    for (final request in [
      ChildDirectoryRequest(institutionId: 'bad'),
      ChildDirectoryRequest(
        after: ChildDirectoryCursor(name: '', contextId: contextId),
      ),
      ChildDirectoryRequest(
        after: ChildDirectoryCursor(name: 'name', contextId: 'bad'),
      ),
    ]) {
      expect(request.toRpcParams, throwsFormatException);
    }
  });
  test('empty page has no total and no cursor', () {
    final page = decodeChildDirectory(response([]), request: ChildDirectoryRequest());
    expect(page.items, isEmpty);
    expect(page.nextCursor, isNull);
  });
  test('full page cursor is server supplied and last returned context', () {
    final page = decodeChildDirectory(
      response([item()], cursor: {'name': 'server_lower', 'context_id': contextId}),
      request: ChildDirectoryRequest(limit: 1, institutionId: institutionId),
    );
    expect(page.items.single.personId, personId);
    expect(page.nextCursor!.name, 'server_lower');
    expect(page.nextCursor!.contextId, contextId);
  });
  test('same person may have different institutional contexts', () {
    final page = decodeChildDirectory(
      response([
        item(),
        {...item(), 'context_id': otherId, 'institution_id': otherId},
      ]),
      request: ChildDirectoryRequest(),
    );
    expect(page.items, hasLength(2));
    expect(() => page.items.clear(), throwsUnsupportedError);
  });
  test('denies duplicate context, wrong filter and over-limit', () {
    for (final payload in [
      response([item(), item()]),
      response([
        {...item(), 'institution_id': otherId},
      ]),
      response([
        item(),
        {...item(), 'context_id': otherId},
      ]),
    ]) {
      expect(
        () => decodeChildDirectory(
          payload,
          request: ChildDirectoryRequest(limit: 1, institutionId: institutionId),
        ),
        throwsFormatException,
      );
    }
  });
  test('rejects cursor for empty, short or mismatched last row', () {
    for (final payload in [
      response([], cursor: {'name': 'name', 'context_id': contextId}),
      response([item()], cursor: {'name': 'name', 'context_id': contextId}),
      response(
        [
          item(),
          {...item(), 'context_id': otherId},
        ],
        cursor: {'name': 'name', 'context_id': contextId},
      ),
    ]) {
      expect(
        () => decodeChildDirectory(payload, request: ChildDirectoryRequest(limit: 2)),
        throwsFormatException,
      );
    }
  });
  test('strict shape rejects extra PII total and raw envelope', () {
    for (final payload in [
      item(),
      response([
        {...item(), 'local_identifier': 'secret'},
      ]),
      {
        'ok': true,
        'data': {'items': <Object?>[], 'next_cursor': null, 'total_count': 0},
        'error': null,
      },
    ]) {
      expect(
        () => decodeChildDirectory(payload, request: ChildDirectoryRequest()),
        throwsFormatException,
      );
    }
  });
  for (final field in [
    'context_id',
    'person_id',
    'institution_id',
    'person_name',
    'institution_name',
  ]) {
    test(
      'rejects malformed $field',
      () => expect(
        () => decodeChildDirectory(
          response([
            {...item(), field: ''},
          ]),
          request: ChildDirectoryRequest(),
        ),
        throwsFormatException,
      ),
    );
  }
  for (final code in [
    'SAI_AUTH_REQUIRED',
    'SAI_SESSION_INVALID',
    'SAI_INTERNAL_CONTEXT_DENIED',
    'SAI_MEMBERSHIP_SUSPENDED',
    'SAI_MEMBERSHIP_REVOKED',
    'SAI_PERMISSION_DENIED',
    'SAI_MFA_REQUIRED',
  ]) {
    test(
      'safe denied for $code',
      () => expect(
        () => decodeChildDirectory({
          'ok': false,
          'data': null,
          'error': {
            'code': code,
            'message': 'RAW',
            'correlation_id': contextId,
            'http_status': 403,
          },
        }, request: ChildDirectoryRequest()),
        throwsA(isA<ChildDirectoryDeniedException>()),
      ),
    );
  }
}
