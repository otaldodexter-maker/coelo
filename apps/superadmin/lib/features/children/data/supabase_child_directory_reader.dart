import 'package:coelo_api/children.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef ChildDirectoryRpc = Future<Object?> Function(String name, Map<String, Object?> params);

final class ChildDirectoryUnavailableException implements Exception {
  const ChildDirectoryUnavailableException();
  @override
  String toString() => 'Child directory unavailable';
}

/// Stateless adapter for the candidate internal read contract; not wired to UI.
/// Session invalidation and late-result handling belong to its future consumer.
final class SupabaseChildDirectoryReader {
  SupabaseChildDirectoryReader(SupabaseClient client)
    : _rpc = ((name, params) => client.rpc<Object?>(name, params: params));
  const SupabaseChildDirectoryReader.withRpc(this._rpc);
  final ChildDirectoryRpc _rpc;

  Future<ChildDirectoryPage> fetchPage(ChildDirectoryRequest request) async {
    try {
      final params = request.toRpcParams();
      final response = await _rpc('superadmin_child_context_directory_v2', params);
      return decodeChildDirectory(response, request: request);
    } on ChildDirectoryDeniedException {
      rethrow;
    } on PostgrestException catch (error) {
      if (const {'42501', 'PGRST301', 'PGRST302'}.contains(error.code)) {
        throw const ChildDirectoryDeniedException();
      }
      throw const ChildDirectoryUnavailableException();
    } on Object {
      // Never carry raw transport details or response data into UI errors.
      throw const ChildDirectoryUnavailableException();
    }
  }
}
