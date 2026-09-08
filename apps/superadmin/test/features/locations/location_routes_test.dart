import 'package:coelo_api/children.dart';
import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/locations/domain/location_catalog_reader.dart';
import 'package:coelo_superadmin/features/units/domain/unit_detail.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';

import 'location_read_fixtures.dart';

final class _RecordingReader implements LocationCatalogReader {
  final directories = <LocationDirectoryRequest>[];
  final details = <String>[];
  Object? failure;

  @override
  Future<LocationDirectoryResult> fetchDirectory(LocationDirectoryRequest request) async {
    directories.add(request);
    if (failure != null) throw failure!;
    return locationPage(scope: request.scope);
  }

  @override
  Future<LocationCatalogEntry> fetchDetail(String id) async {
    details.add(id);
    if (failure != null) throw failure!;
    return locationFixture(id: id);
  }
}

final class _RecordingUnitDetail implements UnitDetailRepository {
  final String institutionId = institutionA;
  final requested = <String>[];
  UnitDetailFailure? failure;

  @override
  Future<UnitDetail> fetchById(String unitId) async {
    requested.add(unitId);
    if (failure != null) throw UnitDetailException(failure!);
    return UnitDetail(
      id: unitId,
      name: 'Unidade sintética',
      slug: 'unidade-sintetica',
      status: 'active',
      institutionId: institutionId,
      institutionName: 'Instituição sintética',
      institutionType: null,
      unitType: const UnitDetailType(id: 'school', name: 'Escola'),
      address: null,
      contact: null,
      effectivePlan: null,
    );
  }
}

final class _RecordingChildRead {
  final requests = <ChildDirectoryRequest>[];

  Future<ChildDirectoryPage> call(ChildDirectoryRequest request) async {
    requests.add(request);
    return ChildDirectoryPage(items: const [], nextCursor: null);
  }
}

void main() {
  test('location routes carry their owner and never expose a scope-less catalog', () {
    expect(SuperadminRoutes.institutionLocations, '/institutions/:institutionId/locations');
    expect(
      SuperadminRoutes.institutionLocationDetail,
      '/institutions/:institutionId/locations/:locationId',
    );
    expect(SuperadminRoutes.unitLocations, '/units/:unitId/locations');
    expect(SuperadminRoutes.unitLocationDetail, '/units/:unitId/locations/:locationId');
    expect(SuperadminRoutes.studentsDirectory, '/students/directory');
    for (final path in const [
      SuperadminRoutes.institutionLocations,
      SuperadminRoutes.unitLocations,
      SuperadminRoutes.studentsDirectory,
    ]) {
      expect(path, isNot(startsWith('/dev/')));
    }
  });

  ({
    GoRouterHarness harness,
    _RecordingReader reader,
    _RecordingUnitDetail units,
    _RecordingChildRead children,
    SuperadminSession session,
  })
  build(WidgetTester tester) {
    final session = SuperadminSession()..signInForTesting();
    final reader = _RecordingReader();
    final units = _RecordingUnitDetail();
    final children = _RecordingChildRead();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      locationCatalogReader: reader,
      unitDetailRepository: units,
      childDirectoryRead: children.call,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    return (
      harness: GoRouterHarness(router),
      reader: reader,
      units: units,
      children: children,
      session: session,
    );
  }

  testWidgets('the institution catalog reads the owner taken from the route', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final context = build(tester);
    await context.harness.pump(tester);

    context.harness.router.go('/institutions/$institutionA/locations');
    await tester.pumpAndSettle();
    expect(context.reader.directories.single.scope, isA<InstitutionLocationScope>());
    expect(context.reader.directories.single.scope.institutionId, institutionA);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a location link opens the detail of that id only', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final context = build(tester);
    await context.harness.pump(tester);

    context.harness.router.go('/institutions/$institutionA/locations/$locationB');
    await tester.pumpAndSettle();
    expect(context.reader.details, [locationB]);
    expect(context.reader.directories, isEmpty);
  });

  testWidgets('a malformed owner in the route is denied without any read', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final context = build(tester);
    await context.harness.pump(tester);

    context.harness.router.go('/institutions/not-a-uuid/locations');
    await tester.pumpAndSettle();
    expect(context.reader.directories, isEmpty);
    expect(find.byKey(const Key('location-directory-denied')), findsOneWidget);
  });

  testWidgets('the unit catalog takes its institution from the authorized detail', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final context = build(tester);
    await context.harness.pump(tester);

    context.harness.router.go('/units/$unitA/locations');
    await tester.pumpAndSettle();
    expect(context.units.requested, [unitA]);
    final scope = context.reader.directories.single.scope;
    expect(scope, isA<UnitLocationScope>());
    expect((scope as UnitLocationScope).unitId, unitA);
    // The institution comes from the unit detail, not from the URL.
    expect(scope.institutionId, institutionA);
  });

  testWidgets('a denied unit detail never reaches the catalog read', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final context = build(tester);
    context.units.failure = UnitDetailFailure.denied;
    await context.harness.pump(tester);

    context.harness.router.go('/units/$unitA/locations');
    await tester.pumpAndSettle();
    expect(context.reader.directories, isEmpty);
    expect(find.byKey(const Key('unit-locations-gate-denied')), findsOneWidget);
  });

  testWidgets('a revoked authorization rebuilds the catalog instead of keeping data', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final context = build(tester);
    await context.harness.pump(tester);

    context.harness.router.go('/institutions/$institutionA/locations');
    await tester.pumpAndSettle();
    expect(context.reader.directories, hasLength(1));

    context.session.signOut();
    await tester.pumpAndSettle();
    expect(find.text('Sala de leitura'), findsNothing);
  });

  testWidgets('reloading the same route reads again instead of serving stale data', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final context = build(tester);
    await context.harness.pump(tester);

    context.harness.router.go('/institutions/$institutionA/locations');
    await tester.pumpAndSettle();
    context.harness.router.go('/institutions/$institutionB/locations');
    await tester.pumpAndSettle();
    expect(context.reader.directories, hasLength(2));
    expect(context.reader.directories.last.scope.institutionId, institutionB);
  });

  testWidgets('the students directory route uses the injected CHILD read', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final context = build(tester);
    await context.harness.pump(tester);

    context.harness.router.go(SuperadminRoutes.studentsDirectory);
    await tester.pumpAndSettle();
    expect(context.children.requests, hasLength(1));
    expect(context.children.requests.single.after, isNull);
    expect(find.byKey(const Key('child-directory-empty')), findsOneWidget);
  });
}

final class GoRouterHarness {
  GoRouterHarness(this.router);

  final GoRouter router;

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
  }
}
