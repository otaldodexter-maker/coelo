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
///
/// [expectedVersion] is the `managementVersion` the actor was looking at. Every
/// command that changes an existing location carries it, so an edit made
/// against a screen that has gone stale loses instead of overwriting what it
/// never saw.
abstract interface class LocationCatalogWriter {
  Future<LocationCatalogEntry> create({
    required LocationWriteDraft draft,
    required String requestId,
  });

  Future<LocationCatalogEntry> update({
    required String locationId,
    required LocationWriteDraft draft,
    required int expectedVersion,
    required String requestId,
  });

  Future<LocationCatalogEntry> setStatus({
    required String locationId,
    required LocationCatalogStatus status,
    required int expectedVersion,
    required String requestId,
  });

  Future<LocationCatalogEntry> copy({
    required String sourceId,
    required String sourceInstitutionId,
    required LocationScope targetScope,
    required String name,
    required String requestId,
  });

  Future<LocationSchedule> readSchedule({required String locationId});

  Future<LocationSchedule> setSchedule({
    required String locationId,
    required List<LocationScheduleWindow> windows,
    required int expectedVersion,
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

  @override
  Future<LocationCatalogEntry> update({
    required String locationId,
    required LocationWriteDraft draft,
    required int expectedVersion,
    required String requestId,
  }) async => throw const LocationCatalogWriteUnavailableException();

  @override
  Future<LocationCatalogEntry> setStatus({
    required String locationId,
    required LocationCatalogStatus status,
    required int expectedVersion,
    required String requestId,
  }) async => throw const LocationCatalogWriteUnavailableException();

  @override
  Future<LocationCatalogEntry> copy({
    required String sourceId,
    required String sourceInstitutionId,
    required LocationScope targetScope,
    required String name,
    required String requestId,
  }) async => throw const LocationCatalogWriteUnavailableException();

  @override
  Future<LocationSchedule> readSchedule({required String locationId}) async =>
      throw const LocationCatalogWriteUnavailableException();

  @override
  Future<LocationSchedule> setSchedule({
    required String locationId,
    required List<LocationScheduleWindow> windows,
    required int expectedVersion,
    required String requestId,
  }) async => throw const LocationCatalogWriteUnavailableException();
}

final class LocationCatalogWriteUnavailableException implements Exception {
  const LocationCatalogWriteUnavailableException();

  @override
  String toString() => 'Location write unavailable';
}
