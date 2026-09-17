import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/child_safety.dart';
import '../domain/child_safety_contract.dart';
import 'child_safety_response_decoder.dart';

final class SupabaseChildSafetyRepository
    implements
        ChildSafetyRepository,
        ChildSafetyMutationSupport,
        ChildSafetyPersonSearchSupport,
        ChildSafetyPersonWithoutAccountSupport {
  const SupabaseChildSafetyRepository(this._client, {http.Client? mediaClient})
    : _mediaClient = mediaClient;

  final SupabaseClient _client;
  final http.Client? _mediaClient;

  /// O contrato de escrita foi qualificado em producao (child_safety_request_
  /// authorization, edit_pending, decide e change_lifecycle; decisao pelo
  /// Superadmin com auditoria, P32 B, pacote 171800). Sem esta adesao o
  /// controlador escondia Criar/Gerenciar mesmo com can_create do servidor.
  @override
  bool get mutationsEnabled => true;

  @override
  Future<ChildSafetyDirectoryPage> fetchDirectory(ChildSafetyDirectoryQuery query) async {
    final payload = await _rpc('superadmin_child_safety_directory', {
      'p_search': query.search.trim(),
      'p_institution_ids': query.institutionIds.toList(),
      'p_unit_ids': query.unitIds.toList(),
      'p_segment': query.segment.databaseValue,
      'p_limit': query.pageSize,
      'p_cursor': _decodeCursor(query.cursor),
    });
    return decodeChildSafetyDirectory(payload);
  }

  @override
  Future<ChildSafetyRecord?> fetchChild(String childId) async {
    final payload = await _rpc('superadmin_child_safety_get', {'p_child_id': childId});
    return decodeChildSafetyRecord(payload);
  }

  @override
  Future<List<ChildSafetyChildOption>> searchChildren(String query, {int limit = 20}) async {
    final payload = await _rpc('superadmin_child_safety_search_children', {
      'p_search': query.trim(),
      'p_limit': limit,
    });
    return decodeChildSafetyOptions(payload);
  }

  /// B5 (spec 061): leitor unico com deteccao de tipo no servidor; o cliente
  /// so envia o texto e recebe o resultado minimizado (CPF nunca).
  @override
  Future<List<ChildSafetyPersonMatch>> searchPeople(String query) async {
    final payload = await _rpc('superadmin_person_search_v1', {'p_query': query.trim()});
    return decodeChildSafetyPersonMatches(payload);
  }

  /// B6 (spec 062): registro da pessoa sem conta; CPF vai so ao servidor, que
  /// guarda apenas o HMAC e devolve a mascara.
  @override
  Future<PersonWithoutAccountRegistration> registerPersonWithoutAccount(
    RegisterPersonWithoutAccountCommand command,
  ) async {
    final payload = await _rpc('child_safety_register_person_without_account_v1', {
      'p_request_id': command.requestId,
      'p_payload': {
        'child_context_id': command.childContextId,
        'unit_id': command.unitId,
        'full_name': command.fullName.trim(),
        'cpf': command.cpf,
        if (command.mobilePhone case final phone? when phone.trim().isNotEmpty)
          'mobile_phone': phone.trim(),
        if (command.email case final email? when email.trim().isNotEmpty) 'email': email.trim(),
      },
    });
    return decodePersonWithoutAccountRegistration(payload);
  }

  /// Documento em R2 privado pelo gateway child-safety-media: prepare -> PUT
  /// assinado -> finalize. O cliente nunca ve bucket ou chave.
  @override
  Future<ChildSafetyPersonDocument> uploadPersonDocument(
    ChildSafetyPersonDocumentUpload upload,
  ) async {
    final bytes = upload.file.bytes;
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      throw const ChildSafetyValidationException();
    }
    final prepared = await _mediaAction({
      'action': 'prepare',
      'request_id': upload.requestId,
      'authorized_person_id': upload.authorizedPersonId,
      'mime_type': upload.file.mimeType,
      'size_bytes': bytes.length,
    });
    final documentId = prepared['document_id'];
    final uploadUrl = prepared['upload_url'];
    final requiredHeaders = prepared['required_headers'];
    final uri = uploadUrl is String ? Uri.tryParse(uploadUrl) : null;
    if (documentId is! String || uri == null || !uri.hasScheme || uri.userInfo.isNotEmpty) {
      throw const ChildSafetyUnavailableException();
    }
    final headers = <String, String>{};
    if (requiredHeaders is Map) {
      for (final entry in requiredHeaders.entries) {
        final key = entry.key.toString().toLowerCase();
        if (key == 'authorization' || key == 'apikey' || key == 'cookie') {
          throw const ChildSafetyUnavailableException();
        }
        headers[key] = entry.value.toString();
      }
    }
    final client = _mediaClient ?? http.Client();
    try {
      final request = http.Request('PUT', uri)
        ..followRedirects = false
        ..headers.addAll(headers)
        ..bodyBytes = bytes;
      final response = await http.Response.fromStream(await client.send(request));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const ChildSafetyUnavailableException();
      }
    } on ClientException {
      throw const ChildSafetyUnavailableException();
    } finally {
      if (_mediaClient == null) client.close();
    }
    final finalized = await _mediaAction({
      'action': 'finalize',
      'document_id': documentId,
      'checksum_sha256': sha256.convert(bytes).toString(),
    });
    final status = finalized['status'];
    if (finalized['document_id'] != documentId || status is! String) {
      throw const ChildSafetyUnavailableException();
    }
    return ChildSafetyPersonDocument(documentId: documentId, status: status);
  }

  Future<Map<String, dynamic>> _mediaAction(Map<String, dynamic> body) async {
    try {
      final response = await _client.functions.invoke('child-safety-media', body: body);
      if (response.status != 200 || response.data is! Map) {
        throw const ChildSafetyUnavailableException();
      }
      return Map<String, dynamic>.from(response.data as Map);
    } on FunctionException catch (error) {
      throw switch (error.status) {
        401 || 403 => const ChildSafetyUnauthorizedException(),
        _ => const ChildSafetyUnavailableException(),
      };
    } on ClientException {
      throw const ChildSafetyUnavailableException();
    }
  }

  @override
  Future<void> saveAuthorization(SavePickupAuthorizationCommand command) async {
    final payload = <String, Object?>{
      'child_id': command.childId,
      'child_context_id': command.childContextId,
      'unit_id': command.unitId,
      // B6: pessoa sem conta vai por authorized_person_id; person_id fica ausente.
      if (command.authorizedPersonId case final withoutAccount?)
        'authorized_person_id': withoutAccount
      else
        'person_id': command.personId,
      'relationship_code': command.relationshipCode,
      'relationship_detail': command.relationshipDetail,
      'capability_codes': command.capabilityCodes.toList()..sort(),
      'valid_from': command.validFrom?.toUtc().toIso8601String(),
      'valid_until': command.validUntil?.toUtc().toIso8601String(),
      'request_reason': command.requestReason.trim(),
    };
    if (command.authorizationId case final authorizationId?) {
      await _rpc('child_safety_edit_pending_authorization', {
        'p_request_id': command.requestId,
        'p_authorization_id': authorizationId,
        'p_expected_version': command.expectedVersion,
        'p_payload': payload,
      });
    } else {
      await _rpc('child_safety_request_authorization', {
        'p_request_id': command.requestId,
        'p_payload': payload,
      });
    }
  }

  @override
  Future<void> transitionAuthorization(TransitionPickupAuthorizationCommand command) async {
    await _rpc('child_safety_decide_authorization', {
      'p_request_id': command.requestId,
      'p_authorization_id': command.authorizationId,
      'p_expected_version': command.expectedVersion,
      'p_decision': command.status.name,
      'p_reason': command.reason.trim(),
    });
  }

  @override
  Future<void> suspendAuthorization(SuspendPickupAuthorizationCommand command) async {
    await _rpc('child_safety_change_lifecycle', {
      'p_request_id': command.requestId,
      'p_authorization_id': command.authorizationId,
      'p_expected_version': command.expectedVersion,
      'p_lifecycle_status': 'suspended',
      'p_reason': command.reason.trim(),
    });
  }

  @override
  Future<void> requestExport(ChildSafetyExportCommand command) async {
    await _rpc('superadmin_request_child_safety_export', {
      'p_request_id': command.requestId,
      'p_format': command.format,
      'p_filters': command.filters,
    });
  }

  Future<Object?> _rpc(String function, Map<String, Object?> params) async {
    try {
      return await _client.rpc(function, params: params);
    } on PostgrestException catch (error) {
      throw switch (error.code) {
        '42501' => const ChildSafetyUnauthorizedException(),
        'P0002' => const ChildSafetyNotFoundException(),
        // PT409: conflito de versao sinalizado pelas RPCs de child_safety desde
        // 20260916152000 (40001 fazia o PostgREST reexecutar ate o 504).
        '23505' || '40001' || 'PT409' => const ChildSafetyConflictException(),
        // PT422: limite de taxa da busca de pessoa (PERSON_SEARCH_RATE_LIMIT).
        'PT422' => const ChildSafetyRateLimitException(),
        '22023' when error.details?.toString().contains('PERSON_HAS_ACCOUNT') ?? false =>
          const ChildSafetyPersonHasAccountException(),
        '22023' || '23514' => const ChildSafetyValidationException(),
        _ => const ChildSafetyUnavailableException(),
      };
    } on ClientException {
      throw const ChildSafetyUnavailableException();
    }
  }
}

Object? _decodeCursor(String? cursor) {
  if (cursor == null || cursor.isEmpty) return null;
  try {
    return jsonDecode(cursor);
  } on FormatException {
    throw const ChildSafetyValidationException();
  }
}
