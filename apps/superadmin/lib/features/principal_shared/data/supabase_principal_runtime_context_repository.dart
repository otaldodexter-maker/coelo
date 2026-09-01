import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/principal_runtime_context.dart';

final class SupabasePrincipalRuntimeContextRepository implements PrincipalRuntimeContextRepository {
  const SupabasePrincipalRuntimeContextRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<PrincipalRuntimeContext>> listAvailableContexts() async {
    try {
      final response = await _client.rpc<List<dynamic>>('list_my_principal_contexts');
      return response
          .map((row) => _contextFromJson(Map<String, dynamic>.from(row as Map)))
          .toList(growable: false);
    } on PostgrestException catch (error) {
      if (error.code == '42501' || error.code == 'PGRST301') {
        throw const PrincipalRuntimeContextUnauthorized();
      }
      throw const PrincipalRuntimeContextUnavailable();
    } on FormatException {
      throw const PrincipalRuntimeContextUnavailable();
    } on TypeError {
      throw const PrincipalRuntimeContextUnavailable();
    }
  }
}

PrincipalRuntimeContext _contextFromJson(Map<String, dynamic> json) => PrincipalRuntimeContext(
  membershipId: _requiredText(json, 'membership_id'),
  personId: _requiredText(json, 'person_id'),
  institutionId: _requiredText(json, 'institution_id'),
  institutionName: _requiredText(json, 'institution_name'),
  roleCode: _requiredText(json, 'role_code'),
  scopeKind: _requiredText(json, 'scope_kind'),
  unitId: _optionalText(json, 'unit_id'),
  unitName: _optionalText(json, 'unit_name'),
  groupId: _optionalText(json, 'group_id'),
  groupName: _optionalText(json, 'group_name'),
);

String _requiredText(Map<String, dynamic> json, String key) {
  final value = _optionalText(json, key);
  if (value == null) throw FormatException('invalid_$key');
  return value;
}

String? _optionalText(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('invalid_$key');
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
