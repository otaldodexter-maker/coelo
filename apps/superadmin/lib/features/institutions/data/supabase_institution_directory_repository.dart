import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/institution_directory_item.dart';
import '../domain/institution_directory_page.dart';
import '../domain/institution_directory_query.dart';
import '../domain/institution_directory_repository.dart';
import '../domain/institution_record.dart';

final class SupabaseInstitutionDirectoryRepository implements InstitutionDirectoryRepository {
  SupabaseInstitutionDirectoryRepository(this._client);

  final SupabaseClient _client;
  _PendingInstitutionRequest? _pendingRequest;

  @override
  Future<InstitutionDirectoryPage> fetchPage(InstitutionDirectoryQuery query) async {
    try {
      final filters = <String, Object?>{
        if (query.search.trim().isNotEmpty) 'search': query.search.trim(),
        if (query.statuses.isNotEmpty)
          'statuses': query.statuses.map((status) => status.databaseValue).toList(growable: false),
        if (query.planId != null) 'plan_id': query.planId,
        if (query.states.isNotEmpty) 'states': query.states.toList(growable: false),
        if (query.cities.isNotEmpty) 'cities': query.cities.toList(growable: false),
        if (query.districts.isNotEmpty) 'districts': query.districts.toList(growable: false),
        if (query.typeIds.isNotEmpty) 'type_ids': query.typeIds.toList(growable: false),
      };
      final items = <InstitutionDirectoryItem>[];
      var totalCount = 0;
      for (var consumed = 0; consumed < query.pageSize; consumed += 100) {
        final limit = min(100, query.pageSize - consumed);
        final data = _unwrapEnvelope(
          await _client.rpc<Object?>(
            'superadmin_institution_directory_v2',
            params: {
              'p_filters': filters,
              'p_limit': limit,
              'p_offset': query.offset + consumed,
              'p_sort': query.sortColumn.databaseColumn,
              'p_sort_ascending': query.sortAscending,
            },
          ),
        );
        final page = _asMap(data);
        totalCount = _asInt(page['total_count']);
        final rows = _asRows(page['items']);
        items.addAll(rows.map(InstitutionDirectoryItem.fromJson));
        if (rows.length < limit) break;
      }

      return InstitutionDirectoryPage(
        items: items,
        totalCount: totalCount,
        page: query.page,
        pageSize: query.pageSize,
      );
    } on PostgrestException catch (error) {
      _throwMappedException(error);
    } on ClientException {
      throw const InstitutionDirectoryUnavailableException();
    }
  }

  @override
  Future<InstitutionRecord> fetchById(String institutionId) async {
    try {
      final response = await _client.rpc<Object?>(
        'superadmin_institution_detail_v2',
        params: {'p_institution_id': institutionId},
      );
      return InstitutionRecord.fromRpcPayload(_asMap(_unwrapEnvelope(response)));
    } on PostgrestException catch (error) {
      _throwMappedException(error);
    } on ClientException {
      throw const InstitutionDirectoryUnavailableException();
    } on InstitutionDirectoryNotFoundException {
      rethrow;
    }
  }

  @override
  Future<InstitutionRecord> create(InstitutionRecord draft) async {
    throw const InstitutionDirectoryUnavailableException();
  }

  @override
  Future<InstitutionRecord> update(InstitutionRecord draft, {required int expectedVersion}) async {
    _throwIfUnsupportedRelations(draft);
    final payload = _institutionEditCorePayload(draft);
    final signature = _requestSignature(
      operation: 'update',
      institutionId: draft.id,
      expectedVersion: expectedVersion,
      payload: payload,
    );
    final requestId = _requestIdFor(signature);
    try {
      final response = await _client.rpc<Object?>(
        'superadmin_institution_edit_core_v2',
        params: {
          'p_request_id': requestId,
          'p_institution_id': draft.id,
          'p_expected_version': expectedVersion,
          'p_payload': payload,
        },
      );
      _unwrapEnvelope(response);
      final record = await fetchById(draft.id);
      _clearPendingRequest(signature, requestId);
      return record;
    } on PostgrestException catch (error) {
      if (!_isUnavailableCode(error.code)) {
        _clearPendingRequest(signature, requestId);
      }
      _throwMappedException(error);
    } on ClientException {
      throw const InstitutionDirectoryUnavailableException();
    } catch (_) {
      _clearPendingRequest(signature, requestId);
      rethrow;
    }
  }

  @override
  Future<InstitutionDirectoryFilterOptions> fetchFilterOptions({
    Set<String> states = const {},
    Set<String> cities = const {},
  }) async {
    try {
      final data = _asMap(
        _unwrapEnvelope(
          await _client.rpc<Object?>(
            'superadmin_institution_filter_options_v2',
            params: {
              'p_states': states.toList(growable: false),
              'p_cities': cities.toList(growable: false),
            },
          ),
        ),
      );
      return InstitutionDirectoryFilterOptions(
        plans: _options(data['plans']),
        types: _options(data['types']),
        states: _options(data['states']),
        cities: _options(data['cities']),
        districts: _options(data['districts']),
      );
    } on PostgrestException catch (error) {
      _throwMappedException(error);
    } on ClientException {
      throw const InstitutionDirectoryUnavailableException();
    }
  }

  void _throwIfUnsupportedRelations(InstitutionRecord draft) {
    if (draft.hasUnsupportedRemoteData) {
      _pendingRequest = null;
      throw InstitutionDirectoryUnsupportedRelationException(
        'Não é possível salvar campos ou vínculos sem contrato remoto aprovado.',
      );
    }
  }

  String _requestSignature({
    required String operation,
    required Map<String, dynamic> payload,
    String? institutionId,
    int? expectedVersion,
  }) {
    return jsonEncode({
      'operation': operation,
      'institution_id': institutionId,
      'expected_version': expectedVersion,
      'payload': payload,
    });
  }

  String _requestIdFor(String signature) {
    final pending = _pendingRequest;
    if (pending != null && pending.signature == signature) {
      return pending.requestId;
    }

    final requestId = _nextRequestId();
    _pendingRequest = _PendingInstitutionRequest(signature, requestId);
    return requestId;
  }

  void _clearPendingRequest(String signature, String requestId) {
    final pending = _pendingRequest;
    if (pending?.signature == signature && pending?.requestId == requestId) {
      _pendingRequest = null;
    }
  }

  bool _isUnavailableCode(String? code) {
    return code == 'PGRST000' || code == 'PGRST001' || code == 'PGRST002';
  }

  Never _throwMappedException(PostgrestException error) {
    switch (error.code) {
      case '42501':
      case 'PGRST301':
        throw const InstitutionDirectoryUnauthorizedException();
      case 'P0002':
        throw const InstitutionDirectoryNotFoundException();
      case '40001':
        throw const InstitutionDirectoryConflictException();
      case '22023':
      case '23514':
        throw InstitutionDirectoryValidationException(error.message);
      case 'PGRST000':
      case 'PGRST001':
      case 'PGRST002':
        throw const InstitutionDirectoryUnavailableException();
      default:
        throw InstitutionDirectoryUnexpectedException(error.message);
    }
  }
}

final class _PendingInstitutionRequest {
  const _PendingInstitutionRequest(this.signature, this.requestId);

  final String signature;
  final String requestId;
}

final class UnavailableInstitutionDirectoryRepository implements InstitutionDirectoryRepository {
  const UnavailableInstitutionDirectoryRepository();

  @override
  Future<InstitutionDirectoryPage> fetchPage(InstitutionDirectoryQuery query) {
    return Future<InstitutionDirectoryPage>.error(const InstitutionDirectoryUnavailableException());
  }

  @override
  Future<InstitutionRecord> fetchById(String institutionId) {
    return Future<InstitutionRecord>.error(const InstitutionDirectoryUnavailableException());
  }

  @override
  Future<InstitutionRecord> create(InstitutionRecord draft) {
    return Future<InstitutionRecord>.error(const InstitutionDirectoryUnavailableException());
  }

  @override
  Future<InstitutionRecord> update(InstitutionRecord draft, {required int expectedVersion}) {
    return Future<InstitutionRecord>.error(const InstitutionDirectoryUnavailableException());
  }

  @override
  Future<InstitutionDirectoryFilterOptions> fetchFilterOptions({
    Set<String> states = const {},
    Set<String> cities = const {},
  }) {
    return Future<InstitutionDirectoryFilterOptions>.error(
      const InstitutionDirectoryUnavailableException(),
    );
  }
}

List<InstitutionDirectoryFilterOption> _options(Object? value) {
  return _asRows(value)
      .map(
        (row) => InstitutionDirectoryFilterOption(
          id: row['id'] as String,
          label: row['label'] as String,
        ),
      )
      .toList(growable: false);
}

Map<String, Object?> _institutionEditCorePayload(InstitutionRecord record) {
  return {
    'public_name': record.publicName,
    'trade_name': record.tradeName.isEmpty ? null : record.tradeName,
    'legal_name': record.legalName.isEmpty ? null : record.legalName,
    'timezone': record.timezone,
    'locale': record.locale,
    if (record.typeId.isNotEmpty) 'institution_type_id': record.typeId,
    'address': {
      'country': record.country,
      'state': record.state.isEmpty ? null : record.state,
      'city': record.city.isEmpty ? null : record.city,
      'district': record.district.isEmpty ? null : record.district,
      'street': record.street.isEmpty ? null : record.street,
      'number': record.addressNumber.isEmpty ? null : record.addressNumber,
      'complement': record.complement.isEmpty ? null : record.complement,
      'postal_code': record.postalCode.replaceAll(RegExp(r'\D'), ''),
    },
  };
}

Object? _unwrapEnvelope(Object? value) {
  final envelope = _asMap(value);
  if (envelope['ok'] == true) return envelope['data'];
  final error = envelope['error'];
  final details = error is Map ? Map<String, dynamic>.from(error) : const <String, dynamic>{};
  final code = details['code']?.toString();
  final message = details['message']?.toString() ?? 'Não foi possível concluir a operação.';
  switch (code) {
    case 'SAI_AUTH_REQUIRED':
    case 'SAI_SESSION_INVALID':
    case 'SAI_INTERNAL_CONTEXT_DENIED':
    case 'SAI_MEMBERSHIP_SUSPENDED':
    case 'SAI_MEMBERSHIP_REVOKED':
    case 'SAI_PERMISSION_DENIED':
    case 'SAI_MFA_REQUIRED':
      throw const InstitutionDirectoryUnauthorizedException();
    case 'SAI_CONCURRENT_CHANGE':
    case 'SAI_LAST_OWNER_PROTECTED':
      throw const InstitutionDirectoryConflictException();
    case 'SAI_INVALID_ARGUMENT':
      throw InstitutionDirectoryValidationException(message);
    default:
      throw const InstitutionDirectoryUnavailableException();
  }
}

Map<String, dynamic> _asMap(Object? value) => value is Map
    ? Map<String, dynamic>.from(value)
    : throw const InstitutionDirectoryUnavailableException();

List<Map<String, dynamic>> _asRows(Object? value) => value is List
    ? value.map((row) => _asMap(row)).toList(growable: false)
    : throw const InstitutionDirectoryUnavailableException();

int _asInt(Object? value) =>
    value is num ? value.toInt() : throw const InstitutionDirectoryUnavailableException();

String _nextRequestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  String hex(int value) => value.toRadixString(16).padLeft(2, '0');
  return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}-'
      '${hex(bytes[4])}${hex(bytes[5])}-'
      '${hex(bytes[6])}${hex(bytes[7])}-'
      '${hex(bytes[8])}${hex(bytes[9])}-'
      '${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
}
