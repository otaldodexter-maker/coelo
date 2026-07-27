abstract interface class CatalogAccessGateway {
  Future<CatalogAccessResult> checkAccess();
}

enum CatalogAccessResult { allowed, unauthenticated, denied, unavailable }
