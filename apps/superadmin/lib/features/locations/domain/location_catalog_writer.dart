import 'package:coelo_api/locations.dart';
import 'package:coelo_domain/locations.dart';

/// Creates locations in the catalog of one owner.
///
/// Separate from the reader on purpose: a screen that only lists locations must
/// not be able to create one, and a composition without the write capability
/// stays read-only by construction.
///
/// [requestId] makes the create idempotent. Retrying the same request with the
/// same draft returns the location already created; reusing it with a different
/// draft is a conflict, never a second location.
abstract interface class LocationCatalogWriter {
  Future<LocationCatalogEntry> create({
    required LocationWriteDraft draft,
    required String requestId,
  });
}

/// Default composition: creating fails honestly instead of pretending.
final class UnavailableLocationCatalogWriter implements LocationCatalogWriter {
  const UnavailableLocationCatalogWriter();

  @override
  Future<LocationCatalogEntry> create({
    required LocationWriteDraft draft,
    required String requestId,
  }) async => throw const LocationCatalogWriteUnavailableException();
}

final class LocationCatalogWriteUnavailableException implements Exception {
  const LocationCatalogWriteUnavailableException();

  @override
  String toString() => 'Location write unavailable';
}
