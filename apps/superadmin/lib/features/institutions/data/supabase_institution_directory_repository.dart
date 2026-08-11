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
      var request = _client.from('institution_directory').select();
      final search = query.search.trim();
      if (search.isNotEmpty) {
        request = request.ilike('search_name', '%${_escapeLike(search)}%');
      }
      if (query.statuses.isNotEmpty) {
        request = request.inFilter(
          'status',
          query.statuses.map((status) => status.databaseValue).toList(growable: false),
        );
      }
      if (query.planId != null) {
        request = request.eq('plan_id', query.planId!);
      }
      if (query.states.isNotEmpty) {
        request = request.inFilter('state', query.states.toList(growable: false));
      }
      if (query.cities.isNotEmpty) {
        request = request.inFilter('city', query.cities.toList(growable: false));
      }
      if (query.districts.isNotEmpty) {
        request = request.inFilter('district', query.districts.toList(growable: false));
      }
      if (query.typeIds.isNotEmpty) {
        request = request.inFilter('institution_type_id', query.typeIds.toList(growable: false));
      }

      final response = await request
          .order(query.sortColumn.databaseColumn, ascending: query.sortAscending)
          .order('id', ascending: true)
          .range(query.offset, query.offset + query.pageSize - 1)
          .count(CountOption.exact);
      final rows = response.data;
      final items = rows
          .map((row) => InstitutionDirectoryItem.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);

      return InstitutionDirectoryPage(
        items: items,
        totalCount: response.count,
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
      final response = await _client.rpc<Map<String, dynamic>>(
        'get_institution_for_superadmin',
        params: {'p_institution_id': institutionId},
      );
      if (response.isEmpty) {
        throw const InstitutionDirectoryNotFoundException();
      }
      return InstitutionRecord.fromRpcPayload(
        _coercePayload(response, missingError: const InstitutionDirectoryNotFoundException()),
      );
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
    _throwIfUnsupportedRelations(draft);
    final payload = _normalizePayload(draft.toRpcPayload());
    final signature = _requestSignature(operation: 'create', payload: payload);
    final requestId = _requestIdFor(signature);
    try {
      final response = await _client.rpc<Map<String, dynamic>>(
        'create_institution_for_superadmin',
        params: {'p_request_id': requestId, 'p_payload': payload},
      );
      final record = InstitutionRecord.fromRpcPayload(
        _coercePayload(
          response,
          missingError: const InstitutionDirectoryUnexpectedException('missing payload'),
        ),
      );
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
  Future<InstitutionRecord> update(InstitutionRecord draft, {required int expectedVersion}) async {
    _throwIfUnsupportedRelations(draft);
    final payload = _normalizePayload(draft.toRpcPayload());
    final signature = _requestSignature(
      operation: 'update',
      institutionId: draft.id,
      expectedVersion: expectedVersion,
      payload: payload,
    );
    final requestId = _requestIdFor(signature);
    try {
      final response = await _client.rpc<Map<String, dynamic>>(
        'update_institution_for_superadmin',
        params: {
          'p_request_id': requestId,
          'p_institution_id': draft.id,
          'p_expected_version': expectedVersion,
          'p_payload': payload,
        },
      );
      final record = InstitutionRecord.fromRpcPayload(
        _coercePayload(
          response,
          missingError: const InstitutionDirectoryUnexpectedException('missing payload'),
        ),
      );
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
      final statesRequest = _client.from('institution_directory_locations').select('state');
      var locationsRequest = _client
          .from('institution_directory_locations')
          .select('state, city, district');
      if (states.isNotEmpty) {
        locationsRequest = locationsRequest.inFilter('state', states.toList(growable: false));
      }
      if (cities.isNotEmpty) {
        locationsRequest = locationsRequest.inFilter('city', cities.toList(growable: false));
      }
      final results = await Future.wait<List<dynamic>>([
        _client.from('plans').select('id, name').eq('status', 'active').order('name'),
        _client.from('institution_types').select('id, name').eq('status', 'active').order('name'),
        statesRequest.order('state'),
        locationsRequest.order('city').order('district'),
      ]);
      return InstitutionDirectoryFilterOptions(
        plans: _optionsFromRows(results[0]),
        types: _optionsFromRows(results[1]),
        states: _locationOptionsFromRows(results[2], 'state'),
        cities: states.isEmpty ? const [] : _locationOptionsFromRows(results[3], 'city'),
        districts: cities.isEmpty ? const [] : _locationOptionsFromRows(results[3], 'district'),
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

List<InstitutionDirectoryFilterOption> _locationOptionsFromRows(List<dynamic> rows, String key) {
  final values = <String>{};
  for (final rawRow in rows) {
    final row = Map<String, dynamic>.from(rawRow as Map);
    final value = row[key];
    if (value is String && value.trim().isNotEmpty) {
      values.add(value);
    }
  }
  final sorted = values.toList()..sort();
  return sorted
      .map((value) => InstitutionDirectoryFilterOption(id: value, label: value))
      .toList(growable: false);
}

List<InstitutionDirectoryFilterOption> _optionsFromRows(List<dynamic> rows) {
  return rows
      .map((row) => Map<String, dynamic>.from(row as Map))
      .map(
        (row) =>
            InstitutionDirectoryFilterOption(id: row['id'] as String, label: row['name'] as String),
      )
      .toList(growable: false);
}

String _escapeLike(String value) {
  return value.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');
}

Map<String, dynamic> _normalizePayload(Map<String, dynamic> payload) {
  final normalized = Map<String, dynamic>.from(payload);
  final json = jsonEncode(normalized);
  return jsonDecode(json) as Map<String, dynamic>;
}

Map<String, dynamic> _coercePayload(Object? payload, {required Exception missingError}) {
  if (payload is Map<String, dynamic>) {
    return Map<String, dynamic>.from(payload);
  }
  throw missingError;
}

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
