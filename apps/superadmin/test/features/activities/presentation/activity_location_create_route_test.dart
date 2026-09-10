import 'dart:convert';
import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/activities/data/supabase_activity_command_repository.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_catalogued_location_section.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/auth/domain/superadmin_auth_context.dart';
import 'package:coelo_superadmin/features/locations/domain/location_catalog_reader.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_selection_field.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../support/activities/fake_activity_directory_repository.dart';
import '../../locations/location_read_fixtures.dart';

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

void main() {
  for (final enabled in [false, true]) {
    final requests = <Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async {
        requests.add(r);
        return Response(
          jsonEncode({
            'ok': true,
            'error': null,
            'data': {
              'activity_id': '40000000-0000-4000-8000-000000000001',
              'management_version': 1,
              'status': 'draft',
              'correlation_id': '40000000-0000-4000-8000-000000000002',
              'replayed': false,
              'location_id': locationA,
              'reservation': null,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: r,
        );
      }),
    );
    tearDownAll(client.dispose);
    testWidgets('normal create catalog gate=$enabled composes a single atomic request', (
      tester,
    ) async {
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
          sessionId: 'atomic-create',
        );

      addTearDown(session.dispose);
      final catalog = _Catalog();
      final router = createSuperadminRouter(
        session: session,
        login: unavailableSuperadminLogin,
        logout: unavailableSuperadminLogout,
        requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
        onThemeModeChanged: (_) {},
        activityDirectoryRepository: _Directory(),
        activityCommandRepository: SupabaseActivityCommandRepository(
          client,
          activityLocationCreateAvailable: enabled,
        ),
        enableStructureMutations: true,
        enableActivityLocationCreate: enabled,
        locationCatalogReader: catalog,
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
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
      expect(find.byKey(const Key('activity-form-location')), findsNothing);
      if (!enabled) {
        expect(find.byKey(const Key('activity-catalogued-location-unavailable')), findsOneWidget);
        expect(catalog.calls, isEmpty);
        expect(requests, isEmpty);
        return;
      }
      final field = tester.widget<LocationSelectionField>(find.byType(LocationSelectionField));
      expect(field.scope.institutionId, institutionA);
      await tester.ensureVisible(find.byKey(const Key('location-selection-option')));
      await tester.tap(find.byKey(const Key('location-selection-option')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Sala de leitura').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sala de leitura').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('activity-form-save-draft')));
      await tester.pumpAndSettle();
      expect(requests, hasLength(1));
      expect(requests.single.url.path, endsWith('/rpc/superadmin_activity_location_create_v2'));
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['p_location_id'], locationA);
      expect(body['p_reservation'], isNull);
      final payload = body['p_activity_payload'] as Map<String, dynamic>;
      expect(payload['institution_id'], institutionA);
      expect(payload['unit_ids'], [unitA]);
      expect(tester.takeException(), isNull);
    });
  }
}
