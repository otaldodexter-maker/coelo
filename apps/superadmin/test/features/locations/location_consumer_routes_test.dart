import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/auth/domain/superadmin_auth_context.dart';
import 'package:coelo_superadmin/features/groups/domain/group_detail.dart';
import 'package:coelo_superadmin/features/locations/domain/location_catalog_reader.dart';
import 'package:coelo_superadmin/features/locations/domain/location_reservation_gateway.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_consumer_reservations.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_reservation_panel.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'location_read_fixtures.dart';

const groupId = '40000000-0000-4000-8000-000000000001';

class _Groups implements GroupDetailRepository {
  @override
  Future<GroupDetail> fetchById(String id) async => GroupDetail(
    id: id,
    institutionId: institutionA,
    institutionName: 'Instituição autorizada',
    unitId: unitA,
    unitName: 'Unidade autorizada',
    name: 'Turma autorizada',
    groupType: 'class',
    groupTypeOtherText: null,
    status: 'active',
    inheritAppearance: true,
    inheritAccess: true,
    inheritActivities: true,
    managementVersion: 1,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

class _Catalog implements LocationCatalogReader {
  @override
  Future<LocationDirectoryResult> fetchDirectory(LocationDirectoryRequest request) async =>
      locationPage(scope: request.scope);
  @override
  Future<LocationCatalogEntry> fetchDetail(String id) async => locationFixture(id: id);
}

class _Reservations implements LocationReservationGateway {
  final consumers = <LocationReservationConsumer>[];
  @override
  bool get available => true;
  @override
  Future<LocationSchedulingPolicyState> getPolicy({
    required String locationId,
    required LocationScope scope,
  }) async => LocationSchedulingPolicyState(
    scope: scope,
    policy: LocationSchedulingPolicy.block,
    managementVersion: 1,
  );
  @override
  Future<LocationReservationPage> listPaged({
    required String locationId,
    required LocationReservationConsumer consumer,
    String? afterId,
    int limit = 50,
  }) async {
    consumers.add(consumer);
    return LocationReservationPage(
      locationId: locationId,
      consumer: consumer,
      items: [],
      nextId: null,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('Unexpected mutation');
}

void main() {
  testWidgets(
    'normal group route composes reservations from authorized detail and confines revocation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const permissions = {'groups.read', 'locations.read', 'locations.reservations.read'};
      final session = SuperadminSession()
        ..authorize(
          const SuperadminAuthContext(
            platformRoleCode: 'test',
            scopeKind: SuperadminAuthScopeKind.platform,
            permissionCodes: permissions,
            aal: 'aal1',
          ),
          sessionId: 'consumer-route-session',
        );
      final gateway = _Reservations();
      final router = createSuperadminRouter(
        session: session,
        login: unavailableSuperadminLogin,
        logout: unavailableSuperadminLogout,
        requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
        groupDetailRepository: _Groups(),
        locationCatalogReader: _Catalog(),
        locationReservationGateway: gateway,
        onThemeModeChanged: (_) {},
      );
      addTearDown(router.dispose);
      addTearDown(session.dispose);
      await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
      router.go('/groups/$groupId');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('location-selection-option')),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('group-detail-content')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const Key('location-selection-option'))),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      final section = tester.widget<LocationConsumerReservations>(
        find.byType(LocationConsumerReservations),
      );
      expect(
        section.consumer,
        const LocationReservationConsumer(kind: LocationReservationConsumerKind.group, id: groupId),
      );
      expect(section.scopes.map((option) => option.scope.institutionId).toSet(), {institutionA});
      expect((section.scopes.last.scope as UnitLocationScope).unitId, unitA);
      await tester.tap(find.byKey(const Key('location-selection-option')));
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text('Sala de leitura').last),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sala de leitura').last);
      await tester.pumpAndSettle();
      expect(gateway.consumers.single, section.consumer);
      expect(
        tester.widget<LocationReservationPanel>(find.byType(LocationReservationPanel)).canManage,
        isFalse,
      );
      session.authorize(
        const SuperadminAuthContext(
          platformRoleCode: 'test',
          scopeKind: SuperadminAuthScopeKind.platform,
          permissionCodes: {'groups.read'},
          aal: 'aal1',
        ),
        sessionId: 'consumer-route-revoked',
      );
      await tester.pumpAndSettle();
      expect(find.byType(LocationReservationPanel), findsNothing);
      expect(gateway.consumers, hasLength(1));
    },
  );
}
