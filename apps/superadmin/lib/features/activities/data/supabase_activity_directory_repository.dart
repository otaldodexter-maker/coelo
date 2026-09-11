import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/activity_directory.dart';

/// Directory reads use the nominal internal v2 contract. Editor reads remain
/// closed until their projections are equivalent; no legacy fallback is used.
final class SupabaseActivityDirectoryRepository implements ActivityDirectoryRepository {
  const SupabaseActivityDirectoryRepository(this._client);

  final SupabaseClient _client;

  Future<T> _unavailable<T>() => Future.error(const ActivityDirectoryUnavailableException());

  @override
  Future<ActivityDirectoryResult> fetchPage(ActivityDirectoryQuery query) async {
    try {
      final data = _v2Data(
        await _client.rpc<Object?>(
          'superadmin_activity_directory_v2',
          params: {
            'p_filters': {
              'search': query.search,
              'institution_ids': query.institutionIds.toList(growable: false),
              'unit_ids': query.unitIds.toList(growable: false),
              'group_ids': query.groupIds.toList(growable: false),
              'statuses': query.statuses
                  .map((value) => value.databaseValue)
                  .toList(growable: false),
              'origins': query.origins.map((value) => value.databaseValue).toList(growable: false),
            },
            'p_limit': query.pageSize,
            'p_offset': query.offset,
            'p_sort': query.sortColumn.name,
            'p_sort_ascending': query.sortAscending,
          },
        ),
      );
      final rows = _v2Rows(data['items']);
      final total = _nonNegativeInt(data['total']);
      if (data['limit'] != query.pageSize ||
          data['offset'] != query.offset ||
          rows.length > query.pageSize ||
          (rows.isNotEmpty && total < query.offset + rows.length)) {
        throw const ActivityDirectoryUnavailableException();
      }
      return ActivityDirectoryResult(
        items: rows.map(_directoryItem).toList(growable: false),
        totalCount: total,
        page: query.page,
        pageSize: query.pageSize,
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    } on ActivityDirectoryUnauthorizedException {
      // A negacao de autorizacao precisa sobreviver ao catch amplo abaixo. Ela
      // e lancada de dentro do parsing, por _v2Data, e e Exception: sem este
      // rethrow ela viraria indisponibilidade e o motivo real se perderia.
      rethrow;
    } on Exception {
      // Cobre resposta malformada E falha de transporte. Antes, apenas
      // FormatException era capturada, entao um ClientException escapava do
      // repositorio e chegava a UI como excecao nao tratada. TypeError e
      // StateError continuam com clausula propria porque sao Error e nao
      // Exception: on Exception nao os captura.
      throw const ActivityDirectoryUnavailableException();
    } on TypeError {
      throw const ActivityDirectoryUnavailableException();
    } on StateError {
      throw const ActivityDirectoryUnavailableException();
    }
  }

  @override
  Future<ActivityFilterOptions> fetchFilterOptions() async {
    try {
      final data = _v2Data(await _client.rpc<Object?>('superadmin_activity_filter_options_v2'));
      return ActivityFilterOptions(
        institutions: _filterOptions(data['institutions']),
        units: _filterOptions(data['units'], requireParent: true),
        groups: _filterOptions(data['groups'], requireParent: true),
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    } on ActivityDirectoryUnauthorizedException {
      // A negacao de autorizacao precisa sobreviver ao catch amplo abaixo. Ela
      // e lancada de dentro do parsing, por _v2Data, e e Exception: sem este
      // rethrow ela viraria indisponibilidade e o motivo real se perderia.
      rethrow;
    } on Exception {
      throw const ActivityDirectoryUnavailableException();
    } on TypeError {
      throw const ActivityDirectoryUnavailableException();
    }
  }

  /// Secoes pedidas ao carregar a etapa "Estrutura e locais". A secao
  /// `taxonomy` fica de fora de proposito: a v2 devolve uma lista plana
  /// (categorias e subtipos misturados, sem `subtypes` e sem "Outros") e o
  /// controller substituiria a arvore carregada por
  /// `superadmin_activity_template_options`, regredindo a etapa Identidade.
  /// Com `taxonomy` vazia o controller preserva a arvore ja carregada, do
  /// mesmo modo que faz com `templates`.
  static const _formOptionSections = ['structure', 'participants', 'professionals'];

  @override
  Future<ActivityFormOptions> fetchFormOptions({required String institutionId}) async {
    try {
      final data = _v2Data(
        await _client.rpc<Object?>(
          'superadmin_activity_form_options_v2',
          params: {
            'p_institution_id': institutionId,
            'p_sections': _formOptionSections,
            'p_limit': _formOptionLimit,
          },
        ),
      );
      final structure = _mapOrEmpty(data['structure']);
      final students = _v2Students(data['participants']);
      final participantCountByGroup = <String, int>{};
      for (final student in students) {
        participantCountByGroup.update(student.groupId, (count) => count + 1, ifAbsent: () => 1);
      }
      return ActivityFormOptions(
        units: _v2Units(structure['units'], institutionId: institutionId),
        groups: _v2Groups(structure['groups'], participantCountByGroup: participantCountByGroup),
        professionals: _v2Professionals(data['professionals']),
        students: students,
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    } on ActivityDirectoryUnauthorizedException {
      // A negacao de autorizacao precisa sobreviver ao catch amplo abaixo. Ela
      // e lancada de dentro do parsing, por _v2Data, e e Exception: sem este
      // rethrow ela viraria indisponibilidade e o motivo real se perderia.
      rethrow;
    } on Exception {
      throw const ActivityDirectoryUnavailableException();
    } on TypeError {
      throw const ActivityDirectoryUnavailableException();
    }
  }

  @override
  Future<List<ActivityFormProfessionalOption>> searchProfessionals({
    required String institutionId,
    required String query,
    int limit = 20,
  }) async {
    try {
      final data = _v2Data(
        await _client.rpc<Object?>(
          'superadmin_activity_form_options_v2',
          params: {
            'p_institution_id': institutionId,
            'p_sections': const ['professionals'],
            'p_search': _v2Search(query),
            'p_limit': limit.clamp(1, _formOptionLimit),
          },
        ),
      );
      return _v2Professionals(data['professionals']);
    } on PostgrestException catch (error) {
      throw _mapError(error);
    } on ActivityDirectoryUnauthorizedException {
      // A negacao de autorizacao precisa sobreviver ao catch amplo abaixo. Ela
      // e lancada de dentro do parsing, por _v2Data, e e Exception: sem este
      // rethrow ela viraria indisponibilidade e o motivo real se perderia.
      rethrow;
    } on Exception {
      throw const ActivityDirectoryUnavailableException();
    } on TypeError {
      throw const ActivityDirectoryUnavailableException();
    }
  }

  /// Secoes pedidas ao abrir a edicao, numa unica chamada. `permissions`
  /// entra junto de proposito: o controller hidrata cada capacidade ausente
  /// como `both`, entao sem as acoes reais um "salvar" da edicao reescreveria
  /// as permissoes de todos os profissionais. Quem pode salvar ja precisa de
  /// `activities.manage_permissions` no save_v2, a mesma capacidade que a
  /// secao exige na leitura.
  static const _detailSections = ['participants', 'professionals', 'permissions'];

  @override
  Future<ActivityDetail?> fetchById(String activityId) async {
    try {
      final envelope = await _client.rpc<Object?>(
        'superadmin_activity_detail_v2',
        params: {'p_activity_id': activityId, 'p_sections': _detailSections},
      );
      // ACTIVITY_NOT_FOUND cobre o id inexistente e o de outro tenant, sem
      // distinguir; a pagina trata `null` como "nao encontrado".
      if (_v2ErrorCode(envelope) == 'ACTIVITY_NOT_FOUND') return null;
      return _v2Detail(_v2Data(envelope), requestedId: activityId);
    } on PostgrestException catch (error) {
      throw _mapError(error);
    } on ActivityDirectoryUnauthorizedException {
      // A negacao de autorizacao precisa sobreviver ao catch amplo abaixo. Ela
      // e lancada de dentro do parsing, por _v2Data, e e Exception: sem este
      // rethrow ela viraria indisponibilidade e o motivo real se perderia.
      rethrow;
    } on Exception {
      throw const ActivityDirectoryUnavailableException();
    } on TypeError {
      throw const ActivityDirectoryUnavailableException();
    } on StateError {
      throw const ActivityDirectoryUnavailableException();
    }
  }

  @override
  Future<ActivityTemplateOptions> fetchTemplateOptions({String? institutionId}) async {
    try {
      final payload = _asMap(
        await _client.rpc<Object?>(
          'superadmin_activity_template_options',
          params: {'p_institution_id': institutionId},
        ),
      );
      return ActivityTemplateOptions(
        institutions: _rows(payload['institutions'])
            .map(
              (row) => ActivityFormInstitutionOption(
                id: row['id'] as String,
                name: row['name'] as String,
              ),
            )
            .toList(growable: false),
        units: _rows(payload['units'])
            .map(
              (row) => ActivityFormUnitOption(
                id: row['id'] as String,
                institutionId: row['institution_id'] as String,
                name: row['name'] as String,
              ),
            )
            .toList(growable: false),
        taxonomy: _taxonomyOptions(payload['taxonomy']),
        templates: _templateOptions(payload['templates']),
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    } on ActivityDirectoryUnauthorizedException {
      // A negacao de autorizacao precisa sobreviver ao catch amplo abaixo. Ela
      // e lancada de dentro do parsing, por _v2Data, e e Exception: sem este
      // rethrow ela viraria indisponibilidade e o motivo real se perderia.
      rethrow;
    } on Exception {
      throw const ActivityDirectoryUnavailableException();
    }
  }
}

Map<String, dynamic> _v2Data(Object? value) {
  final envelope = _asMap(value);
  if (envelope['ok'] == false) {
    final error = _asMap(envelope['error']);
    if (const {
      'SAI_AUTH_REQUIRED',
      'SAI_SESSION_INVALID',
      'SAI_INTERNAL_CONTEXT_DENIED',
      'SAI_MEMBERSHIP_SUSPENDED',
      'SAI_MEMBERSHIP_REVOKED',
      'SAI_PERMISSION_DENIED',
      'SAI_MFA_REQUIRED',
    }.contains(error['code'])) {
      throw const ActivityDirectoryUnauthorizedException();
    }
    throw const ActivityDirectoryUnavailableException();
  }
  if (envelope['ok'] != true || envelope['error'] != null) {
    throw const ActivityDirectoryUnavailableException();
  }
  return _asMap(envelope['data']);
}

List<Map<String, dynamic>> _v2Rows(Object? value) {
  if (value is! List) throw const ActivityDirectoryUnavailableException();
  return value.map(_asMap).toList(growable: false);
}

int _nonNegativeInt(Object? value) {
  if (value is! int || value < 0) throw const ActivityDirectoryUnavailableException();
  return value;
}

String _requiredText(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    throw const ActivityDirectoryUnavailableException();
  }
  return value;
}

ActivityDirectoryItem _directoryItem(Map<String, dynamic> row) {
  // Fail closed against older/incomplete v2 deployments instead of inventing
  // origin, governance, link counts or an empty contextual table.
  for (final key in [
    'id',
    'institution_id',
    'institution_name',
    'name',
    'origin_scope_kind',
    'distribution_scope',
    'governance_kind',
    'status',
    'handle_stem',
    'canonical_handle',
    'updated_at',
  ]) {
    _requiredText(row[key]);
  }
  final unitCount = _nonNegativeInt(row['active_unit_count']);
  final groupCount = _nonNegativeInt(row['active_group_count']);
  if (_nonNegativeInt(row['management_version']) == 0) {
    throw const ActivityDirectoryUnavailableException();
  }
  if (_v2Rows(row['linked_units']).length != unitCount ||
      _v2Rows(row['linked_groups']).length != groupCount) {
    throw const ActivityDirectoryUnavailableException();
  }
  return ActivityDirectoryItem.fromJson(row);
}

List<ActivityFilterOption> _filterOptions(Object? value, {bool requireParent = false}) =>
    _v2Rows(value)
        .map(
          (row) => ActivityFilterOption(
            id: _requiredText(row['id']),
            label: _requiredText(row['label']),
            parentId: requireParent ? _requiredText(row['parent_id']) : null,
          ),
        )
        .toList(growable: false);

List<Map<String, dynamic>> _rows(Object? value) => value is List
    ? value.map((row) => Map<String, dynamic>.from(row as Map)).toList(growable: false)
    : const [];

/// Teto de `p_limit` aceito por `superadmin_activity_form_options_v2`.
const _formOptionLimit = 100;

/// Teto de `p_search` aceito por `superadmin_activity_form_options_v2`.
const _formOptionSearchLength = 120;

Map<String, dynamic> _mapOrEmpty(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

String? _v2Search(String query) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return null;
  return trimmed.length > _formOptionSearchLength
      ? trimmed.substring(0, _formOptionSearchLength)
      : trimmed;
}

// As colecoes abaixo toleram lista ausente (viram vazias), mas uma linha
// presente sem os campos obrigatorios e projecao malformada e falha fechada.
List<ActivityFormUnitOption> _v2Units(Object? value, {required String institutionId}) =>
    _rows(value)
        .map(
          (row) => ActivityFormUnitOption(
            id: _requiredText(row['unit_id']),
            institutionId: institutionId,
            name: _requiredText(row['name']),
          ),
        )
        .toList(growable: false);

List<ActivityFormGroupOption> _v2Groups(
  Object? value, {
  required Map<String, int> participantCountByGroup,
}) => _rows(value)
    .map(
      (row) => ActivityFormGroupOption(
        id: _requiredText(row['group_id']),
        unitId: _requiredText(row['unit_id']),
        name: _requiredText(row['name']),
        participantCount: participantCountByGroup[row['group_id']] ?? 0,
      ),
    )
    .toList(growable: false);

List<ActivityFormStudentOption> _v2Students(Object? value) => _rows(value)
    .map((row) {
      // A RPC nao expoe o id da crianca (minimizacao); o vinculo turma-crianca
      // e o unico identificador que os comandos usam.
      final childGroupLinkId = _requiredText(row['child_group_link_id']);
      return ActivityFormStudentOption(
        childGroupLinkId: childGroupLinkId,
        id: childGroupLinkId,
        groupId: _requiredText(row['group_id']),
        name: _requiredText(row['display_name']),
      );
    })
    .toList(growable: false);

List<ActivityFormProfessionalOption> _v2Professionals(Object? value) => _rows(value)
    .map(
      (row) => ActivityFormProfessionalOption(
        id: _requiredText(row['membership_id']),
        name: _requiredText(row['display_name']),
        role: _requiredText(row['role_code']),
      ),
    )
    .toList(growable: false);

List<ActivityTaxonomyOption> _taxonomyOptions(Object? value) => _rows(value)
    .map(
      (row) => ActivityTaxonomyOption(
        id: row['id'] as String,
        label: row['label'] as String,
        isOther: row['is_other'] as bool? ?? false,
        subtypes: _rows(row['subtypes'])
            .map(
              (subtype) => ActivityTaxonomySubtypeOption(
                id: subtype['id'] as String,
                label: subtype['label'] as String,
              ),
            )
            .toList(growable: false),
      ),
    )
    .toList(growable: false);

List<ActivityTemplateOption> _templateOptions(Object? value) => _rows(value)
    .map(
      (row) => ActivityTemplateOption(
        id: row['id'] as String,
        name: row['name'] as String,
        taxonomyId: row['taxonomy_id'] as String,
        subtypeId: row['subtype_id'] as String?,
        description: row['description'] as String? ?? '',
        scopeKind: ActivityTemplateScopeKind.fromDatabase(
          row['scope_kind'] as String? ?? 'platform',
        ),
        institutionId: row['institution_id'] as String?,
        unitId: row['unit_id'] as String?,
        governance: ActivityGovernance.fromDatabase(
          row['governance_kind'] as String? ?? 'optional',
        ),
        status: ActivityStatus.fromDatabase(row['status'] as String? ?? 'active'),
      ),
    )
    .toList(growable: false);

Exception _mapError(PostgrestException error) => error.code == '42501' || error.code == 'PGRST301'
    ? const ActivityDirectoryUnauthorizedException()
    : const ActivityDirectoryUnavailableException();

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const ActivityDirectoryUnavailableException();
}
