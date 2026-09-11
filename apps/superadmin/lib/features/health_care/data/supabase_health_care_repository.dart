import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/health_care.dart';
import '../domain/health_care_repository.dart';

/// Perfis de cuidado contra o Supabase real.
///
/// Duas observações sobre o contrato desta interface, que nasceu para o
/// repositório de `/dev` e por isso carrega coisas que um cliente produtivo não
/// pode carregar:
///
/// 1. O [HealthCareActor] chega por parâmetro. Aqui ele serve apenas para a
///    tela decidir o que desenhar. **Nenhuma autorização é feita com ele**: o
///    ator real é derivado da sessão dentro das RPCs, e o servidor recalcula
///    capacidade, tenant e vínculo em toda leitura e escrita. Um ator forjado
///    no cliente não muda o que o banco devolve.
/// 2. Medicação não vive dentro do perfil de cuidado. A spec 020 diz que os
///    destinos são irmãos e que o perfil não incorpora doses, e o backend
///    seguiu isso: plano de medicação é um agregado próprio, com comandos
///    próprios, servido por [SupabaseMedicationPlanRepository]. Os dois métodos
///    de medicação desta interface falham fechados com o motivo explícito, em
///    vez de fingir que escrevem.
final class SupabaseHealthCareRepository implements HealthCareRepository {
  const SupabaseHealthCareRepository(this._client);

  final SupabaseClient _client;

  /// O ator produtivo é sempre o da sessão; não há ator padrão para o cliente
  /// escolher.
  @override
  HealthCareActor? get defaultActor => null;

  @override
  Future<HealthCareDirectoryPage> fetchDirectory(
    HealthCareDirectoryQuery query, {
    required HealthCareActor actor,
  }) async {
    final payload = _map(
      await _rpc('superadmin_health_care_directory', {
        'search': query.search.trim().isEmpty ? null : query.search.trim(),
        'statuses': query.operationalStatuses.isEmpty
            ? null
            : query.operationalStatuses.map(_statusToDatabase).toList(growable: false),
        'institution_id': _single(query.institutionIds),
        'unit_id': _single(query.unitIds),
        'group_id': _single(query.groupOrActivityIds),
        'page_limit': query.pageSize,
        'page_offset': query.page * query.pageSize,
      }),
    );
    return HealthCareDirectoryPage(
      items: _rows(payload['items']).map(_summary).toList(growable: false),
      totalCount: _asInt(payload['total']),
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  @override
  Future<HealthCareChild?> findChild(String childId, {required HealthCareActor actor}) async {
    final Object? payload;
    try {
      payload = await _rpc('superadmin_health_care_profile_detail', {'profile_id': childId});
    } on StateError {
      // Negativa opaca do servidor: perfil inexistente e perfil fora do escopo
      // respondem a mesma coisa, porque distinguir confirmaria a existência.
      return null;
    }
    if (payload == null) return null;
    return _child(_map(payload));
  }

  @override
  Future<HealthCareAcknowledgement> updateCareProfile({
    required String childId,
    required List<HealthCareProfileItem> items,
    required String justification,
    required HealthCareActor actor,
  }) async {
    final saved = _map(
      await _rpc('superadmin_health_care_save_profile', {
        'request_id': _requestId(),
        'profile_id': childId,
        'expected_version': await _currentVersion(childId),
        'payload': {
          'subject': 'care_profile',
          'justification': justification,
          'items': items
              .map((item) => {'catalog_item_id': item.catalogItemId, 'other_text': item.otherText})
              .toList(growable: false),
        },
      }),
    );
    return _acknowledgement(childId, HealthCareAcknowledgementSubject.careProfile, saved);
  }

  @override
  Future<HealthCareAllergy> createAllergy({
    required String childId,
    required String label,
    required HealthCareAllergyType type,
    required HealthCareActor actor,
  }) async {
    await _rpc('superadmin_health_care_save_profile', {
      'request_id': _requestId(),
      'profile_id': childId,
      'expected_version': await _currentVersion(childId),
      'payload': {
        'subject': 'allergy_or_restriction',
        'justification': 'Inclusão de alergia ou restrição.',
        'allergies': [
          {'label': label, 'allergy_type': _allergyTypeToDatabase(type), 'status': 'active'},
        ],
      },
    });
    final child = await findChild(childId, actor: actor);
    final created = child?.allergies.where((allergy) => allergy.label == label);
    if (created == null || created.isEmpty) {
      throw StateError('A alergia não foi confirmada pelo servidor.');
    }
    return created.last;
  }

  @override
  Future<HealthCareAcknowledgement> deactivateAllergy({
    required String childId,
    required String allergyId,
    required String justification,
    required HealthCareActor actor,
  }) async {
    final saved = _map(
      await _rpc('superadmin_health_care_save_profile', {
        'request_id': _requestId(),
        'profile_id': childId,
        'expected_version': await _currentVersion(childId),
        'payload': {
          'subject': 'allergy_or_restriction',
          'justification': justification,
          'allergies': [
            {'id': allergyId, 'active': false, 'status': 'history'},
          ],
        },
      }),
    );
    return _acknowledgement(childId, HealthCareAcknowledgementSubject.allergyOrRestriction, saved);
  }

  // Medicação é um agregado irmão, não parte do perfil (spec 020). Falhar
  // fechado com o motivo é honesto; escrever no perfil seria inventar um
  // caminho que o backend não tem.
  @override
  Future<HealthMedication> createMedication({
    required String childId,
    required String name,
    required String dose,
    required String doseUnit,
    required String route,
    required DateTime startsAt,
    required DateTime endsAt,
    required List<HealthMedicationSchedule> schedules,
    String? documentName,
    String? documentType,
    required HealthCareActor actor,
  }) async => _medicationLivesElsewhere();

  @override
  Future<HealthMedicationChangeResult> changeMedicationRelevant({
    required String childId,
    required String medicationId,
    required String name,
    required String justification,
    required HealthCareActor actor,
  }) async => _medicationLivesElsewhere();

  Never _medicationLivesElsewhere() => throw StateError(
    'Medicação é um plano próprio: use Planos de medicação, não o perfil de cuidado.',
  );

  /// Cria o perfil de cuidado de uma criança. [HealthCareProfileDraft.childId]
  /// é o contexto infantil (a instituição é derivada dele no servidor);
  /// devolve o id do perfil criado.
  Future<String> createCareProfile(HealthCareProfileDraft draft) async {
    final saved = _map(
      await _rpc('superadmin_health_care_save_profile', {
        'request_id': _requestId(),
        'profile_id': null,
        'expected_version': 0,
        'payload': {'child_context_id': draft.childId, ..._draftPayload(draft, null)},
      }),
    );
    return saved['id']! as String;
  }

  /// Edita um perfil existente. Aqui [HealthCareProfileDraft.childId] é o id
  /// do perfil (a rota de edição carrega por perfil), e a versão esperada vem
  /// da mesma leitura que informa a alergia ativa a atualizar.
  Future<void> saveCareProfileDraft(HealthCareProfileDraft draft) async {
    final detail = _map(
      await _rpc('superadmin_health_care_profile_detail', {'profile_id': draft.childId}),
    );
    final activeAllergy = _rows(
      detail['allergies'],
    ).where((row) => row['active'] as bool? ?? true).firstOrNull;
    await _rpc('superadmin_health_care_save_profile', {
      'request_id': _requestId(),
      'profile_id': draft.childId,
      'expected_version': _asInt(detail['management_version']),
      'payload': _draftPayload(draft, activeAllergy?['id'] as String?),
    });
  }

  /// Lê o perfil na forma que o formulário de edição consome; `null` quando o
  /// servidor nega (negativa opaca, sem confirmar existência).
  Future<HealthCareProfileDraft?> loadCareProfileDraft(String profileId) async {
    final Object? payload;
    try {
      payload = await _rpc('superadmin_health_care_profile_detail', {'profile_id': profileId});
    } on StateError {
      return null;
    }
    final detail = _map(payload);
    if (detail.isEmpty) return null;
    final allergy = _rows(
      detail['allergies'],
    ).where((row) => row['active'] as bool? ?? true).firstOrNull;
    final lastEpisode = allergy?['last_episode_at'] as String?;
    return HealthCareProfileDraft(
      childId: profileId,
      careItemIds: {for (final row in _rows(detail['items'])) row['catalog_item_id']! as String},
      importantSigns: detail['important_signs'] as String? ?? '',
      adaptations: detail['adaptations'] as String? ?? '',
      allergyType: allergy == null
          ? HealthCareAllergyType.food
          : _allergyTypeFromDatabase(allergy['allergy_type'] as String?),
      allergyStatus: allergy == null
          ? HealthCareAllergyStatus.active
          : _allergyStatusFromDatabase(allergy['status'] as String?),
      severity: allergy == null
          ? HealthCareEpisodeSeverity.moderate
          : _severityFromDatabase(allergy['episode_severity'] as String?) ??
                HealthCareEpisodeSeverity.moderate,
      lastEpisode: lastEpisode == null ? '' : lastEpisode.substring(0, 10),
      observedReaction: allergy?['observed_reaction'] as String? ?? '',
      allergyGuidance: allergy?['guidance'] as String? ?? '',
      allergyNotes: allergy?['notes'] as String? ?? '',
    );
  }

  /// A versão esperada vem de uma leitura autorizada imediatamente antes da
  /// escrita. O servidor recusa a escrita se a versão tiver mudado, então uma
  /// leitura obsoleta vira conflito, nunca sobrescrita silenciosa.
  Future<int> _currentVersion(String profileId) async {
    final payload = _map(
      await _rpc('superadmin_health_care_profile_detail', {'profile_id': profileId}),
    );
    return _asInt(payload['management_version']);
  }

  Future<Object?> _rpc(String function, Map<String, Object?> params) async {
    try {
      return await _client.rpc<Object?>(function, params: params);
    } on PostgrestException catch (error) {
      if (error.code == '42501' || error.code == 'PGRST301') {
        throw StateError('Acesso não autorizado a saúde e cuidado.');
      }
      if (error.code == 'P0002' || error.code == 'PGRST116') {
        throw StateError('Perfil de cuidado indisponível.');
      }
      if (error.code == '40001' || error.code == '55P03') {
        throw StateError('O perfil foi alterado. Atualize e tente novamente.');
      }
      if (error.code == '23514' || error.code == '23502' || error.code == '22023') {
        throw StateError('Informe a justificativa e os dados obrigatórios do perfil.');
      }
      throw StateError('Saúde e cuidado estão indisponíveis.');
    }
  }
}

/// Corpo do comando de salvar a partir do rascunho do formulário. A alergia só
/// entra quando o formulário descreveu alguma; com [activeAllergyId] ela
/// atualiza a alergia ativa em vez de criar outra.
Map<String, Object?> _draftPayload(HealthCareProfileDraft draft, String? activeAllergyId) {
  final describesAllergy = [
    draft.lastEpisode,
    draft.observedReaction,
    draft.allergyGuidance,
    draft.allergyNotes,
  ].any((value) => value.trim().isNotEmpty);
  final lastEpisode = DateTime.tryParse(draft.lastEpisode.trim());
  return {
    'subject': 'care_profile',
    'justification': draft.justification,
    'important_signs': draft.importantSigns,
    'adaptations': draft.adaptations,
    'items': [
      for (final id in draft.careItemIds) {'catalog_item_id': id, 'other_text': null},
    ],
    if (describesAllergy)
      'allergies': [
        {
          'id': ?activeAllergyId,
          'label': _allergyTypeLabel(draft.allergyType),
          'allergy_type': _allergyTypeToDatabase(draft.allergyType),
          'status': _allergyStatusToDatabase(draft.allergyStatus),
          'active': true,
          if (lastEpisode != null) 'last_episode_at': lastEpisode.toUtc().toIso8601String(),
          'episode_severity': _severityToDatabase(draft.severity),
          'observed_reaction': draft.observedReaction,
          'guidance': draft.allergyGuidance,
          'notes': draft.allergyNotes,
        },
      ],
  };
}

String _allergyTypeLabel(HealthCareAllergyType type) => switch (type) {
  HealthCareAllergyType.medication => 'Alergia a medicamento',
  HealthCareAllergyType.food => 'Alergia alimentar',
  HealthCareAllergyType.restriction => 'Restrição',
  HealthCareAllergyType.other => 'Outra alergia',
};

String _allergyStatusToDatabase(HealthCareAllergyStatus status) => switch (status) {
  HealthCareAllergyStatus.active => 'active',
  HealthCareAllergyStatus.monitoring => 'monitoring',
  HealthCareAllergyStatus.history => 'history',
};

String _severityToDatabase(HealthCareEpisodeSeverity severity) => switch (severity) {
  HealthCareEpisodeSeverity.mild => 'mild',
  HealthCareEpisodeSeverity.moderate => 'moderate',
  HealthCareEpisodeSeverity.severe => 'severe',
};

/// Identificador de intenção (UUID v4) para comandos de Saúde e Cuidado que
/// nascem fora deste repositório, como o plano de medicação.
String newHealthCareRequestId() => _requestId();

HealthCareChildSummary _summary(Map<String, Object?> row) => HealthCareChildSummary(
  id: row['id']! as String,
  personId: row['child_person_id'] as String?,
  displayName: row['display_name'] as String? ?? '',
  operationalStatus: _statusFromDatabase(row['operational_status'] as String?),
  medicationCount: _asInt(row['medication_count']),
  activeAllergyCount: _asInt(row['active_allergy_count']),
  pendingAcknowledgementCount: 0,
);

HealthCareChild _child(Map<String, Object?> payload) {
  final profileId = payload['id']! as String;
  return HealthCareChild(
    id: profileId,
    personId: payload['child_person_id'] as String? ?? '',
    displayName: payload['display_name'] as String? ?? '',
    operationalStatus: _statusFromDatabase(payload['operational_status'] as String?),
    allergies: _rows(
      payload['allergies'],
    ).map((row) => _allergy(profileId, row)).toList(growable: false),
    careProfile: _rows(payload['items']).map(_profileItem).toList(growable: false),
  );
}

HealthCareProfileItem _profileItem(Map<String, Object?> row) => HealthCareProfileItem(
  catalogItemId: row['catalog_item_id']! as String,
  otherText: row['other_text'] as String?,
);

HealthCareAllergy _allergy(String childId, Map<String, Object?> row) => HealthCareAllergy(
  id: row['id']! as String,
  childId: childId,
  label: row['label'] as String? ?? '',
  type: _allergyTypeFromDatabase(row['allergy_type'] as String?),
  active: row['active'] as bool? ?? true,
  status: _allergyStatusFromDatabase(row['status'] as String?),
  lastEpisodeAt: _optionalDate(row['last_episode_at']),
  episodeSeverity: _severityFromDatabase(row['episode_severity'] as String?),
  observedReaction: row['observed_reaction'] as String? ?? '',
  guidance: row['guidance'] as String? ?? '',
  notes: row['notes'] as String? ?? '',
  inactivatedAt: _optionalDate(row['inactivated_at']),
);

/// O recibo de ciência do servidor é a revisão gravada com justificativa.
HealthCareAcknowledgement _acknowledgement(
  String childId,
  HealthCareAcknowledgementSubject subject,
  Map<String, Object?> saved,
) => HealthCareAcknowledgement(
  id: '${saved['id']}:${saved['revision']}',
  childId: childId,
  subject: subject,
  createdAt: DateTime.now().toUtc(),
);

String _statusToDatabase(HealthCareOperationalStatus status) => switch (status) {
  HealthCareOperationalStatus.active => 'active',
  HealthCareOperationalStatus.implementation => 'implementation',
  HealthCareOperationalStatus.inactive => 'inactive',
};

HealthCareOperationalStatus _statusFromDatabase(String? value) => switch (value) {
  'active' => HealthCareOperationalStatus.active,
  'inactive' => HealthCareOperationalStatus.inactive,
  _ => HealthCareOperationalStatus.implementation,
};

String _allergyTypeToDatabase(HealthCareAllergyType type) => switch (type) {
  HealthCareAllergyType.medication => 'medication',
  HealthCareAllergyType.food => 'food',
  HealthCareAllergyType.restriction => 'restriction',
  HealthCareAllergyType.other => 'other',
};

HealthCareAllergyType _allergyTypeFromDatabase(String? value) => switch (value) {
  'medication' => HealthCareAllergyType.medication,
  'food' => HealthCareAllergyType.food,
  'restriction' => HealthCareAllergyType.restriction,
  _ => HealthCareAllergyType.other,
};

HealthCareAllergyStatus _allergyStatusFromDatabase(String? value) => switch (value) {
  'monitoring' => HealthCareAllergyStatus.monitoring,
  'history' => HealthCareAllergyStatus.history,
  _ => HealthCareAllergyStatus.active,
};

HealthCareEpisodeSeverity? _severityFromDatabase(String? value) => switch (value) {
  'mild' => HealthCareEpisodeSeverity.mild,
  'moderate' => HealthCareEpisodeSeverity.moderate,
  'severe' => HealthCareEpisodeSeverity.severe,
  _ => null,
};

String? _single(Set<String> values) => values.length == 1 ? values.single : null;

/// O `request_id` identifica a intenção do comando para o recibo do servidor.
/// Aqui ele é por tentativa: diferente de Assiduidade, estes comandos carregam
/// versão esperada, então uma repetição já é recusada como conflito.
String _requestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}

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

DateTime? _optionalDate(Object? value) =>
    value is String && value.isNotEmpty ? DateTime.parse(value) : null;
