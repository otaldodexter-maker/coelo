import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/routine_contract.dart';

/// Rotina diária contra o Supabase real.
///
/// As tabelas de rotina usam RLS deny-by-default com FORCE e o cliente só tem
/// SELECT; toda escrita passa por RPC `SECURITY DEFINER` que recalcula ator,
/// capacidade e escopo no servidor. Por isso este arquivo nunca monta consulta
/// direta a tabela: se montasse, estaria pedindo algo que o banco recusaria.
///
/// A negativa de escopo é opaca de propósito: o servidor responde a mesma coisa
/// para um id que não existe e para um id que existe fora do escopo, porque
/// distinguir os dois confirmaria a existência do segundo. Aqui isso vira
/// [RoutineRepositoryFailureKind.notFound] nos dois casos.
final class SupabaseRoutineRepository implements RoutineRepository {
  const SupabaseRoutineRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<RoutineDirectoryPage> fetchPage(RoutineDirectoryQuery query) async {
    final payload = _map(
      await _rpc('superadmin_routine_directory', {
        'entry_kind': _kindToDatabase(query.kind),
        'search': query.search.trim().isEmpty ? null : query.search.trim(),
        'status': query.status,
        'institution_id': query.institutionId,
        'unit_id': query.unitId,
        'group_id': query.groupId,
        'page_limit': query.pageSize,
        // O contrato do cliente pagina a partir de 1; o servidor recebe deslocamento.
        'page_offset': (query.page - 1).clamp(0, 1 << 30) * query.pageSize,
      }),
    );
    final rows = _rows(payload['items']);
    return RoutineDirectoryPage(
      items: rows.map((row) => _directoryItem(query.kind, row)).toList(growable: false),
      page: query.page,
      pageSize: query.pageSize,
      totalCount: _asInt(payload['total']),
      // A capacidade vem no topo do envelope (candidato 20260911220000); o
      // fallback por linha some quando o pacote estiver em producao. Sem isso o
      // diretorio vazio nascia "somente leitura" (F-R04-FCR-009).
      canManage: payload['can_manage'] == true || rows.any((row) => row['can_manage'] == true),
    );
  }

  @override
  Future<RoutineModel> fetchModel(String id) async {
    final payload = _map(await _rpc('superadmin_routine_model_detail', {'model_id': id}));
    final definition = _map(payload['definition']);
    return RoutineModel(
      id: payload['id']! as String,
      name: payload['name'] as String? ?? '',
      description: payload['description'] as String? ?? '',
      version: _asInt(definition['version']),
      versionId: definition['model_version_id'] as String?,
      status: _modelStatus(payload['status'] as String?),
      sections: _rows(definition['sections']).map(_section).toList(growable: false),
      expectedVersion: _asInt(payload['management_version']),
      originScope: payload['origin_unit_id'] == null
          ? RoutineModelOriginScope.institution
          : RoutineModelOriginScope.unit,
      institutionId: payload['institution_id'] as String?,
      originUnitId: payload['origin_unit_id'] as String?,
      canManage: payload['can_manage'] == true,
    );
  }

  @override
  Future<RoutineApplication> fetchApplication(String id) async {
    final payload = _map(
      await _rpc('superadmin_routine_application_detail', {'application_id': id}),
    );
    return RoutineApplication(
      id: payload['id']! as String,
      modelVersionId: payload['source_model_version_id'] as String? ?? '',
      institutionId: payload['institution_id']! as String,
      unitId: payload['unit_id'] as String?,
      groupId: payload['group_id'] as String?,
      parentApplicationId: payload['parent_application_id'] as String?,
      activityId: payload['activity_id'] as String?,
      status: _applicationStatus(payload['status'] as String?),
      inheritanceMode: payload['inheritance_mode'] == 'customized'
          ? RoutineInheritanceMode.customized
          : RoutineInheritanceMode.inherited,
      effectiveVersion: _asInt(payload['effective_version']),
      expectedVersion: _asInt(payload['management_version']),
      validFrom: _optionalDate(payload['valid_from']),
      validUntil: _optionalDate(payload['valid_until']),
      startsAt: payload['starts_at'] as String?,
      endsAt: payload['ends_at'] as String?,
      visibility: payload['visibility'] as String? ?? 'institution',
      assignees: _rows(payload['assignees'])
          .map(
            (row) => RoutineApplicationAssignee(
              membershipId: row['membership_id']! as String,
              responsibility: _responsibility(row['responsibility'] as String?),
            ),
          )
          .toList(growable: false),
      canManage: payload['can_manage'] == true,
    );
  }

  @override
  Future<RoutineLaunch> fetchLaunch(String id) async {
    final payload = _map(await _rpc('superadmin_routine_launch_detail', {'launch_id': id}));
    return RoutineLaunch(
      id: payload['id']! as String,
      applicationId: payload['application_id']! as String,
      applicationRevisionId: payload['application_revision_id'] as String? ?? '',
      institutionId: payload['institution_id']! as String,
      unitId: payload['unit_id'] as String? ?? '',
      groupId: payload['group_id'] as String? ?? '',
      authorMembershipId: payload['author_membership_id'] as String? ?? '',
      serviceDate: _date(payload['launch_date']),
      status: _launchStatus(payload['status'] as String?),
      expectedVersion: _asInt(payload['management_version']),
      children: _rows(payload['children']).map(_childEntry).toList(growable: false),
      canManage: payload['can_manage'] == true,
    );
  }

  @override
  Future<String> saveModel(RoutineModel model, {required String requestId}) async {
    model.validate();
    final saved = _map(
      await _rpc('superadmin_routine_save_model', {
        'request_id': requestId,
        'model_id': model.expectedVersion == 0 ? null : model.id,
        'expected_version': model.expectedVersion,
        'payload': {
          'institution_id': model.institutionId,
          'origin_scope': model.originScope == RoutineModelOriginScope.unit
              ? 'unit'
              : 'institution',
          'origin_unit_id': model.originUnitId,
          'name': model.name,
          'description': model.description,
          'status': _modelStatusToDatabase(model.status),
          'sections': model.sections.map(_sectionJson).toList(growable: false),
        },
      }),
    );
    return saved['id']! as String;
  }

  @override
  Future<String> saveApplication(
    RoutineApplication application, {
    required String requestId,
  }) async {
    application.validate();
    final saved = _map(
      await _rpc('superadmin_routine_save_application', {
        'request_id': requestId,
        'application_id': application.expectedVersion == 0 ? null : application.id,
        'expected_version': application.expectedVersion,
        'payload': {
          'institution_id': application.institutionId,
          'unit_id': application.unitId,
          'group_id': application.groupId,
          'activity_id': application.activityId,
          'scope_kind': _scopeKind(application),
          'source_model_version_id': application.modelVersionId,
          'parent_application_id': application.parentApplicationId,
          'inheritance_mode': application.inheritanceMode == RoutineInheritanceMode.customized
              ? 'customized'
              : 'inherited',
          'visibility': application.visibility,
          'valid_from': _optionalDateOnly(application.validFrom),
          'valid_until': _optionalDateOnly(application.validUntil),
          'starts_at': application.startsAt,
          'ends_at': application.endsAt,
          'status': _applicationStatusToDatabase(application.status),
          'assignees': application.assignees
              .map(
                (assignee) => {
                  'membership_id': assignee.membershipId,
                  'responsibility': assignee.responsibility.name,
                },
              )
              .toList(growable: false),
        },
      }),
    );
    return saved['id']! as String;
  }

  @override
  Future<String> revertApplicationCustomization({
    required String applicationId,
    required int expectedVersion,
    required String requestId,
  }) async {
    final saved = _map(
      await _rpc('superadmin_routine_revert_application', {
        'request_id': requestId,
        'application_id': applicationId,
        'expected_version': expectedVersion,
      }),
    );
    return saved['id']! as String;
  }

  @override
  Future<String> saveLaunchDraft(RoutineLaunch launch, {required String requestId}) async {
    final saved = _map(
      await _rpc('superadmin_routine_save_launch_draft', {
        'request_id': requestId,
        'launch_id': launch.expectedVersion == 0 ? null : launch.id,
        'expected_version': launch.expectedVersion,
        'payload': {
          'application_id': launch.applicationId,
          'launch_date': _dateOnly(launch.serviceDate),
          'entries': launch.children
              .map(
                (child) => {
                  'child_context_id': child.childContextId,
                  'child_group_link_id': child.childGroupLinkId,
                  'status': child.status,
                  'answers': child.answers
                      .map((answer) => {'field_id': answer.fieldId, 'value': answer.value})
                      .toList(growable: false),
                },
              )
              .toList(growable: false),
        },
      }),
    );
    return saved['id']! as String;
  }

  @override
  Future<void> publishLaunch({
    required String launchId,
    required int expectedVersion,
    required String requestId,
  }) async {
    await _rpc('superadmin_routine_publish_launch', {
      'request_id': requestId,
      'launch_id': launchId,
      'expected_version': expectedVersion,
    });
  }

  @override
  Future<void> correctLaunch({
    required String launchId,
    required int expectedVersion,
    required String reason,
    required String requestId,
    required List<RoutineAnswerCorrection> corrections,
  }) async {
    await _rpc('superadmin_routine_correct_launch', {
      'request_id': requestId,
      'launch_id': launchId,
      'expected_version': expectedVersion,
      'reason': reason,
      'payload': corrections
          .map((correction) => {'answer_id': correction.answerId, 'value': correction.value})
          .toList(growable: false),
    });
  }

  Future<Object?> _rpc(String function, Map<String, Object?> params) async {
    try {
      return await _client.rpc<Object?>(function, params: params);
    } on PostgrestException catch (error) {
      throw _translate(error);
    }
  }

  RoutineRepositoryException _translate(PostgrestException error) {
    if (error.code == '42501' || error.code == 'PGRST301') {
      return const RoutineRepositoryException(
        RoutineRepositoryFailureKind.unauthorized,
        'Acesso não autorizado à rotina diária.',
      );
    }
    if (error.code == 'P0002' || error.code == 'PGRST116') {
      return const RoutineRepositoryException(
        RoutineRepositoryFailureKind.notFound,
        'Rotina indisponível.',
      );
    }
    if (error.code == '40001' || error.code == '55P03') {
      return const RoutineRepositoryException(
        RoutineRepositoryFailureKind.conflict,
        'A rotina foi alterada. Atualize e tente novamente.',
      );
    }
    return RoutineRepositoryException(
      RoutineRepositoryFailureKind.unavailable,
      error.message,
    );
  }
}

/// Gera o identificador de intenção de um comando de rotina.
///
/// Diferente de Assiduidade, todo comando de rotina carrega versão esperada,
/// então uma repetição já é recusada como conflito e a chave não precisa ser
/// estável entre tentativas. O `requestId` chega por parâmetro no contrato, e
/// esta função existe só para quem não tiver um.
String newRoutineRequestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}

String _scopeKind(RoutineApplication application) {
  if (application.activityId != null) return 'activity';
  if (application.groupId != null) return 'group';
  if (application.unitId != null) return 'unit';
  return 'institution';
}

RoutineDirectoryItem _directoryItem(RoutineEntryKind kind, Map<String, Object?> row) =>
    RoutineDirectoryItem(
      id: row['id']! as String,
      kind: kind,
      name: switch (kind) {
        RoutineEntryKind.model => row['name'] as String? ?? '',
        RoutineEntryKind.application => row['scope_kind'] as String? ?? '',
        RoutineEntryKind.launch => row['launch_date'] as String? ?? '',
      },
      status: row['status'] as String? ?? '',
      version: _asInt(row['version'] ?? row['management_version']),
      originLabel: row['origin_unit_id'] as String?,
      effectiveLabel: row['inheritance_mode'] as String?,
    );

RoutineSection _section(Map<String, Object?> row) => RoutineSection(
  id: row['id']! as String,
  name: row['name'] as String? ?? '',
  sortOrder: _asInt(row['sort_order']),
  fields: _rows(row['fields']).map(_field).toList(growable: false),
);

RoutineField _field(Map<String, Object?> row) => RoutineField(
  id: row['id']! as String,
  label: row['label'] as String? ?? '',
  kind: _fieldKind(row['kind'] as String?),
  sortOrder: _asInt(row['sort_order']),
  isRequired: row['is_required'] == true,
  initialValue: row['initial_value'],
  minimumValue: row['minimum_value'] as num?,
  maximumValue: row['maximum_value'] as num?,
  options: _rows(row['options'])
      .map(
        (option) => RoutineFieldOption(
          id: option['id']! as String,
          label: option['label'] as String? ?? '',
          sortOrder: _asInt(option['sort_order']),
        ),
      )
      .toList(growable: false),
  conditions: _rows(row['conditions'])
      .map(
        (condition) => RoutineCondition(
          id: condition['id']! as String,
          parentFieldId: condition['parent_field_id']! as String,
          targetFieldId: condition['target_field_id']! as String,
          optionId: condition['option_id'] as String?,
          booleanValue: condition['boolean_value'] as bool?,
          depth: _asInt(condition['depth']),
        ),
      )
      .toList(growable: false),
);

Map<String, Object?> _sectionJson(RoutineSection section) => {
  'id': section.id,
  'name': section.name,
  'sort_order': section.sortOrder,
  'fields': section.fields
      .map(
        (field) => {
          'id': field.id,
          'label': field.label,
          'kind': _fieldKindToDatabase(field.kind),
          'sort_order': field.sortOrder,
          'is_required': field.isRequired,
          'initial_value': field.initialValue,
          'minimum_value': field.minimumValue,
          'maximum_value': field.maximumValue,
          'options': field.options
              .map(
                (option) => {
                  'id': option.id,
                  'label': option.label,
                  'sort_order': option.sortOrder,
                },
              )
              .toList(growable: false),
          'conditions': field.conditions
              .map(
                (condition) => {
                  'id': condition.id,
                  'parent_field_id': condition.parentFieldId,
                  'target_field_id': condition.targetFieldId,
                  'option_id': condition.optionId,
                  'boolean_value': condition.booleanValue,
                  'depth': condition.depth,
                },
              )
              .toList(growable: false),
        },
      )
      .toList(growable: false),
};

RoutineChildEntryDraft _childEntry(Map<String, Object?> row) => RoutineChildEntryDraft(
  entryId: row['entry_id'] as String?,
  childContextId: row['child_context_id']! as String,
  childGroupLinkId: row['child_group_link_id'] as String? ?? '',
  status: row['status'] as String? ?? 'draft',
  answers: _rows(row['answers'])
      .map(
        (answer) => RoutineAnswerDraft(
          fieldId: answer['field_id']! as String,
          value: answer['value'],
        ),
      )
      .toList(growable: false),
);

String _kindToDatabase(RoutineEntryKind kind) => switch (kind) {
  RoutineEntryKind.model => 'model',
  RoutineEntryKind.application => 'application',
  RoutineEntryKind.launch => 'launch',
};

RoutineFieldKind _fieldKind(String? value) => switch (value) {
  'long_text' => RoutineFieldKind.longText,
  'number' => RoutineFieldKind.number,
  'boolean' => RoutineFieldKind.boolean,
  'single_choice' => RoutineFieldKind.singleChoice,
  'multiple_choice' => RoutineFieldKind.multipleChoice,
  _ => RoutineFieldKind.shortText,
};

String _fieldKindToDatabase(RoutineFieldKind kind) => switch (kind) {
  RoutineFieldKind.shortText => 'short_text',
  RoutineFieldKind.longText => 'long_text',
  RoutineFieldKind.number => 'number',
  RoutineFieldKind.boolean => 'boolean',
  RoutineFieldKind.singleChoice => 'single_choice',
  RoutineFieldKind.multipleChoice => 'multiple_choice',
};

RoutineModelStatus _modelStatus(String? value) => switch (value) {
  'active' => RoutineModelStatus.active,
  'inactive' => RoutineModelStatus.inactive,
  'archived' => RoutineModelStatus.archived,
  _ => RoutineModelStatus.draft,
};

String _modelStatusToDatabase(RoutineModelStatus status) => status.name;

RoutineApplicationStatus _applicationStatus(String? value) => switch (value) {
  'active' => RoutineApplicationStatus.active,
  'inactive' => RoutineApplicationStatus.inactive,
  'archived' => RoutineApplicationStatus.archived,
  _ => RoutineApplicationStatus.draft,
};

String _applicationStatusToDatabase(RoutineApplicationStatus status) => status.name;

RoutineLaunchStatus _launchStatus(String? value) => switch (value) {
  'published' => RoutineLaunchStatus.published,
  'corrected' => RoutineLaunchStatus.corrected,
  'cancelled' => RoutineLaunchStatus.cancelled,
  _ => RoutineLaunchStatus.draft,
};

RoutineApplicationResponsibility _responsibility(String? value) => switch (value) {
  'review' => RoutineApplicationResponsibility.review,
  'publish' => RoutineApplicationResponsibility.publish,
  _ => RoutineApplicationResponsibility.record,
};

Map<String, Object?> _map(Object? value) =>
    value is Map ? value.cast<String, Object?>() : const <String, Object?>{};

List<Map<String, Object?>> _rows(Object? value) => value is List
    ? value.whereType<Map<Object?, Object?>>().map(_map).toList(growable: false)
    : const <Map<String, Object?>>[];

int _asInt(Object? value) => switch (value) {
  final num number => number.toInt(),
  final String text => int.tryParse(text) ?? 0,
  _ => 0,
};

DateTime _date(Object? value) => _optionalDate(value) ?? DateTime.utc(1970);

DateTime? _optionalDate(Object? value) =>
    value is String && value.isNotEmpty ? DateTime.parse(value) : null;

String? _optionalDateOnly(DateTime? value) => value == null ? null : _dateOnly(value);

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
