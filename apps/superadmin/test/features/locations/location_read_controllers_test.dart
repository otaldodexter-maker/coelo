import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/locations/domain/location_catalog_reader.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_directory_controller.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_detail_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'location_read_fixtures.dart';

void main() {
  test('shrinking total recovers once to a valid page', () async {
    final reader = ControlledLocationReader();
    final controller = LocationDirectoryController(
      reader: reader,
      scope: scopeA,
      sessionAvailable: true,
    );
    var loading = controller.load();
    reader.directories.last.result.complete(locationPage(total: 40));
    await loading;
    loading = controller.goToPage(2);
    reader.directories.last.result.complete(LocationDirectoryResult(items: [], totalCount: 1));
    await Future<void>.delayed(Duration.zero);
    expect(reader.directories, hasLength(3));
    expect(reader.directories.last.request.offset, 0);
    reader.directories.last.result.complete(locationPage());
    await loading;
    expect(controller.page, 0);
    expect(controller.state, LocationReadState.ready);
    controller.dispose();
  });
  test('default reader is unavailable, never a runtime fixture', () async {
    final controller = LocationDirectoryController(scope: scopeA, sessionAvailable: true);
    await controller.load();
    expect(controller.state, LocationReadState.unavailable);
    expect(controller.data, isNull);
    controller.dispose();
  });
  test('directory absent session never calls reader', () async {
    final reader = ControlledLocationReader();
    final controller = LocationDirectoryController(reader: reader, scope: scopeA);
    await controller.load();
    expect(reader.directories, isEmpty);
    expect(controller.state, LocationReadState.denied);
    controller.dispose();
  });
  test('directory reads explicit scope and query defaults', () async {
    final reader = ControlledLocationReader();
    final controller = LocationDirectoryController(
      reader: reader,
      scope: scopeA,
      sessionAvailable: true,
    );
    final loading = controller.load();
    expect(controller.data, isNull);
    expect(reader.directories.single.request.scope, scopeA);
    expect(reader.directories.single.request.limit, 11);
    expect(reader.directories.single.request.offset, 0);
    reader.directories.single.result.complete(locationPage());
    await loading;
    expect(controller.state, LocationReadState.ready);
    controller.dispose();
  });
  test('search resets page and empty search has distinct state', () async {
    final reader = ControlledLocationReader();
    final controller = LocationDirectoryController(
      reader: reader,
      scope: scopeA,
      sessionAvailable: true,
    );
    var loading = controller.load();
    reader.directories.last.result.complete(locationPage(total: 40));
    await loading;
    loading = controller.goToPage(1);
    expect(reader.directories.last.request.offset, 11);
    reader.directories.last.result.complete(locationPage(total: 40));
    await loading;
    loading = controller.setSearch('  livro  ');
    expect(controller.page, 0);
    expect(controller.data, isNull);
    expect(reader.directories.last.request.search, 'livro');
    reader.directories.last.result.complete(LocationDirectoryResult(items: [], totalCount: 0));
    await loading;
    expect(controller.state, LocationReadState.noResults);
    loading = controller.setSearch('');
    reader.directories.last.result.complete(LocationDirectoryResult(items: [], totalCount: 0));
    await loading;
    expect(controller.state, LocationReadState.empty);
    controller.dispose();
  });
  test('directory context replacement clears data and ignores late old success', () async {
    final reader = ControlledLocationReader();
    final controller = LocationDirectoryController(
      reader: reader,
      scope: scopeA,
      sessionAvailable: true,
    );
    final old = controller.load();
    final newer = controller.load(scope: scopeB);
    reader.directories.last.result.complete(locationPage(scope: scopeB));
    await newer;
    reader.directories.first.result.complete(locationPage());
    await old;
    expect(controller.data!.items.single.scope.institutionId, institutionB);
    controller.dispose();
  });
  test('directory loss of session immediately removes loaded data', () async {
    final reader = ControlledLocationReader();
    final controller = LocationDirectoryController(
      reader: reader,
      scope: scopeA,
      sessionAvailable: true,
    );
    final load = controller.load();
    reader.directories.last.result.complete(locationPage());
    await load;
    await controller.load(sessionAvailable: false);
    expect(controller.data, isNull);
    expect(controller.state, LocationReadState.denied);
    expect(reader.directories, hasLength(1));
    controller.dispose();
  });
  test('directory denied and unavailable errors retain no payload', () async {
    final reader = ControlledLocationReader();
    final controller = LocationDirectoryController(
      reader: reader,
      scope: scopeA,
      sessionAvailable: true,
    );
    var load = controller.load();
    reader.directories.last.result.completeError(const LocationCatalogAccessDeniedException());
    await load;
    expect(controller.state, LocationReadState.denied);
    load = controller.load();
    reader.directories.last.result.completeError(StateError('PRIVATE ERROR'));
    await load;
    expect(controller.state, LocationReadState.unavailable);
    expect(controller.data, isNull);
    controller.dispose();
  });
  test('directory owner mismatch is unavailable rather than disclosed', () async {
    final reader = ControlledLocationReader();
    final controller = LocationDirectoryController(
      reader: reader,
      scope: scopeA,
      sessionAvailable: true,
    );
    final load = controller.load();
    reader.directories.last.result.complete(locationPage(scope: scopeB));
    await load;
    expect(controller.state, LocationReadState.unavailable);
    expect(controller.data, isNull);
    controller.dispose();
  });
  test('directory reentrant listener prevents outdated dispatch', () async {
    final reader = ControlledLocationReader();
    final controller = LocationDirectoryController(
      reader: reader,
      scope: scopeA,
      sessionAvailable: true,
    );
    var invalidated = false;
    controller.addListener(() {
      if (!invalidated) {
        invalidated = true;
        controller.load(sessionAvailable: false);
      }
    });
    await controller.load();
    expect(reader.directories, isEmpty);
    expect(controller.state, LocationReadState.denied);
    controller.dispose();
  });
  test('directory dispose ignores late completion', () async {
    final reader = ControlledLocationReader();
    final controller = LocationDirectoryController(
      reader: reader,
      scope: scopeA,
      sessionAvailable: true,
    );
    var notifications = 0;
    controller.addListener(() => notifications++);
    final load = controller.load();
    controller.dispose();
    reader.directories.last.result.complete(locationPage());
    await load;
    expect(notifications, 1);
    expect(controller.data, isNull);
  });
  test('directory caps accessible pagination without losing global count', () async {
    final reader = ControlledLocationReader();
    final controller = LocationDirectoryController(
      reader: reader,
      scope: scopeA,
      sessionAvailable: true,
    );
    final load = controller.load();
    reader.directories.last.result.complete(locationPage(total: 20000));
    await load;
    expect(controller.totalPages, 910);
    expect(controller.windowLimited, isTrue);
    expect(controller.data!.totalCount, 20000);
    await controller.goToPage(910);
    expect(reader.directories, hasLength(1));
    controller.dispose();
  });
  test('invalid search is rejected before dispatch', () async {
    final reader = ControlledLocationReader();
    final controller = LocationDirectoryController(
      reader: reader,
      scope: scopeA,
      sessionAvailable: true,
    );
    await controller.setSearch('x' * 121);
    expect(reader.directories, isEmpty);
    expect(controller.state, LocationReadState.unavailable);
    controller.dispose();
  });
  test('detail absent session never calls reader', () async {
    final reader = ControlledLocationReader();
    final controller = LocationDetailController(reader: reader, id: locationA, scope: scopeA);
    await controller.load();
    expect(reader.details, isEmpty);
    expect(controller.state, LocationReadState.denied);
    controller.dispose();
  });
  test('detail loads and reload clears immediately', () async {
    final reader = ControlledLocationReader();
    final controller = LocationDetailController(
      reader: reader,
      id: locationA,
      scope: scopeA,
      sessionAvailable: true,
    );
    var load = controller.load();
    reader.details.last.result.complete(locationFixture());
    await load;
    expect(controller.data!.id, locationA);
    load = controller.load();
    expect(controller.data, isNull);
    reader.details.last.result.completeError(const LocationCatalogAccessDeniedException());
    await load;
    expect(controller.state, LocationReadState.denied);
    controller.dispose();
  });
  for (final wrong in [locationFixture(id: locationB), locationFixture(scope: scopeB)]) {
    test('detail rejects mismatched id/scope ${wrong.id} ${wrong.scope.institutionId}', () async {
      final reader = ControlledLocationReader();
      final controller = LocationDetailController(
        reader: reader,
        id: locationA,
        scope: scopeA,
        sessionAvailable: true,
      );
      final load = controller.load();
      reader.details.last.result.complete(wrong);
      await load;
      expect(controller.data, isNull);
      expect(controller.state, LocationReadState.unavailable);
      controller.dispose();
    });
  }
  test('detail revision replacement ignores stale error', () async {
    final reader = ControlledLocationReader();
    final controller = LocationDetailController(
      reader: reader,
      id: locationA,
      scope: scopeA,
      sessionAvailable: true,
    );
    final old = controller.load();
    final newer = controller.load(contextRevision: 1);
    reader.details.last.result.complete(locationFixture());
    await newer;
    reader.details.first.result.completeError(const LocationCatalogAccessDeniedException());
    await old;
    expect(controller.state, LocationReadState.ready);
    controller.dispose();
  });
  test('detail invalid ID never dispatches', () async {
    final reader = ControlledLocationReader();
    final controller = LocationDetailController(
      reader: reader,
      id: 'invalid',
      scope: scopeA,
      sessionAvailable: true,
    );
    await controller.load();
    expect(reader.details, isEmpty);
    expect(controller.state, LocationReadState.denied);
    controller.dispose();
  });
  test('detail dispose and late error cause no notification', () async {
    final reader = ControlledLocationReader();
    final controller = LocationDetailController(
      reader: reader,
      id: locationA,
      scope: scopeA,
      sessionAvailable: true,
    );
    var notifications = 0;
    controller.addListener(() => notifications++);
    final load = controller.load();
    controller.dispose();
    reader.details.last.result.completeError(StateError('late'));
    await load;
    expect(notifications, 1);
    expect(controller.data, isNull);
  });
}
