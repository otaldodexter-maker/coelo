import 'dart:convert';

import 'package:coelo_superadmin/features/students/data/supabase_student_link_repository.dart';
import 'package:coelo_superadmin/features/students/domain/student_link.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class _Backend {
  final calls = <String, Map<String, Object?>>{};
  String? errorCode;

  MockClient get client => MockClient((request) async {
    final function = request.url.path.split('/rpc/').last;
    calls[function] = jsonDecode(request.body) as Map<String, Object?>;
    if (errorCode != null) {
      return Response(
        jsonEncode({'code': errorCode, 'message': 'recusado'}),
        400,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }
    return Response(
      jsonEncode({
        'child_context_id': 'context-1',
        'unit_link_id': 'unit-link-1',
        'group_link_id': 'group-link-1',
        'status': 'active',
      }),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  });

  Map<String, Object?> payloadOf(String function) =>
      calls[function]!['payload']! as Map<String, Object?>;
}

SupabaseClient _clientFor(_Backend backend) =>
    SupabaseClient('https://example.supabase.co', 'publishable-key', httpClient: backend.client);

void main() {
  test('nenhum dos quatro comandos envia instituição', () async {
    final backend = _Backend();
    final client = _clientFor(backend);
    addTearDown(client.dispose);
    final repository = SupabaseStudentLinkRepository(client);

    await repository.link(
      requestId: 'r1',
      childContextId: 'context-1',
      unitId: 'unit-1',
      groupId: 'group-1',
    );
    await repository.transfer(
      requestId: 'r2',
      childContextId: 'context-1',
      fromUnitId: 'unit-1',
      toUnitId: 'unit-2',
      reason: 'Mudança de turno.',
    );
    await repository.edit(
      requestId: 'r3',
      childContextId: 'context-1',
      unitId: 'unit-1',
      groupId: 'group-1',
    );
    await repository.revoke(
      requestId: 'r4',
      childContextId: 'context-1',
      unitId: 'unit-1',
      reason: 'Saída definitiva.',
    );

    expect(backend.calls, hasLength(4));
    for (final entry in backend.calls.entries) {
      final payload = entry.value['payload']! as Map<String, Object?>;
      expect(
        payload.keys.any((key) => key.contains('institution')),
        isFalse,
        reason:
            '${entry.key}: a instituição é derivada do contexto infantil no banco; '
            'aceitá-la do cliente permitiria mover a criança de tenant',
      );
      expect(entry.value['child_context_id'], 'context-1');
    }
  });

  test('editar distingue não mexer na data de fim de apagar a data de fim', () async {
    final backend = _Backend();
    final client = _clientFor(backend);
    addTearDown(client.dispose);
    final repository = SupabaseStudentLinkRepository(client);

    await repository.edit(
      requestId: 'r1',
      childContextId: 'context-1',
      unitId: 'unit-1',
      groupId: 'group-1',
      startsAt: DateTime.utc(2026, 9, 10),
    );
    expect(
      backend.payloadOf('superadmin_student_edit').containsKey('ends_at'),
      isFalse,
      reason: 'sem intenção sobre a data de fim, a chave não vai e o servidor não mexe nela',
    );

    await repository.edit(
      requestId: 'r2',
      childContextId: 'context-1',
      unitId: 'unit-1',
      groupId: 'group-1',
      clearEndsAt: true,
    );
    final payload = backend.payloadOf('superadmin_student_edit');
    expect(payload.containsKey('ends_at'), isTrue);
    expect(payload['ends_at'], isNull, reason: 'apagar a data de fim é a chave presente e nula');
  });

  test('transferir manda as duas unidades e o motivo', () async {
    final backend = _Backend();
    final client = _clientFor(backend);
    addTearDown(client.dispose);

    await SupabaseStudentLinkRepository(client).transfer(
      requestId: 'r1',
      childContextId: 'context-1',
      fromUnitId: 'unit-1',
      toUnitId: 'unit-2',
      toGroupId: 'group-2',
      reason: 'Mudança de turno.',
    );

    final payload = backend.payloadOf('superadmin_student_transfer');
    expect(payload['from_unit_id'], 'unit-1');
    expect(payload['to_unit_id'], 'unit-2');
    expect(payload['to_group_id'], 'group-2');
    expect(payload['reason'], 'Mudança de turno.');
  });

  test('cada recusa do servidor vira o tipo de falha certo', () async {
    for (final (code, kind) in <(String, StudentLinkFailureKind)>[
      ('42501', StudentLinkFailureKind.unauthorized),
      ('P0002', StudentLinkFailureKind.notFound),
      ('22023', StudentLinkFailureKind.invalidInput),
      ('40001', StudentLinkFailureKind.conflict),
      ('XX000', StudentLinkFailureKind.unavailable),
    ]) {
      final backend = _Backend()..errorCode = code;
      final client = _clientFor(backend);
      addTearDown(client.dispose);

      await expectLater(
        SupabaseStudentLinkRepository(client).revoke(
          requestId: 'r1',
          childContextId: 'context-1',
          unitId: 'unit-1',
          reason: 'Saída.',
        ),
        throwsA(isA<StudentLinkException>().having((error) => error.kind, 'kind', kind)),
        reason: 'código $code',
      );
    }
  });

  test('a composição padrão falha fechada e diz o motivo', () async {
    await expectLater(
      const UnavailableStudentLinkRepository().link(
        requestId: 'r1',
        childContextId: 'context-1',
        unitId: 'unit-1',
      ),
      throwsA(
        isA<StudentLinkException>()
            .having((error) => error.kind, 'kind', StudentLinkFailureKind.unavailable)
            .having((error) => error.message, 'message', contains('indisponível')),
      ),
    );
  });
}
