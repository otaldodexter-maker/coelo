import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/activity_read_detail.dart';

class SupabaseActivityReadDetailRepository implements ActivityReadDetailRepository {
  const SupabaseActivityReadDetailRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<ActivityReadDetail> fetchById(String activityId) async {
    if (!isActivityReadDetailId(activityId)) {
      throw const ActivityReadDetailException(ActivityReadDetailFailure.invalidId);
    }
    try {
      final value = await _client.rpc<Object?>(
        'superadmin_activity_detail_v2',
        params: {'p_activity_id': activityId, 'p_sections': <String>[]},
      );
      if (value is! Map ||
          value.length != 3 ||
          !const ['ok', 'data', 'error'].every(value.containsKey) ||
          value['ok'] is! bool) {
        throw const FormatException('Invalid envelope');
      }
      if (value['ok'] == false) {
        final error = value['error'];
        if (value['data'] != null ||
            error is! Map ||
            error.length != 4 ||
            !const ['code', 'message', 'correlation_id', 'http_status'].every(error.containsKey) ||
            error['code'] is! String ||
            (error['code'] as String).trim().isEmpty ||
            error['message'] is! String ||
            error['correlation_id'] is! String ||
            !isActivityReadDetailId(error['correlation_id'] as String) ||
            error['http_status'] is! int ||
            (error['http_status'] as int) < 400 ||
            (error['http_status'] as int) > 599) {
          throw const FormatException('Invalid error envelope');
        }
        final denied = _denials.contains(error['code']);
        throw ActivityReadDetailException(
          denied ? ActivityReadDetailFailure.denied : ActivityReadDetailFailure.unavailable,
        );
      }
      if (value['error'] != null) throw const FormatException('Contradictory envelope');
      final detail = ActivityReadDetail.fromJson(value['data']);
      if (detail.id != activityId.toLowerCase()) {
        throw const FormatException('Uncorrelated activity');
      }
      return detail;
    } on ActivityReadDetailException {
      rethrow;
    } on PostgrestException catch (error) {
      throw ActivityReadDetailException(
        const {'42501', 'PGRST301', 'PGRST302'}.contains(error.code)
            ? ActivityReadDetailFailure.denied
            : ActivityReadDetailFailure.unavailable,
      );
    } on Object {
      throw const ActivityReadDetailException(ActivityReadDetailFailure.unavailable);
    }
  }
}

const _denials = {
  'SAI_AUTH_REQUIRED',
  'SAI_SESSION_INVALID',
  'SAI_INTERNAL_CONTEXT_DENIED',
  'SAI_MEMBERSHIP_SUSPENDED',
  'SAI_MEMBERSHIP_REVOKED',
  'SAI_PERMISSION_DENIED',
  'SAI_MFA_REQUIRED',
  'ACTIVITY_NOT_FOUND',
};
