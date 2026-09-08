import 'dart:async';
import 'package:coelo_superadmin/features/children/data/supabase_child_directory_reader.dart';
import 'package:coelo_superadmin/features/children/presentation/child_directory_controller.dart';
import 'package:flutter_test/flutter_test.dart';

const institutionA = '10000000-0000-0000-0000-000000000001';
const institutionB = '10000000-0000-0000-0000-000000000002';
const contextId = '20000000-0000-0000-0000-000000000001';
const personId = '30000000-0000-0000-0000-000000000001';
Map<String, Object?> page(String owner) => {
  'ok': true,
  'error': null,
  'data': {
    'items': [
      {
        'context_id': contextId,
        'person_id': personId,
        'person_name': 'Sintética',
        'institution_id': owner,
        'institution_name': 'Sintética',
      },
    ],
    'next_cursor': null,
  },
};
Map<String, Object?> denial() => {
  'ok': false,
  'data': null,
  'error': {
    'code': 'SAI_MEMBERSHIP_REVOKED',
    'message': 'RAW INTERNAL',
    'correlation_id': contextId,
    'http_status': 403,
  },
};

void main() {
  test(
    'actual adapter DTO controller pipeline discards A after B and current revocation clears B',
    () async {
      final calls = <Map<String, Object?>>[];
      final replies = <Completer<Object?>>[];
      final reader = SupabaseChildDirectoryReader.withRpc((name, params) {
        expect(name, 'superadmin_child_context_directory_v2');
        calls.add(params);
        final reply = Completer<Object?>();
        replies.add(reply);
        return reply.future;
      });
      final controller = ChildDirectoryController(
        read: reader.fetchPage,
        sessionAvailable: true,
        institutionId: institutionA,
      );
      final old = controller.reload();
      final current = controller.setContext(
        sessionAvailable: true,
        institutionId: institutionB,
        revision: 1,
      );
      replies.last.complete(page(institutionB));
      await current;
      replies.first.complete(page(institutionA));
      await old;
      expect(controller.page!.items.single.institutionId, institutionB);
      expect(calls.map((call) => call['p_institution_id']), [institutionA, institutionB]);
      final revoked = controller.reload();
      expect(controller.page, isNull);
      replies.last.complete(denial());
      await revoked;
      expect(controller.state, ChildDirectoryState.denied);
      expect(controller.page, isNull);
      controller.dispose();
    },
  );
  test('strict DTO rejects leaked extra PII and pipeline retains no page', () async {
    final reader = SupabaseChildDirectoryReader.withRpc(
      (_, _) async => {
        'ok': true,
        'error': null,
        'data': {'items': <Object?>[], 'next_cursor': null, 'private': 'RAW'},
      },
    );
    final controller = ChildDirectoryController(read: reader.fetchPage, sessionAvailable: true);
    await controller.reload();
    expect(controller.state, ChildDirectoryState.unavailable);
    expect(controller.page, isNull);
    controller.dispose();
  });
  test('pipeline logout during response prevents restoring data and further transport', () async {
    final reply = Completer<Object?>();
    var calls = 0;
    final reader = SupabaseChildDirectoryReader.withRpc((_, _) {
      calls++;
      return reply.future;
    });
    final controller = ChildDirectoryController(read: reader.fetchPage, sessionAvailable: true);
    final old = controller.reload();
    await controller.setContext(sessionAvailable: false, institutionId: null, revision: 1);
    reply.complete(page(institutionA));
    await old;
    await controller.nextPage();
    expect(controller.state, ChildDirectoryState.denied);
    expect(controller.page, isNull);
    expect(calls, 1);
    controller.dispose();
  });
}
