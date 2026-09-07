import 'dart:async';

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/unit_detail.dart';

final class SupabaseUnitDetailRepository implements UnitDetailRepository {
  SupabaseUnitDetailRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<UnitDetail> fetchById(String unitId) async {
    if (!isUnitDetailId(unitId)) {
      throw const UnitDetailException(UnitDetailFailure.invalidId);
    }
    try {
      final value = await _client.rpc<Object?>(
        'superadmin_unit_detail_v2',
        params: {'p_unit_id': unitId},
      );
      if (value is! Map || value['ok'] is! bool) {
        throw const UnitDetailException(UnitDetailFailure.unavailable);
      }
      if (value['ok'] != true) {
        final error = value['error'];
        final code = error is Map ? error['code'] : null;
        throw UnitDetailException(
          _deniedCodes.contains(code) ? UnitDetailFailure.denied : UnitDetailFailure.unavailable,
        );
      }
      final detail = UnitDetail.fromJson(value['data']);
      if (detail.id.toLowerCase() != unitId.toLowerCase()) {
        throw const UnitDetailException(UnitDetailFailure.unavailable);
      }
      return detail;
    } on PostgrestException catch (error) {
      throw UnitDetailException(
        const {'42501', 'PGRST301', 'PGRST302'}.contains(error.code)
            ? UnitDetailFailure.denied
            : UnitDetailFailure.unavailable,
      );
    } on ClientException {
      throw const UnitDetailException(UnitDetailFailure.unavailable);
    } on TimeoutException {
      throw const UnitDetailException(UnitDetailFailure.unavailable);
    } on FormatException {
      throw const UnitDetailException(UnitDetailFailure.unavailable);
    } on TypeError {
      throw const UnitDetailException(UnitDetailFailure.unavailable);
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
