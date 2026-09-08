import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/locations/domain/location_catalog_reader.dart';
import 'package:coelo_superadmin/features/locations/domain/location_selection_source.dart';
import 'package:flutter_test/flutter_test.dart';

import 'location_read_fixtures.dart';

void main() {
  test('options request one extra row and report truncation without a second read', () async {
    final reader = ControlledLocationReader();
    final source = CatalogLocationSelectionSource(reader);
    final options = source.fetchOptions(
      const LocationSelectionRequest(scope: scopeA, search: '  sala  '),
    );
    await Future<void>.delayed(Duration.zero);
    expect(reader.directories, hasLength(1));
    expect(reader.directories.single.request.limit, 11);
    expect(reader.directories.single.request.offset, 0);
    expect(reader.directories.single.request.search, 'sala');
    reader.directories.single.result.complete(
      LocationDirectoryResult(
        items: [
          for (var index = 0; index < 11; index += 1)
            locationFixture(id: _id(index), name: 'Sala $index'),
        ],
        totalCount: 40,
      ),
    );
    final result = await options;
    expect(reader.directories, hasLength(1));
    expect(result.options, hasLength(10));
    expect(result.truncated, isTrue);
    expect(result.options.first.label, 'Sala 0');
  });

  test('a complete short page is not reported as truncated', () async {
    final reader = ControlledLocationReader();
    final source = CatalogLocationSelectionSource(reader);
    final options = source.fetchOptions(const LocationSelectionRequest(scope: scopeA));
    await Future<void>.delayed(Duration.zero);
    reader.directories.single.result.complete(locationPage());
    final result = await options;
    expect(result.options, hasLength(1));
    expect(result.truncated, isFalse);
  });

  test('only active entries become selectable options', () async {
    final reader = ControlledLocationReader();
    final source = CatalogLocationSelectionSource(reader);
    final options = source.fetchOptions(const LocationSelectionRequest(scope: scopeA));
    await Future<void>.delayed(Duration.zero);
    reader.directories.single.result.complete(
      LocationDirectoryResult(
        items: [
          locationFixture(id: _id(0), status: LocationCatalogStatus.active),
          locationFixture(id: _id(1), status: LocationCatalogStatus.draft),
          locationFixture(id: _id(2), status: LocationCatalogStatus.inactive),
          locationFixture(id: _id(3), status: LocationCatalogStatus.suspended),
          locationFixture(id: _id(4), status: LocationCatalogStatus.archived),
        ],
        totalCount: 5,
      ),
    );
    final result = await options;
    expect(result.options.map((option) => option.id), [_id(0)]);
    expect(result.truncated, isFalse);
  });

  test('a page carrying another owner is refused instead of filtered', () async {
    final reader = ControlledLocationReader();
    final source = CatalogLocationSelectionSource(reader);
    final options = source.fetchOptions(const LocationSelectionRequest(scope: scopeA));
    await Future<void>.delayed(Duration.zero);
    reader.directories.single.result.complete(
      LocationDirectoryResult(
        items: [
          locationFixture(id: _id(0)),
          locationFixture(id: _id(1), scope: scopeB),
        ],
        totalCount: 2,
      ),
    );
    await expectLater(options, throwsA(isA<LocationSelectionUnavailableException>()));
  });

  test('invalid scope and limits never reach transport', () async {
    final reader = ControlledLocationReader();
    final source = CatalogLocationSelectionSource(reader);
    await expectLater(
      source.fetchOptions(
        const LocationSelectionRequest(
          scope: LocationScope.institution(institutionId: 'not-a-uuid'),
        ),
      ),
      throwsA(isA<LocationSelectionUnavailableException>()),
    );
    await expectLater(
      source.fetchOptions(const LocationSelectionRequest(scope: scopeA, limit: 0)),
      throwsA(isA<LocationSelectionUnavailableException>()),
    );
    await expectLater(
      source.fetchOptions(
        const LocationSelectionRequest(scope: scopeA, limit: locationSelectionMaxLimit + 1),
      ),
      throwsA(isA<LocationSelectionUnavailableException>()),
    );
    expect(reader.directories, isEmpty);
  });

  test('unit scope is sent as its own catalog, never widened to the institution', () async {
    final reader = ControlledLocationReader();
    final source = CatalogLocationSelectionSource(reader);
    final options = source.fetchOptions(const LocationSelectionRequest(scope: scopeUnitA));
    await Future<void>.delayed(Duration.zero);
    expect(reader.directories.single.request.scope, isA<UnitLocationScope>());
    reader.directories.single.result.complete(locationPage(scope: scopeUnitA));
    final result = await options;
    expect(result.options.single.scope, isA<UnitLocationScope>());
  });

  test('denied read stays denied and other failures are sanitized', () async {
    final reader = ControlledLocationReader();
    final source = CatalogLocationSelectionSource(reader);
    final denied = source.fetchOptions(const LocationSelectionRequest(scope: scopeA));
    await Future<void>.delayed(Duration.zero);
    reader.directories.single.result.completeError(const LocationCatalogAccessDeniedException());
    await expectLater(denied, throwsA(isA<LocationCatalogAccessDeniedException>()));

    final failed = source.fetchOptions(const LocationSelectionRequest(scope: scopeA));
    await Future<void>.delayed(Duration.zero);
    reader.directories.last.result.completeError(StateError('raw server detail'));
    await expectLater(failed, throwsA(isA<LocationSelectionUnavailableException>()));
  });

  test('an active snapshot resolves as selectable', () async {
    final reader = ControlledLocationReader();
    final source = CatalogLocationSelectionSource(reader);
    final resolving = source.resolveSnapshot(id: locationA, scope: scopeA);
    await Future<void>.delayed(Duration.zero);
    expect(reader.details.single.id, locationA);
    reader.details.single.result.complete(locationFixture());
    final resolved = await resolving;
    expect(resolved.resolution, LocationSnapshotResolution.selectable);
    expect(resolved.snapshot.id, locationA);
    expect(resolved.snapshot.kind, LocationKind.internal);
  });

  test('an inactive snapshot resolves as historical reference, not as an option', () async {
    final reader = ControlledLocationReader();
    final source = CatalogLocationSelectionSource(reader);
    final resolving = source.resolveSnapshot(id: locationA, scope: scopeA);
    await Future<void>.delayed(Duration.zero);
    reader.details.single.result.complete(locationFixture(status: LocationCatalogStatus.inactive));
    final resolved = await resolving;
    expect(resolved.resolution, LocationSnapshotResolution.notSelectable);
    expect(resolved.snapshot.label, 'Sala de leitura');
  });

  test('a detail answering another id or owner is refused', () async {
    final reader = ControlledLocationReader();
    final source = CatalogLocationSelectionSource(reader);
    final wrongId = source.resolveSnapshot(id: locationA, scope: scopeA);
    await Future<void>.delayed(Duration.zero);
    reader.details.single.result.complete(locationFixture(id: locationB));
    await expectLater(wrongId, throwsA(isA<LocationSelectionUnavailableException>()));

    final wrongOwner = source.resolveSnapshot(id: locationA, scope: scopeA);
    await Future<void>.delayed(Duration.zero);
    reader.details.last.result.complete(locationFixture(scope: scopeB));
    await expectLater(wrongOwner, throwsA(isA<LocationSelectionUnavailableException>()));
  });

  test('malformed identifiers never reach transport on resolve', () async {
    final reader = ControlledLocationReader();
    final source = CatalogLocationSelectionSource(reader);
    await expectLater(
      source.resolveSnapshot(id: 'not-a-uuid', scope: scopeA),
      throwsA(isA<LocationSelectionUnavailableException>()),
    );
    await expectLater(
      source.resolveSnapshot(
        id: locationA,
        scope: const LocationScope.unit(institutionId: institutionA, unitId: 'not-a-uuid'),
      ),
      throwsA(isA<LocationSelectionUnavailableException>()),
    );
    expect(reader.details, isEmpty);
  });

  test('the default source is unavailable, never an empty option list', () async {
    const source = UnavailableLocationSelectionSource();
    await expectLater(
      source.fetchOptions(const LocationSelectionRequest(scope: scopeA)),
      throwsA(isA<LocationSelectionUnavailableException>()),
    );
    await expectLater(
      source.resolveSnapshot(id: locationA, scope: scopeA),
      throwsA(isA<LocationSelectionUnavailableException>()),
    );
  });

  test('a one-off selection keeps its text and fabricates no catalog id', () {
    const selection = LocationSelection.oneOff('Praça da esquina');
    expect(selection, isA<OneOffLocationSelection>());
    expect((selection as OneOffLocationSelection).text, 'Praça da esquina');
  });
}

String _id(int index) =>
    '10000000-0000-4000-8000-00000000${(index + 10).toString().padLeft(4, '0')}';
