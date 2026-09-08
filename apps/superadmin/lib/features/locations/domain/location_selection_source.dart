/// Minimal read/selection contract for consumers of the location catalog.
///
/// Forms, Agenda, Atividades and Turmas select a location; none of them owns
/// the catalog. This source exposes only what a consumer legitimately needs:
/// selectable options for a scope and the resolution of a snapshot it already
/// holds. It never grants access, never reserves a space and never turns a
/// one-off text into a catalog entry.
///
/// Session availability is a render gate. Authorization stays server-side on
/// every request, and every identifier a consumer supplies is revalidated
/// there.
library;

import 'package:coelo_domain/locations.dart';

import 'location_catalog_reader.dart';

/// How many options a consumer may request at once.
///
/// A selection field is not a directory: consumers narrow by search instead of
/// paging. The cap is enforced before transport so a hostile or buggy caller
/// cannot widen the read.
const int locationSelectionMaxLimit = 20;

final class LocationSelectionRequest {
  const LocationSelectionRequest({required this.scope, this.search, this.limit = 10});

  final LocationScope scope;
  final String? search;
  final int limit;
}

/// Result of one selection read.
///
/// [options] carries snapshots, not catalog entities: a consumer must not infer
/// status, visibility or permission from them. [truncated] tells the consumer
/// that more options exist for the scope, so it can ask the user to refine the
/// search instead of implying the list is complete.
final class LocationSelectionOptions {
  LocationSelectionOptions({
    required List<LocationReferenceSnapshot> options,
    this.truncated = false,
  }) : options = List.unmodifiable(options);

  final List<LocationReferenceSnapshot> options;
  final bool truncated;
}

/// Whether a snapshot the consumer already holds may still be offered.
///
/// `notSelectable` means the entry is readable but no longer active, so the
/// consumer may keep rendering it as a historical reference without offering it
/// as a new choice. Absence is not modelled here: the catalog does not
/// distinguish "deleted" from "not readable by you", and this contract must not
/// invent that difference.
enum LocationSnapshotResolution { selectable, notSelectable }

final class LocationResolvedSnapshot {
  const LocationResolvedSnapshot({required this.resolution, required this.snapshot});

  final LocationSnapshotResolution resolution;
  final LocationReferenceSnapshot snapshot;
}

abstract interface class LocationSelectionSource {
  /// Active options a consumer may offer for [request].
  ///
  /// Throws [LocationCatalogAccessDeniedException] when the server denies the
  /// read and [LocationSelectionUnavailableException] for every other failure,
  /// without retaining server messages or payloads.
  Future<LocationSelectionOptions> fetchOptions(LocationSelectionRequest request);

  /// Re-reads a snapshot the consumer already stored.
  ///
  /// Consumers call this before reusing a saved selection: a location may have
  /// been renamed, deactivated or moved out of reach since it was chosen.
  Future<LocationResolvedSnapshot> resolveSnapshot({
    required String id,
    required LocationScope scope,
  });
}

final class LocationSelectionUnavailableException implements Exception {
  const LocationSelectionUnavailableException();

  @override
  String toString() => 'Location selection unavailable';
}

/// Only active entries may be offered as a new choice.
///
/// Draft, inactive, suspended and archived entries stay out of the picker even
/// when the reader returns them, so a consumer cannot schedule against a space
/// the institution has taken out of service.
bool selectableLocationStatus(LocationCatalogStatus status) =>
    status == LocationCatalogStatus.active;

LocationReferenceSnapshot locationSnapshotOf(LocationCatalogEntry entry) =>
    LocationReferenceSnapshot(
      id: entry.id,
      scope: entry.scope,
      kind: entry.kind,
      label: entry.name,
    );

/// Adapts the existing catalog reader; it adds no transport of its own.
///
/// The reader already validates envelope, shape, ownership and identifiers, so
/// this source only applies the selection rules on top of it and refuses
/// anything whose scope does not match what the consumer asked for.
final class CatalogLocationSelectionSource implements LocationSelectionSource {
  const CatalogLocationSelectionSource(this._reader);

  final LocationCatalogReader _reader;

  @override
  Future<LocationSelectionOptions> fetchOptions(LocationSelectionRequest request) async {
    final search = request.search?.replaceAll(RegExp(r'^ +| +$'), '');
    if (!validLocationScope(request.scope) ||
        request.limit < 1 ||
        request.limit > locationSelectionMaxLimit) {
      throw const LocationSelectionUnavailableException();
    }
    // One extra row answers "is there more" without a second read.
    final result = await _read(
      () => _reader.fetchDirectory(
        LocationDirectoryRequest(
          scope: request.scope,
          search: search == null || search.isEmpty ? null : search,
          limit: request.limit + 1,
        ),
      ),
    );
    final matching = result.items
        .where((entry) => sameLocationScope(entry.scope, request.scope))
        .toList(growable: false);
    if (matching.length != result.items.length) {
      throw const LocationSelectionUnavailableException();
    }
    final selectable = matching.where((entry) => selectableLocationStatus(entry.status)).toList();
    final truncated = matching.length > request.limit || result.totalCount > matching.length;
    return LocationSelectionOptions(
      options: selectable.take(request.limit).map(locationSnapshotOf).toList(growable: false),
      truncated: truncated,
    );
  }

  @override
  Future<LocationResolvedSnapshot> resolveSnapshot({
    required String id,
    required LocationScope scope,
  }) async {
    if (!validLocationId(id) || !validLocationScope(scope)) {
      throw const LocationSelectionUnavailableException();
    }
    final entry = await _read(() => _reader.fetchDetail(id));
    if (entry.id != id || !sameLocationScope(entry.scope, scope)) {
      // A mismatched owner is never presented as the consumer's location.
      throw const LocationSelectionUnavailableException();
    }
    return LocationResolvedSnapshot(
      resolution: selectableLocationStatus(entry.status)
          ? LocationSnapshotResolution.selectable
          : LocationSnapshotResolution.notSelectable,
      snapshot: locationSnapshotOf(entry),
    );
  }

  Future<T> _read<T>(Future<T> Function() read) async {
    try {
      return await read();
    } on LocationCatalogAccessDeniedException {
      rethrow;
    } on Object {
      throw const LocationSelectionUnavailableException();
    }
  }
}

/// Default composition before a session exists; every read fails honestly.
final class UnavailableLocationSelectionSource implements LocationSelectionSource {
  const UnavailableLocationSelectionSource();

  @override
  Future<LocationSelectionOptions> fetchOptions(LocationSelectionRequest request) async =>
      throw const LocationSelectionUnavailableException();

  @override
  Future<LocationResolvedSnapshot> resolveSnapshot({
    required String id,
    required LocationScope scope,
  }) async => throw const LocationSelectionUnavailableException();
}
