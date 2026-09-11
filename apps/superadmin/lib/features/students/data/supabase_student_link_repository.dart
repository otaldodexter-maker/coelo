import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/student_link.dart';

/// Vínculo de alunos contra o Supabase real.
///
/// Os quatro comandos são RPC `SECURITY DEFINER`. O cliente não tem grant de
/// escrita em `child_unit_links` nem em `child_group_links`, então não existe
/// caminho por PostgREST direto: se este arquivo montasse uma consulta a
/// tabela, estaria pedindo algo que o banco recusaria.
///
/// Nenhum método aceita instituição. Ela é derivada do contexto infantil dentro
/// do comando, porque aceitar a instituição enviada pelo cliente permitiria
/// mover a criança de um tenant para outro.
final class SupabaseStudentLinkRepository implements StudentLinkRepository {
  const SupabaseStudentLinkRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<StudentLinks> fetchLinks(String childContextId) async {
    final Object? payload;
    try {
      payload = await _client.rpc<Object?>(
        'superadmin_student_links',
        params: {'child_context_id': childContextId},
      );
    } on PostgrestException catch (error) {
      throw _translate(error);
    }
    final map = payload is Map ? payload.cast<String, Object?>() : const <String, Object?>{};
    return StudentLinks(
      childContextId: map['child_context_id'] as String? ?? childContextId,
      childPersonId: map['child_person_id'] as String? ?? '',
      displayName: map['display_name'] as String? ?? '',
      institutionId: map['institution_id'] as String? ?? '',
      canManage: map['can_manage'] == true,
      unitLinks: _rows(map['unit_links']).map(_unitLink).toList(growable: false),
    );
  }

  @override
  Future<StudentLinkResult> link({
    required String requestId,
    required String childContextId,
    required String unitId,
    String? groupId,
    DateTime? startsAt,
  }) async => _result(
    await _rpc('superadmin_student_link', requestId, childContextId, {
      'unit_id': unitId,
      'group_id': groupId,
      'starts_at': startsAt?.toUtc().toIso8601String(),
    }),
  );

  @override
  Future<StudentLinkResult> transfer({
    required String requestId,
    required String childContextId,
    required String fromUnitId,
    required String toUnitId,
    required String reason,
    String? toGroupId,
  }) async => _result(
    await _rpc('superadmin_student_transfer', requestId, childContextId, {
      'from_unit_id': fromUnitId,
      'to_unit_id': toUnitId,
      'to_group_id': toGroupId,
      'reason': reason,
    }),
  );

  @override
  Future<StudentLinkResult> edit({
    required String requestId,
    required String childContextId,
    required String unitId,
    required String groupId,
    DateTime? startsAt,
    DateTime? endsAt,
    bool clearEndsAt = false,
  }) async => _result(
    await _rpc('superadmin_student_edit', requestId, childContextId, {
      'unit_id': unitId,
      'group_id': groupId,
      'starts_at': startsAt?.toUtc().toIso8601String(),
      // `ends_at` só entra no payload quando há intenção sobre ele: o comando
      // distingue "não mexa na data de fim" de "apague a data de fim" pela
      // presença da chave, não pelo valor nulo.
      if (clearEndsAt || endsAt != null) 'ends_at': endsAt?.toUtc().toIso8601String(),
    }),
  );

  @override
  Future<StudentLinkResult> revoke({
    required String requestId,
    required String childContextId,
    required String unitId,
    required String reason,
  }) async => _result(
    await _rpc('superadmin_student_revoke', requestId, childContextId, {
      'unit_id': unitId,
      'reason': reason,
    }),
  );

  Future<Map<String, Object?>> _rpc(
    String function,
    String requestId,
    String childContextId,
    Map<String, Object?> payload,
  ) async {
    try {
      final response = await _client.rpc<Object?>(
        function,
        params: {'request_id': requestId, 'child_context_id': childContextId, 'payload': payload},
      );
      return response is Map ? response.cast<String, Object?>() : const <String, Object?>{};
    } on PostgrestException catch (error) {
      throw _translate(error);
    }
  }

  StudentLinkException _translate(PostgrestException error) => switch (error.code) {
    '42501' || 'PGRST301' => const StudentLinkException(
      StudentLinkFailureKind.unauthorized,
      'Seu acesso não permite gerenciar o vínculo deste aluno.',
    ),
    'P0002' || 'PGRST116' => const StudentLinkException(
      StudentLinkFailureKind.notFound,
      'Vínculo indisponível.',
    ),
    '22023' || '23514' => const StudentLinkException(
      StudentLinkFailureKind.invalidInput,
      'Revise os dados do vínculo.',
    ),
    '40001' || '55P03' => const StudentLinkException(
      StudentLinkFailureKind.conflict,
      'O vínculo mudou. Atualize e tente novamente.',
    ),
    _ => StudentLinkException(StudentLinkFailureKind.unavailable, error.message),
  };
}

StudentUnitLink _unitLink(Map<String, Object?> row) => StudentUnitLink(
  unitLinkId: row['unit_link_id']! as String,
  unitId: row['unit_id']! as String,
  unitName: row['unit_name'] as String? ?? '',
  status: row['status'] as String? ?? '',
  acceptedAt: _optionalDate(row['accepted_at']),
  revokedAt: _optionalDate(row['revoked_at']),
  groupLinks: _rows(row['group_links'])
      .map(
        (group) => StudentGroupLink(
          groupLinkId: group['group_link_id']! as String,
          groupId: group['group_id']! as String,
          groupName: group['group_name'] as String? ?? '',
          status: group['status'] as String? ?? '',
          startsAt: _optionalDate(group['starts_at']),
          endsAt: _optionalDate(group['ends_at']),
        ),
      )
      .toList(growable: false),
);

List<Map<String, Object?>> _rows(Object? value) => value is List
    ? value
          .whereType<Map<Object?, Object?>>()
          .map((row) => row.cast<String, Object?>())
          .toList(growable: false)
    : const <Map<String, Object?>>[];

DateTime? _optionalDate(Object? value) =>
    value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;

StudentLinkResult _result(Map<String, Object?> payload) => StudentLinkResult(
  childContextId: payload['child_context_id'] as String? ?? '',
  unitLinkId: payload['unit_link_id'] as String? ?? '',
  groupLinkId: payload['group_link_id'] as String?,
  status: payload['status'] as String? ?? '',
);
