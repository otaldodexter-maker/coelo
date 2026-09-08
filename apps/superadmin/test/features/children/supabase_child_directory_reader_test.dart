import 'dart:async';
import 'package:coelo_api/children.dart';
import 'package:coelo_superadmin/features/children/data/supabase_child_directory_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const contextId = '10000000-0000-0000-0000-000000000001';
const personId = '20000000-0000-0000-0000-000000000001';
const institutionId = '30000000-0000-0000-0000-000000000001';
const otherId = '40000000-0000-0000-0000-000000000001';
Map<String, Object?> row({String institution = institutionId}) => {
  'context_id': contextId,
  'person_id': personId,
  'person_name': 'Criança Sintética',
  'institution_id': institution,
  'institution_name': 'Instituição Sintética',
};
Map<String, Object?> ok({String institution = institutionId, Object? cursor}) => {
  'ok': true,
  'data': {
    'items': [row(institution: institution)],
    'next_cursor': cursor,
  },
  'error': null,
};
Map<String, Object?> denied(String code) => {
  'ok': false,
  'data': null,
  'error': {
    'code': code,
    'message': 'RAW PRIVATE ERROR',
    'correlation_id': contextId,
    'http_status': 403,
  },
};

void main() {
  test('calls only candidate RPC with exact defaults and no authority claims', () async {
    var calls = 0;
    final reader = SupabaseChildDirectoryReader.withRpc((name, params) async {
      calls++;
      expect(name, 'superadmin_child_context_directory_v2');
      expect(params, {
        'p_institution_id': null,
        'p_after_name': null,
        'p_after_context_id': null,
        'p_limit': 20,
      });
      return ok();
    });
    final result = await reader.fetchPage(const ChildDirectoryRequest());
    expect(result.items.single.contextId, contextId);
    expect(calls, 1);
  });
  test('passes opaque cursor unchanged including unicode and whitespace', () async {
    const name = '  İΣé\u00a0';
    final reader = SupabaseChildDirectoryReader.withRpc((_, params) async {
      expect(params, {
        'p_institution_id': institutionId,
        'p_after_name': name,
        'p_after_context_id': otherId,
        'p_limit': 50,
      });
      return ok();
    });
    await reader.fetchPage(
      const ChildDirectoryRequest(
        institutionId: institutionId,
        limit: 50,
        after: ChildDirectoryCursor(name: name, contextId: otherId),
      ),
    );
  });
  test('next cursor is decoded without a hidden second request', () async {
    var calls = 0;
    final reader = SupabaseChildDirectoryReader.withRpc((_, _) async {
      calls++;
      return ok(cursor: {'name': 'server opaque', 'context_id': contextId});
    });
    final result = await reader.fetchPage(const ChildDirectoryRequest(limit: 1));
    expect(result.nextCursor!.name, 'server opaque');
    expect(calls, 1);
  });
  test('invalid limits IDs and oversized cursor never invoke RPC', () async {
    var calls = 0;
    final reader = SupabaseChildDirectoryReader.withRpc((_, _) async {
      calls++;
      return ok();
    });
    for (final request in [
      const ChildDirectoryRequest(limit: 0),
      const ChildDirectoryRequest(limit: 51),
      const ChildDirectoryRequest(institutionId: 'bad'),
      ChildDirectoryRequest(
        after: ChildDirectoryCursor(name: 'é' * 4097, contextId: contextId),
      ),
    ]) {
      await expectLater(
        reader.fetchPage(request),
        throwsA(isA<ChildDirectoryUnavailableException>()),
      );
    }
    expect(calls, 0);
  });
  test('exact UTF8 cursor budget is sent intact', () async {
    final reader = SupabaseChildDirectoryReader.withRpc((_, params) async {
      expect(params['p_after_name'], 'é' * 4096);
      return ok();
    });
    await reader.fetchPage(
      ChildDirectoryRequest(
        after: ChildDirectoryCursor(name: 'é' * 4096, contextId: otherId),
      ),
    );
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
    test('safe denied envelope $code', () async {
      final reader = SupabaseChildDirectoryReader.withRpc((_, _) async => denied(code));
      await expectLater(
        reader.fetchPage(const ChildDirectoryRequest()),
        throwsA(isA<ChildDirectoryDeniedException>()),
      );
    });
  }
  for (final code in ['42501', 'PGRST301', 'PGRST302']) {
    test('maps Postgrest denied $code', () async {
      final reader = SupabaseChildDirectoryReader.withRpc(
        (_, _) async => throw PostgrestException(message: 'RAW PRIVATE ERROR', code: code),
      );
      await expectLater(
        reader.fetchPage(const ChildDirectoryRequest()),
        throwsA(isA<ChildDirectoryDeniedException>()),
      );
    });
  }
  test('unknown failure is sanitized without fallback or retry', () async {
    for (final error in [
      StateError('RAW PRIVATE ERROR'),
      const PostgrestException(message: 'RAW PRIVATE ERROR', code: 'XX000'),
    ]) {
      var calls = 0;
      final reader = SupabaseChildDirectoryReader.withRpc((_, _) async {
        calls++;
        throw error;
      });
      try {
        await reader.fetchPage(const ChildDirectoryRequest());
        fail('must reject');
      } on ChildDirectoryUnavailableException catch (error) {
        expect(error.toString(), isNot(contains('RAW PRIVATE ERROR')));
      }
      expect(calls, 1);
    }
  });
  test('malformed envelope wrong owner and oversized output cursor fail honestly', () async {
    for (final response in [
      null,
      <String, Object?>{},
      denied('SAI_INTERNAL_ERROR'),
      ok(institution: otherId),
      ok(cursor: {'name': 'é' * 4097, 'context_id': contextId}),
    ]) {
      final reader = SupabaseChildDirectoryReader.withRpc((_, _) async => response);
      await expectLater(
        reader.fetchPage(const ChildDirectoryRequest(institutionId: institutionId, limit: 1)),
        throwsA(isA<ChildDirectoryUnavailableException>()),
      );
    }
  });
  test('independent simultaneous requests do not share owner or cursor state', () async {
    final completions = <Completer<Object?>>[];
    final reader = SupabaseChildDirectoryReader.withRpc((_, _) {
      final completion = Completer<Object?>();
      completions.add(completion);
      return completion.future;
    });
    final first = reader.fetchPage(const ChildDirectoryRequest(institutionId: institutionId));
    final second = reader.fetchPage(const ChildDirectoryRequest(institutionId: otherId));
    completions.last.complete(ok(institution: otherId));
    expect((await second).items.single.institutionId, otherId);
    completions.first.complete(ok());
    expect((await first).items.single.institutionId, institutionId);
  });
  test('fresh read after denied retries only when caller explicitly requests', () async {
    var calls = 0;
    final reader = SupabaseChildDirectoryReader.withRpc(
      (_, _) async => calls++ == 0 ? denied('SAI_SESSION_INVALID') : ok(),
    );
    await expectLater(
      reader.fetchPage(const ChildDirectoryRequest()),
      throwsA(isA<ChildDirectoryDeniedException>()),
    );
    expect(calls, 1);
    expect((await reader.fetchPage(const ChildDirectoryRequest())).items, hasLength(1));
    expect(calls, 2);
  });
}
