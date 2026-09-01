import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/health_care.dart';
import '../domain/health_care_repository.dart';

final class SupabaseHealthCareRepository implements HealthCareRepository {
  SupabaseHealthCareRepository(
    this._client, {
    HealthCareActor? actor,
    HealthCareActor? Function()? actorProvider,
  }) : _actor = actor,
       _actorProvider = actorProvider;

  final SupabaseClient _client;
  final HealthCareActor? _actor;
  final HealthCareActor? Function()? _actorProvider;
  final Map<String, int> _versions = {};
  final Map<String, String> _profileByChild = {};

  @override
  HealthCareActor? get defaultActor => _actorProvider?.call() ?? _actor;

  HealthCareActor get _authenticatedActor =>
      defaultActor ?? (throw StateError('Contexto autenticado de Saúde e Cuidado indisponível.'));

  @override
  Future<HealthCareDirectoryPage> fetchDirectory(
    HealthCareDirectoryQuery query, {
    required HealthCareActor actor,
  }) async {
    final data = await _rpc('superadmin_care_profile_directory_v2', {
      'p_search': query.search.trim(),
      'p_institution_ids': query.institutionIds.toList(growable: false),
      'p_unit_ids': query.unitIds.toList(growable: false),
      'p_statuses': query.operationalStatuses.map((value) => value.name).toList(growable: false),
      'p_offset': query.offset,
      'p_limit': query.pageSize,
    });
    final rows = data['items'] as List<dynamic>? ?? const [];
    final items = rows
        .map((row) {
          final item = Map<String, dynamic>.from(row as Map);
          final profileId = item['profile_id'] as String;
          final childPersonId = item['child_person_id'] as String;
          _versions[profileId] = (item['current_version'] as num).toInt();
          _profileByChild[childPersonId] = profileId;
          return HealthCareChildSummary(
            id: profileId,
            personId: childPersonId,
            displayName: item['display_name'] as String,
            operationalStatus: _status(item['operational_status'] as String),
            medicationCount: 0,
            activeAllergyCount: 0,
            pendingAcknowledgementCount: 0,
          );
        })
        .toList(growable: false);
    return HealthCareDirectoryPage(
      items: items,
      totalCount: (data['total'] as num?)?.toInt() ?? items.length,
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  @override
  Future<HealthCareChild?> findChild(String profileId, {required HealthCareActor actor}) async {
    final data = await _rpc('superadmin_care_profile_detail_v2', {'p_profile_id': profileId});
    return _child(data);
  }

  Future<List<({String id, String label})>> fetchChildOptions({String search = ''}) async {
    final data = await _rpc('superadmin_care_profile_child_options_v2', {
      'p_search': search.trim(),
      'p_limit': 100,
    });
    final rows = data['items'] as List<dynamic>? ?? const [];
    return rows
        .map((row) => Map<String, dynamic>.from(row as Map))
        .map((row) => (id: row['child_person_id'] as String, label: row['display_name'] as String))
        .toList(growable: false);
  }

  Future<HealthCareProfileDraft?> loadCareProfileDraft(String profileId) async {
    final child = await findChild(profileId, actor: _authenticatedActor);
    if (child == null) return null;
    return HealthCareProfileDraft(
      childId: child.personId,
      careItemIds: child.careProfile.map((item) => item.catalogItemId).toSet(),
    );
  }

  Future<void> saveCareProfileDraft(HealthCareProfileDraft draft) => updateCareProfile(
    childId: draft.childId,
    items: [for (final id in draft.careItemIds) HealthCareProfileItem(catalogItemId: id)],
    justification: draft.justification,
    actor: _authenticatedActor,
  );

  @override
  Future<HealthCareAcknowledgement> updateCareProfile({
    required String childId,
    required List<HealthCareProfileItem> items,
    required String justification,
    required HealthCareActor actor,
  }) async {
    final profileId = _profileByChild[childId] ?? (childId.startsWith('profile-') ? childId : null);
    final payload = {
      'operational_status': 'active',
      'items': [
        for (final (position, item) in items.indexed)
          {
            'catalog_item_id': item.catalogItemId,
            'other_text': item.otherText,
            'position': position,
          },
      ],
      'justification': justification.trim(),
    };
    final data = profileId == null
        ? await _rpc('superadmin_create_care_profile_v2', {
            'p_request_id': _newUuid(),
            'p_child_person_id': childId,
            'p_expected_version': 0,
            'p_payload': payload,
          })
        : await _rpc('superadmin_edit_care_profile_v2', {
            'p_request_id': _newUuid(),
            'p_profile_id': profileId,
            'p_expected_version': _versions[profileId] ?? 1,
            'p_payload': payload,
          });
    final savedProfileId = (data['profile_id'] as String?) ?? profileId!;
    final version = (data['current_version'] as num?)?.toInt() ?? 1;
    _versions[savedProfileId] = version;
    _profileByChild[childId] = savedProfileId;
    return HealthCareAcknowledgement(
      id: savedProfileId,
      childId: childId,
      subject: HealthCareAcknowledgementSubject.careProfile,
      createdAt: DateTime.now().toUtc(),
    );
  }

  HealthCareChild _child(Map<String, dynamic> data) {
    final profileId = data['profile_id'] as String;
    final childPersonId = data['child_person_id'] as String;
    _versions[profileId] = (data['current_version'] as num).toInt();
    _profileByChild[childPersonId] = profileId;
    final contexts = data['contexts'] as List<dynamic>? ?? const [];
    final profileItems = data['items'] as List<dynamic>? ?? const [];
    return HealthCareChild(
      id: profileId,
      personId: childPersonId,
      displayName: data['display_name'] as String,
      operationalStatus: _status(data['operational_status'] as String),
      links: contexts
          .map((row) {
            final context = Map<String, dynamic>.from(row as Map);
            return HealthCareContextLink(
              institutionId: context['institution_id'] as String,
              unitId: context['unit_id'] as String?,
            );
          })
          .toList(growable: false),
      careProfile: profileItems
          .map((row) {
            final item = Map<String, dynamic>.from(row as Map);
            return HealthCareProfileItem(
              catalogItemId: item['catalog_item_id'] as String,
              otherText: item['other_text'] as String?,
            );
          })
          .toList(growable: false),
    );
  }

  Future<Map<String, dynamic>> _rpc(String function, Map<String, Object?> params) async {
    try {
      final response = await _client.rpc<Object?>(function, params: params);
      final envelope = Map<String, dynamic>.from(response as Map);
      if (envelope['ok'] != true) throw _exception(envelope['error']);
      return Map<String, dynamic>.from(envelope['data'] as Map);
    } on PostgrestException catch (error) {
      throw error.code == '42501'
          ? StateError('Acesso não autorizado.')
          : StateError('Saúde e cuidado estão indisponíveis.');
    }
  }

  Object _exception(Object? raw) {
    final error = Map<String, dynamic>.from(raw as Map? ?? const {});
    return switch (error['code']) {
      'SAI_PERMISSION_DENIED' || 'SAI_MFA_REQUIRED' => StateError('Acesso não autorizado.'),
      'SAI_CONCURRENT_CHANGE' ||
      'SAI_REQUEST_REUSED' => StateError('O perfil foi alterado. Recarregue e tente novamente.'),
      _ => StateError('Saúde e cuidado estão indisponíveis.'),
    };
  }

  HealthCareOperationalStatus _status(String value) => switch (value) {
    'implementation' => HealthCareOperationalStatus.implementation,
    'inactive' => HealthCareOperationalStatus.inactive,
    _ => HealthCareOperationalStatus.active,
  };

  Never _unsupported() => throw StateError('Operação indisponível neste módulo.');

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
  }) async => _unsupported();

  @override
  Future<HealthMedicationChangeResult> changeMedicationRelevant({
    required String childId,
    required String medicationId,
    required String name,
    required String justification,
    required HealthCareActor actor,
  }) async => _unsupported();

  @override
  Future<HealthCareAllergy> createAllergy({
    required String childId,
    required String label,
    required HealthCareAllergyType type,
    required HealthCareActor actor,
  }) async => _unsupported();

  @override
  Future<HealthCareAcknowledgement> deactivateAllergy({
    required String childId,
    required String allergyId,
    required String justification,
    required HealthCareActor actor,
  }) async => _unsupported();
}

String _newUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
