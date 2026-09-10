import 'dart:convert';

import 'package:coelo_superadmin/features/attendance/attendance.dart';
import 'package:coelo_superadmin/features/attendance/data/supabase_attendance_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A chave de idempotência de Assiduidade deixou de ser montada no cliente
/// (D11, OQ-040). A semântica de intenção — mesma chamada é a mesma chave,
/// outra turma ou outro dia é outra chave — passou para o banco e é provada em
/// `packages/coelo_database/supabase/tests/attendance_authorization_and_idempotency_v1_test.sql`.
///
/// O que continua sendo responsabilidade do cliente, e é o que este arquivo
/// prova: pedir a chave ao servidor, mandar de volta exatamente o que ele
/// devolveu, e descrever a intenção com o contexto certo, porque criar chamada
/// é o único comando sem agregado e sem versão esperada.
final _draft = AttendanceCallDraft(
  institutionId: 'institution-1',
  unitId: 'unit-1',
  groupId: 'group-1',
  activityContextId: 'activity-1',
  date: DateTime(2026, 8, 10),
);

const _callResponse = {
  'id': 'call-1',
  'institution_id': 'institution-1',
  'unit_id': 'unit-1',
  'group_id': 'group-1',
  'session_date': '2026-08-10',
  'status': 'open',
  'version': 1,
  'participants': <Object?>[],
};

/// Um servidor de mentira que reserva chaves como o banco reserva: a mesma
/// intenção recebe sempre a mesma chave.
final class _FakeAttendanceBackend {
  final reservations = <String, String>{};
  final sentKeys = <String>[];
  final commands = <Map<String, Object?>>[];
  var reserveFailures = 0;
  var commandFailures = 0;

  MockClient get client => MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, Object?>;
    if (request.url.path.endsWith('/rpc/attendance_reserve_idempotency_key')) {
      if (reserveFailures > 0) {
        reserveFailures--;
        return Response('{"message":"boom"}', 500, request: request);
      }
      final intent = jsonEncode([
        body['command'],
        body['aggregate_id'],
        body['expected_version'],
        body['scope'],
      ]);
      final key = reservations.putIfAbsent(intent, () => 'key-${reservations.length + 1}');
      return Response(
        jsonEncode(key),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }
    commands.add(body);
    sentKeys.add(body['p_idempotency_key']! as String);
    if (commandFailures > 0) {
      commandFailures--;
      return Response('{"message":"boom"}', 500, request: request);
    }
    return Response(
      jsonEncode(_callResponse),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  });
}

SupabaseClient _clientFor(_FakeAttendanceBackend backend) =>
    SupabaseClient('https://example.supabase.co', 'publishable-key', httpClient: backend.client);

void main() {
  test('a chave enviada no comando é a que o servidor reservou', () async {
    final backend = _FakeAttendanceBackend();
    final client = _clientFor(backend);
    addTearDown(client.dispose);

    await SupabaseAttendanceRepository(client).createCall(_draft);

    expect(backend.sentKeys, hasLength(1));
    expect(
      backend.reservations.values,
      contains(backend.sentKeys.single),
      reason: 'o cliente não inventa chave: ele devolve a que reservou',
    );
  });

  test('criar chamada descreve a intenção pelo contexto da chamada', () async {
    final backend = _FakeAttendanceBackend();
    final client = _clientFor(backend);
    addTearDown(client.dispose);

    await SupabaseAttendanceRepository(client).createCall(_draft);

    final reserved = jsonDecode(backend.reservations.keys.single) as List<Object?>;
    expect(reserved[0], 'create_call');
    expect(
      reserved[3],
      {
        'institution_id': 'institution-1',
        'unit_id': 'unit-1',
        'group_id': 'group-1',
        'activity_id': 'activity-1',
        'session_date': '2026-08-10',
      },
      reason: 'sem o contexto, duas chamadas diferentes teriam a mesma chave',
    );
  });

  test('repetir uma criação que falhou repete a mesma chave', () async {
    final backend = _FakeAttendanceBackend()..commandFailures = 1;
    final client = _clientFor(backend);
    addTearDown(client.dispose);
    final repository = SupabaseAttendanceRepository(client);

    await expectLater(repository.createCall(_draft), throwsA(isA<Object>()));
    await repository.createCall(_draft);

    expect(backend.sentKeys, hasLength(2));
    expect(
      backend.sentKeys.first,
      backend.sentKeys.last,
      reason: 'criar a mesma chamada duas vezes é uma intenção repetida',
    );
  });

  test('outra turma ou outro dia é outra intenção', () async {
    final backend = _FakeAttendanceBackend();
    final client = _clientFor(backend);
    addTearDown(client.dispose);
    final repository = SupabaseAttendanceRepository(client);

    await repository.createCall(_draft);
    await repository.createCall(
      AttendanceCallDraft(
        institutionId: _draft.institutionId,
        unitId: _draft.unitId,
        groupId: 'group-2',
        activityContextId: _draft.activityContextId,
        date: _draft.date,
      ),
    );
    await repository.createCall(
      AttendanceCallDraft(
        institutionId: _draft.institutionId,
        unitId: _draft.unitId,
        groupId: _draft.groupId,
        activityContextId: _draft.activityContextId,
        date: DateTime(2026, 8, 11),
      ),
    );

    expect(backend.reservations, hasLength(3));
    expect(backend.sentKeys.toSet(), hasLength(3));
  });

  test('comando sobre chamada existente reserva por agregado e versão', () async {
    final backend = _FakeAttendanceBackend();
    final client = _clientFor(backend);
    addTearDown(client.dispose);

    await SupabaseAttendanceRepository(client).completeCall('call-1', expectedVersion: 3);

    final reserved = jsonDecode(backend.reservations.keys.single) as List<Object?>;
    expect(reserved[0], 'complete_call');
    expect(reserved[1], 'call-1');
    expect(
      reserved[2],
      3,
      reason: 'depois que a chamada avança, a intenção antiga deixou de existir',
    );
  });

  test('falha ao reservar não envia comando com chave inventada', () async {
    final backend = _FakeAttendanceBackend()..reserveFailures = 1;
    final client = _clientFor(backend);
    addTearDown(client.dispose);

    await expectLater(
      SupabaseAttendanceRepository(client).createCall(_draft),
      throwsA(isA<Object>()),
    );

    expect(backend.commands, isEmpty, reason: 'sem chave reservada não se escreve nada');
  });
}
