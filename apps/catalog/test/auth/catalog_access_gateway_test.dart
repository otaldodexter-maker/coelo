import 'package:coelo_catalog/auth/catalog_access_gateway.dart';
import 'package:coelo_catalog/auth/supabase_catalog_access_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defines the exact minimal platform membership query', () {
    expect(catalogPlatformMembershipQuery.table, 'platform_memberships');
    expect(catalogPlatformMembershipQuery.columns, 'id');
    expect(catalogPlatformMembershipQuery.limit, 1);
  });

  test('returns unauthenticated without querying when there is no session', () async {
    final api = _FakeCatalogSupabaseAccessApi(hasCurrentSession: false);
    final gateway = SupabaseCatalogAccessGateway.test(api);

    final result = await gateway.checkAccess();

    expect(result, CatalogAccessResult.unauthenticated);
    expect(api.queryCount, 0);
  });

  test('returns denied when RLS exposes no platform membership', () async {
    final api = _FakeCatalogSupabaseAccessApi(hasCurrentSession: true);
    final gateway = SupabaseCatalogAccessGateway.test(api);

    final result = await gateway.checkAccess();

    expect(result, CatalogAccessResult.denied);
    expect(api.queryCount, 1);
  });

  test('returns allowed when RLS exposes a platform membership', () async {
    final api = _FakeCatalogSupabaseAccessApi(
      hasCurrentSession: true,
      visibleMemberships: const [
        {'id': 'membership-id'},
      ],
    );
    final gateway = SupabaseCatalogAccessGateway.test(api);

    final result = await gateway.checkAccess();

    expect(result, CatalogAccessResult.allowed);
    expect(api.queryCount, 1);
  });

  test('returns unavailable when the membership query throws', () async {
    final api = _FakeCatalogSupabaseAccessApi(
      hasCurrentSession: true,
      queryException: Exception('network unavailable'),
    );
    final gateway = SupabaseCatalogAccessGateway.test(api);

    final result = await gateway.checkAccess();

    expect(result, CatalogAccessResult.unavailable);
    expect(api.queryCount, 1);
  });
}

final class _FakeCatalogSupabaseAccessApi implements CatalogSupabaseAccessApi {
  _FakeCatalogSupabaseAccessApi({
    required this.hasCurrentSession,
    this.visibleMemberships = const [],
    this.queryException,
  });

  @override
  final bool hasCurrentSession;

  final List<Map<String, dynamic>> visibleMemberships;
  final Exception? queryException;
  int queryCount = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchVisiblePlatformMemberships() async {
    queryCount += 1;
    if (queryException case final exception?) {
      throw exception;
    }
    return visibleMemberships;
  }
}
