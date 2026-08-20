import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/meal_plan_repository.dart';

final class SupabaseMealPlanRepository implements MealPlanRepository {
  const SupabaseMealPlanRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<MealPlanPage> fetchPage(MealPlanListFilter filter) async {
    final p = _json(await _rpc('meal_plan_list', {'p_query': filter.toJson()}));
    return MealPlanPage(items: _plans(p['items']), total: _int(p['total']) ?? 0,
      limit: _int(p['limit']) ?? filter.pageSize, offset: _int(p['offset']) ?? filter.offset);
  }
  @override
  Future<MealPlanPage> fetchTemplatePage(MealPlanListFilter filter) async {
    final p = _json(await _rpc('meal_plan_template_list', {'p_query': filter.toJson()}));
    final items = _list(p['items']).map((v) =>
      MealPlanTemplate.fromJson(_json(v)).toDirectoryItem()).toList();
    return MealPlanPage(items: items, total: _int(p['total']) ?? items.length,
      limit: _int(p['limit']) ?? filter.pageSize, offset: _int(p['offset']) ?? filter.offset);
  }
  @override
  Future<MealPlan> getById(String id) async =>
    MealPlan.fromJson(_json(await _rpc('meal_plan_get', {'p_meal_plan_id': id})));
  @override
  Future<MealPlanTemplate> getTemplateById(String id) async =>
    MealPlanTemplate.fromJson(_json(await _rpc('meal_plan_template_get', {'p_template_id': id})));
  @override
  Future<MealPlanTemplate> saveTemplate(MealPlanTemplateDraft draft, {required bool publish}) async =>
    MealPlanTemplate.fromJson(_json(await _rpc('meal_plan_template_save', {
      'p_template_id': draft.id, 'p_payload': draft.toJson(),
      'p_expected_version': draft.expectedVersion, 'p_publish': publish,
    })));
  @override
  Future<MealPlanAudienceOptions> fetchAudienceOptions() async =>
    MealPlanAudienceOptions.fromJson(_json(await _rpc('meal_plan_audience_options', const {})));
  @override
  Future<MealPlan> createOrUpdateDraft(MealPlanDraft draft) async =>
    MealPlan.fromJson(_json(await _rpc('meal_plan_create_or_update_draft', {
      'p_request_id': draft.requestId ?? _requestId(), 'p_payload': draft.toJson(),
      'p_meal_plan_id': draft.mealPlanId, 'p_expected_revision': draft.expectedRevision,
    })));
  @override
  Future<MealPlan> submitForReview(String id, String requestId, int revision) async =>
    MealPlan.fromJson(_json(await _rpc('meal_plan_submit_for_review', {
      'p_request_id': requestId, 'p_meal_plan_id': id, 'p_expected_revision': revision,
    })));
  @override
  Future<MealPlan> publish(String id, String requestId, int revision) async =>
    MealPlan.fromJson(_json(await _rpc('meal_plan_publish', {
      'p_request_id': requestId, 'p_meal_plan_id': id, 'p_expected_revision': revision,
    })));
  @override
  Future<List<MealPlanConflict>> checkConflicts({
    required String scopeLevel, required String scopeId, required DateTime startDate,
    required DateTime endDate, required MealPlanRecurrence recurrence,
    required List<MealPlanMenuEntry> menu,
  }) async {
    final p = _json(await _rpc('meal_plan_conflicts_check', {
      'p_scope_level': scopeLevel, 'p_scope_id': scopeId,
      'p_start_date': startDate.toIso8601String(), 'p_end_date': endDate.toIso8601String(),
      'p_recurrence': recurrence.toJson(), 'p_menu': menu.map((v) => v.toJson()).toList(),
    }));
    return _list(p['conflicts']).map((v) => MealPlanConflict.fromJson(_json(v))).toList();
  }
  @override
  Future<MealPlan> fetchEffectiveSnapshot(MealPlanDraft draft) async =>
    MealPlan.fromJson(_json(await _rpc('meal_plan_effective_snapshot', {'p_payload': draft.toJson()})));

  Future<Object?> _rpc(String name, Map<String, Object?> params) async {
    try {
      return await _client.rpc<Object?>(name, params: params);
    } on PostgrestException catch (e) {
      throw switch (e.code) {
        '42501' || 'PGRST301' => const MealPlanUnauthorizedException(),
        'P0002' || 'PGRST116' => const MealPlanNotFoundException(),
        '409' || 'P0003' || '22023' => MealPlanConflictException(e.message),
        _ => MealPlanUnavailableException(e.message),
      };
    }
  }
  List<MealPlan> _plans(Object? v) =>
    _list(v).map((x) => MealPlan.fromJson(_json(x))).toList();
  String _requestId() {
    final r = DateTime.now().microsecondsSinceEpoch.toRadixString(16).padLeft(32, '0');
    return r.substring(0, 8) + '-' + r.substring(8, 12) + '-' + r.substring(12, 16) +
      '-' + r.substring(16, 20) + '-' + r.substring(20, 32);
  }
}
Map<String, Object?> _json(Object? v) => Map<String, Object?>.from(v as Map);
List<Object?> _list(Object? v) => List<Object?>.from(v as List? ?? const []);
int? _int(Object? v) => v == null ? null : int.tryParse(v.toString());
