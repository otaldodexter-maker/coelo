import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/plan_catalog.dart';
import '../domain/plan_catalog_repository.dart';

final class SupabasePlanCatalogRepository implements PlanCatalogRepository {
  const SupabasePlanCatalogRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<PlanPage> list(PlanQuery query) async {
    final value = await _rpc('superadmin_plans_list', {
      'p_search': query.search,
      'p_status': query.status?.name,
      'p_feature': query.feature?.name,
      'p_page': query.page,
      'p_page_size': query.pageSize,
    });
    final json = _requiredMap(value);
    return PlanPage(
      items: _requiredList(json['items']).map(_plan).toList(growable: false),
      totalItems: _requiredInt(json, 'total_items'),
      page: _requiredInt(json, 'page'),
      pageSize: _requiredInt(json, 'page_size'),
    );
  }

  @override
  Future<PlanDetails> get(String planId) async =>
      _details(_requiredMap(await _rpc('superadmin_plan_get', {'p_plan_id': planId})));

  @override
  Future<PlanDetails> save(PlanSaveCommand command) async {
    if (command.reason.trim().isEmpty) {
      throw const PlanRepositoryException(
        PlanRepositoryFailureKind.validation,
        'Informe o motivo.',
      );
    }
    final draft = command.draft;
    final entitlements = <String, Object?>{
      for (final feature in PlanFeature.values)
        'feature.${feature.name}': {'enabled': draft.features.contains(feature)},
      'limit.units': {'value': draft.limits.units},
      'limit.memberships': {'value': draft.limits.memberships},
      'limit.storage_gb': {'value': draft.limits.storageGb},
      'limit.media_gb': {'value': draft.limits.mediaGb},
    };
    return _details(
      _requiredMap(
        await _rpc('superadmin_plan_save', {
          'p_request_id': command.requestId,
          'p_plan_id': command.expectedRevision == null ? null : draft.id,
          'p_expected_revision': command.expectedRevision,
          'p_payload': {
            'name': draft.name,
            'code': draft.code,
            'description': draft.description,
            'status': draft.status.name,
            'entitlements': entitlements,
          },
          'p_reason': command.reason.trim(),
        }),
      ),
    );
  }

  Future<Object?> _rpc(String name, Map<String, Object?> params) async {
    try {
      return await _client.rpc<Object?>(name, params: params);
    } on PostgrestException catch (error) {
      final message = error.message;
      throw PlanRepositoryException(
        error.code == '42501'
            ? PlanRepositoryFailureKind.unauthorized
            : error.code == '40001'
            ? PlanRepositoryFailureKind.conflict
            : error.code == '22023'
            ? PlanRepositoryFailureKind.validation
            : PlanRepositoryFailureKind.unavailable,
        message,
      );
    }
  }

  PlanDetails _details(Map<String, Object?> json) => PlanDetails(
    plan: _plan(json),
    linkedInstitutions: _requiredList(json['linked_institutions'])
        .map((value) {
          final item = _requiredMap(value);
          return PlanLinkedInstitution(
            id: _requiredString(item, 'id'),
            name: _requiredString(item, 'name'),
            subscriptionStatus: _requiredString(item, 'subscription_status'),
            startsAt: DateTime.parse(_requiredString(item, 'starts_at')),
            unitsWithOverride: _requiredInt(item, 'units_with_override'),
          );
        })
        .toList(growable: false),
  );

  PlanCatalog _plan(Object? raw) {
    final json = _requiredMap(raw);
    final entitlements = _requiredMap(json['entitlements']);
    bool feature(PlanFeature value) =>
        _requiredMap(entitlements['feature.${value.name}'])['enabled'] == true;
    int limit(String key) => _requiredInt(_requiredMap(entitlements['limit.$key']), 'value');
    return PlanCatalog(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      code: _requiredString(json, 'code'),
      description: _requiredString(json, 'description'),
      status: _status(_requiredString(json, 'status')),
      features: {
        for (final value in PlanFeature.values)
          if (feature(value)) value,
      },
      limits: PlanLimits(
        units: limit('units'),
        memberships: limit('memberships'),
        storageGb: limit('storage_gb'),
        mediaGb: limit('media_gb'),
      ),
      usedByInstitutionCount: _requiredInt(json, 'used_by_institution_count'),
      revision: _requiredInt(json, 'revision'),
    );
  }
}

Map<String, Object?> _requiredMap(Object? value) {
  if (value is Map) return Map<String, Object?>.from(value);
  throw const PlanRepositoryException(
    PlanRepositoryFailureKind.unknown,
    'Resposta de planos inválida.',
  );
}

List<Object?> _requiredList(Object? value) {
  if (value is List) return List<Object?>.from(value);
  throw const PlanRepositoryException(
    PlanRepositoryFailureKind.unknown,
    'Resposta de planos inválida.',
  );
}

String _requiredString(Map<String, Object?> value, String key) {
  final field = value[key];
  if (field is String && field.isNotEmpty) return field;
  throw const PlanRepositoryException(
    PlanRepositoryFailureKind.unknown,
    'Resposta de planos inválida.',
  );
}

int _requiredInt(Map<String, Object?> value, String key) {
  final field = value[key];
  if (field is int) return field;
  final parsed = int.tryParse(field?.toString() ?? '');
  if (parsed != null) return parsed;
  throw const PlanRepositoryException(
    PlanRepositoryFailureKind.unknown,
    'Resposta de planos inválida.',
  );
}

PlanStatus _status(String value) => switch (value) {
  'active' => PlanStatus.active,
  'archived' => PlanStatus.archived,
  _ => throw const PlanRepositoryException(
    PlanRepositoryFailureKind.unknown,
    'Resposta de planos inválida.',
  ),
};
