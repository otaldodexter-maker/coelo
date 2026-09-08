import 'dart:convert';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';

import 'forms_authoring_api.dart';
import 'forms_backend_gateway.dart';

final class SupabaseFormsAuthoringApi implements FormsAuthoringApi {
  const SupabaseFormsAuthoringApi(this._backend);
  final FormsBackendGateway _backend;
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  @override
  Future<FormsAuthoringInstitutionPage> listInstitutions(FormsAuthoringInstitutionQuery query) =>
      _guard(() async {
        final data = await _request('superadmin_forms_authoring_institutions_v2', {
          'p_query': _query(query),
        });
        _exact(data, const {'items', 'has_more', 'next_cursor'});
        final raw = requireList(data, 'items', context: 'authoring_page');
        if (raw.length > query.limit) throw const FormatException();
        final items = raw.map((value) => _institution(_map(value))).toList(growable: false);
        if (items.map((item) => item.id.toLowerCase()).toSet().length != items.length) {
          throw const FormatException();
        }
        final more = requireBool(data, 'has_more', context: 'authoring_page');
        FormsAuthoringInstitutionCursor? cursor;
        if (more) {
          if (items.isEmpty) throw const FormatException();
          final wire = _map(data['next_cursor']);
          _exact(wire, const {'name_key', 'id'});
          cursor = FormsAuthoringInstitutionCursor(
            nameKey: requireString(wire, 'name_key', context: 'authoring_cursor'),
            id: requireString(wire, 'id', context: 'authoring_cursor'),
          );
          _cursor(cursor);
          if (!_sameId(cursor.id, items.last.id)) throw const FormatException();
        } else if (data['next_cursor'] != null) {
          throw const FormatException();
        }
        return FormsAuthoringInstitutionPage(items: items, nextCursor: cursor);
      });
  @override
  Future<FormsAuthoringEditor> getEditor(String formId) => _guard(() async {
    if (!_uuid.hasMatch(formId)) throw _failure('SAI_INVALID_ARGUMENT');
    final data = await _request('superadmin_forms_editor_v2', {'p_form_id': formId});
    _exact(data, const {'definition', 'application', 'institution', 'capabilities'});
    if (data['application'] != null) throw const FormatException();
    final definition = _definition(_map(data['definition']));
    final institution = _institution(_map(data['institution']));
    if (!_sameId(definition.id, formId) || !_sameId(definition.institutionId, institution.id)) {
      throw const FormatException();
    }
    final capabilities = _map(data['capabilities']);
    _exact(capabilities, const {'manage'});
    return FormsAuthoringEditor(
      definition: definition,
      institution: institution,
      canManage: requireBool(capabilities, 'manage', context: 'authoring_capabilities'),
    );
  });
  @override
  Future<FormDefinition> saveDraft(FormCommand<FormDefinition> command) => _guard(() async {
    final input = command.payload;
    if (!_uuid.hasMatch(command.requestId) ||
        command.expectedVersion < 0 ||
        !_uuid.hasMatch(input.id) ||
        !_uuid.hasMatch(input.institutionId) ||
        input.status != FormStatus.draft) {
      throw _failure('SAI_INVALID_ARGUMENT');
    }
    // Status and version belong to the read projection, not this RPC's
    // allowlisted command. The expected version travels separately.
    final payload = FormDefinitionDto.fromDomain(input).toJson()
      ..remove('status')
      ..remove('management_version');
    final data = await _request('superadmin_forms_save_draft_v2', {
      'p_request_id': command.requestId,
      'p_expected_version': command.expectedVersion,
      'p_payload': payload,
    });
    final definition = _definition(data);
    if (!_sameId(definition.id, input.id) ||
        !_sameId(definition.institutionId, input.institutionId) ||
        definition.managementVersion != command.expectedVersion + 1) {
      throw const FormatException();
    }
    return definition;
  });

  Future<Map<String, Object?>> _request(
    String functionName,
    Map<String, Object?> parameters,
  ) async {
    final envelope = _map(await _backend.rpc(functionName, parameters));
    // A denial never becomes a projection, even if it accidentally contains data.
    if (envelope['ok'] == false) throw _failure(_map(envelope['error'])['code']);
    _exact(envelope, const {'ok', 'data', 'error'});
    if (envelope['ok'] != true || envelope['error'] != null) throw const FormatException();
    return _map(envelope['data']);
  }

  static Map<String, Object?> _query(FormsAuthoringInstitutionQuery query) {
    try {
      if (query.limit < 1 || query.limit > 50 || query.search.runes.length > 160) {
        throw const FormatException();
      }
      return {
        'search': query.search,
        'limit': query.limit,
        'cursor': query.cursor == null ? null : _cursor(query.cursor!),
      };
    } catch (_) {
      throw _failure('SAI_INVALID_ARGUMENT');
    }
  }

  static Map<String, Object?> _cursor(FormsAuthoringInstitutionCursor cursor) {
    final result = <String, Object?>{'name_key': cursor.nameKey, 'id': cursor.id};
    if (!_uuid.hasMatch(cursor.id) ||
        cursor.nameKey.runes.length > 1024 ||
        utf8.encode(jsonEncode(result)).length > 8192) {
      throw const FormatException();
    }
    return result;
  }

  static FormsAuthoringInstitution _institution(Map<String, Object?> data) {
    _exact(data, const {'id', 'public_name'});
    final id = requireString(data, 'id', context: 'authoring_institution');
    final name = requireString(data, 'public_name', context: 'authoring_institution');
    if (!_uuid.hasMatch(id) || name.trim().isEmpty || name.runes.length > 1024) {
      throw const FormatException();
    }
    return FormsAuthoringInstitution(id: id, publicName: name);
  }

  static FormDefinition _definition(Map<String, Object?> data) {
    final definition = FormDefinitionDto.fromJson(data).toDomain();
    if (!_uuid.hasMatch(definition.id) ||
        !_uuid.hasMatch(definition.institutionId) ||
        definition.status != FormStatus.draft ||
        definition.managementVersion < 1) {
      throw const FormatException();
    }
    return definition;
  }

  static bool _sameId(String a, String b) => a.toLowerCase() == b.toLowerCase();
  static Map<String, Object?> _map(Object? value) {
    if (value is! Map<String, Object?>) throw const FormatException();
    return value;
  }

  static void _exact(Map<String, Object?> data, Set<String> keys) {
    if (data.length != keys.length || data.keys.any((key) => !keys.contains(key))) {
      throw const FormatException();
    }
  }

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FormApiException {
      rethrow;
    } on FormsBackendFailure catch (error) {
      throw _failure(error.code);
    } catch (_) {
      throw _failure(null);
    }
  }

  static FormApiException _failure(Object? code) {
    final kind = switch (code) {
      'SAI_AUTH_REQUIRED' ||
      'SAI_SESSION_INVALID' ||
      'SAI_INTERNAL_CONTEXT_DENIED' ||
      'SAI_MEMBERSHIP_SUSPENDED' ||
      'SAI_MEMBERSHIP_REVOKED' ||
      'SAI_PERMISSION_DENIED' ||
      'SAI_MFA_REQUIRED' ||
      '42501' ||
      'PGRST301' => FormApiFailureKind.unauthorized,
      'SAI_INVALID_ARGUMENT' || '22023' => FormApiFailureKind.validation,
      'SAI_CONCURRENT_CHANGE' || '40001' => FormApiFailureKind.conflict,
      _ => FormApiFailureKind.unavailable,
    };
    return FormApiException(kind, switch (kind) {
      FormApiFailureKind.unauthorized => 'Você não possui permissão para esta ação.',
      FormApiFailureKind.validation => 'Revise os dados enviados e tente novamente.',
      FormApiFailureKind.conflict => 'O formulário mudou. Recarregue e tente novamente.',
      _ => 'O contexto de formulários está indisponível. Tente novamente.',
    });
  }
}
