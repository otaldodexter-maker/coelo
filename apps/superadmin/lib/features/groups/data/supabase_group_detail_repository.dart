import 'dart:async';

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/group_detail.dart';

final class SupabaseGroupDetailRepository implements GroupDetailRepository {
  SupabaseGroupDetailRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<GroupDetail> fetchById(String groupId) async {
    if (!isGroupDetailId(groupId)) {
      throw const GroupDetailException(GroupDetailFailure.invalidId);
    }
    try {
      final value = await _client.rpc<Object?>(
        'superadmin_group_detail_v2',
        params: {'p_group_id': groupId},
      );
      if (value is! Map || value['ok'] is! bool) {
        throw const GroupDetailException(GroupDetailFailure.unavailable);
      }
      if (value['ok'] != true) {
        final error = value['error'];
        final code = error is Map ? error['code'] : null;
        throw GroupDetailException(
          _deniedCodes.contains(code) ? GroupDetailFailure.denied : GroupDetailFailure.unavailable,
        );
      }
      final detail = GroupDetail.fromJson(value['data']);
      if (detail.id.toLowerCase() != groupId.toLowerCase()) {
        throw const GroupDetailException(GroupDetailFailure.unavailable);
      }
      return detail;
    } on PostgrestException catch (error) {
      throw GroupDetailException(
        const {'42501', 'PGRST301', 'PGRST302'}.contains(error.code)
            ? GroupDetailFailure.denied
            : GroupDetailFailure.unavailable,
      );
    } on ClientException {
      throw const GroupDetailException(GroupDetailFailure.unavailable);
    } on TimeoutException {
      throw const GroupDetailException(GroupDetailFailure.unavailable);
    } on FormatException {
      throw const GroupDetailException(GroupDetailFailure.unavailable);
    } on TypeError {
      throw const GroupDetailException(GroupDetailFailure.unavailable);
    }
  }
}

const _deniedCodes = {
  'SAI_AUTH_REQUIRED',
  'SAI_SESSION_INVALID',
  'SAI_INTERNAL_CONTEXT_DENIED',
  'SAI_MEMBERSHIP_SUSPENDED',
  'SAI_MEMBERSHIP_REVOKED',
  'SAI_PERMISSION_DENIED',
  'SAI_MFA_REQUIRED',
};
