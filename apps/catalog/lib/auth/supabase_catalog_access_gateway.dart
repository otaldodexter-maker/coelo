import 'package:supabase_flutter/supabase_flutter.dart';

import 'catalog_access_gateway.dart';

const catalogPlatformMembershipQuery = (table: 'platform_memberships', columns: 'id', limit: 1);

abstract interface class CatalogSupabaseAccessApi {
  bool get hasCurrentSession;

  Future<List<Map<String, dynamic>>> fetchVisiblePlatformMemberships();
}

final class SupabaseCatalogAccessGateway implements CatalogAccessGateway {
  SupabaseCatalogAccessGateway(SupabaseClient client)
    : this.test(_SupabaseCatalogAccessApi(client));

  SupabaseCatalogAccessGateway.test(this._api);

  final CatalogSupabaseAccessApi _api;

  @override
  Future<CatalogAccessResult> checkAccess() async {
    try {
      if (!_api.hasCurrentSession) {
        return CatalogAccessResult.unauthenticated;
      }

      final memberships = await _api.fetchVisiblePlatformMemberships();
      return memberships.isEmpty ? CatalogAccessResult.denied : CatalogAccessResult.allowed;
    } on Exception {
      return CatalogAccessResult.unavailable;
    }
  }
}

final class _SupabaseCatalogAccessApi implements CatalogSupabaseAccessApi {
  _SupabaseCatalogAccessApi(this._client);

  final SupabaseClient _client;

  @override
  bool get hasCurrentSession => _client.auth.currentSession != null;

  @override
  Future<List<Map<String, dynamic>>> fetchVisiblePlatformMemberships() {
    return _client
        .from(catalogPlatformMembershipQuery.table)
        .select(catalogPlatformMembershipQuery.columns)
        .limit(catalogPlatformMembershipQuery.limit);
  }
}
