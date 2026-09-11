import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/app/superadmin_app.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/account/data/user_preferences_repository.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_catalogued_location_section.dart';
import 'package:coelo_superadmin/features/auth/domain/superadmin_auth_context.dart';
import 'package:coelo_superadmin/features/locations/domain/location_catalog_reader.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import '../features/locations/location_read_fixtures.dart';
import '../support/activities/fake_activity_directory_repository.dart';

const taxonomy = ActivityTaxonomyOption(
  id: '50000000-0000-4000-8000-000000000001',
  label: 'Oficina',
);

class _Directory extends FakeActivityDirectoryRepository {
  @override
  Future<ActivityFormOptions> fetchFormOptions({required String institutionId}) async =>
      const ActivityFormOptions(
        institutions: [ActivityFormInstitutionOption(id: institutionA, name: 'Instituicao real')],
        units: [
          ActivityFormUnitOption(id: unitA, institutionId: institutionA, name: 'Unidade real'),
        ],
        taxonomy: [taxonomy],
      );
}

class _Catalog implements LocationCatalogReader {
  final calls = <LocationDirectoryRequest>[];
  @override
  Future<LocationDirectoryResult> fetchDirectory(LocationDirectoryRequest r) async {
    calls.add(r);
    return locationPage(scope: r.scope);
  }

  @override
  Future<LocationCatalogEntry> fetchDetail(String id) async => locationFixture(id: id);
}

// A chave activityLocationCreateEnabled do SuperadminApp e o que main.dart liga
// depois de 180150 estar em producao; sem ela o formulario mostra o painel de
// indisponibilidade mesmo com o catalogo e as permissoes presentes.
void main() {
  for (final enabled in [false, true]) {
    testWidgets('App forwards the activity location create gate $enabled', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final session = SuperadminSession()
        ..authorize(
          const SuperadminAuthContext(
            platformRoleCode: 'test',
            scopeKind: SuperadminAuthScopeKind.platform,
            permissionCodes: {
              'activities.read',
              'activities.create',
              'activities.link_units',
              'activities.link_groups',
              'activities.assign_people',
              'activities.manage_permissions',
              'locations.read',
            },
            aal: 'aal1',
          ),
          sessionId: 'activity-location-app-session',
        );
      addTearDown(session.dispose);
      final catalog = _Catalog();
      await tester.pumpWidget(
        SuperadminApp(
          session: session,
          userPreferencesRepository: InMemoryUserPreferencesRepository(),
          activityDirectoryRepository: _Directory(),
          structureMutationsEnabled: true,
          activityLocationCreateEnabled: enabled,
          locationCatalogReader: catalog,
        ),
      );
      await tester.pumpAndSettle();
      final router = tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;
      router.go('/activities/new?institutionId=$institutionA&unitId=$unitA');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('activity-form-name')), 'Oficina');
      await tester.enterText(find.byKey(const Key('activity-form-initials')), 'OF');
      tester
          .widget<CoeloAdminSingleSelectField<ActivityTaxonomyOption?>>(
            find.byKey(const Key('activity-form-category')),
          )
          .onChanged(taxonomy);
      await tester.pump();
      await tester.tap(find.byKey(const Key('activity-form-continue')));
      await tester.pumpAndSettle();
      expect(find.byType(ActivityCataloguedLocationSection), findsOneWidget);
      expect(
        find.byKey(const Key('activity-catalogued-location-unavailable')),
        enabled ? findsNothing : findsOneWidget,
      );
      expect(catalog.calls, enabled ? isNotEmpty : isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
