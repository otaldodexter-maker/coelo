import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/locations/domain/location_consumer_selection_reader.dart';
import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_read_detail.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/auth/domain/superadmin_auth_context.dart';
import 'package:coelo_superadmin/features/groups/domain/group_detail.dart';
import 'package:coelo_superadmin/features/locations/domain/location_catalog_reader.dart';
import 'package:coelo_superadmin/features/locations/domain/location_consumer_bindings_reader.dart';
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

class _Bindings implements LocationConsumerBindingsReader {
  final consumers = <LocationReservationConsumer>[];
  @override
  Future<LocationConsumerBindingPage> fetchPage({
    required LocationReservationConsumer consumer,
    String? afterLocationId,
    int limit = 20,
  }) async {
    consumers.add(consumer);
    return LocationConsumerBindingPage(
      consumer: consumer,
      items: [
        const LocationConsumerBinding(
          location: LocationReferenceSnapshot(
            id: locationB,
            scope: scopeUnitA,
            kind: LocationKind.internal,
            label: 'Sala antiga da unidade',
          ),
          status: LocationCatalogStatus.inactive,
        ),
      ],
      nextLocationId: null,
    );
  }
}

class _Activities implements ActivityReadDetailRepository {
  @override
  Future<ActivityReadDetail> fetchById(String id) async => ActivityReadDetail.fromJson({
    'activity': {
      'activity_id': id,
      'institution_id': institutionA,
      'name': 'Atividade autorizada',
      'description': null,
      'taxonomy_id': null,
      'taxonomy_name': null,
      'status': 'draft',
      'management_version': 1,
      'icon_key': null,
      'initials': null,
      'created_at': '2026-09-01T12:00:00Z',
      'updated_at': '2026-09-01T12:00:00Z',
    },
    'units': [
      {'unit_id': unitA, 'name': 'Unidade autorizada', 'status': 'active'},
    ],
    'groups': <Object?>[],
    'counts': {'units': 1, 'groups': 0, 'participants': 0, 'instructors': 0, 'activity_admins': 0},
  });
}

class _Selection implements LocationConsumerSelectionReader {
  final consumers = <LocationReservationConsumer>[];
  @override
  bool get available => true;
  @override
  Future<LocationConsumerCurrentSelection> fetchSelection({
    required LocationReservationConsumer consumer,
  }) async {
    consumers.add(consumer);
    return LocationConsumerCurrentSelection(
      consumer: consumer,
      location: const LocationReferenceSnapshot(
        id: locationA,
        scope: scopeA,
        kind: LocationKind.external,
        label: 'Local atual gravado',
      ),
      status: LocationCatalogStatus.inactive,
    );
  }
}

void main() {
  for (final kind in [
    LocationReservationConsumerKind.group,
    LocationReservationConsumerKind.activity,
  ]) {
    testWidgets(
      'normal ${kind.name} current choice requires no reservation capability and clears on revocation',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1440, 1100));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final readPermission = kind == LocationReservationConsumerKind.group
            ? 'groups.read'
            : 'activities.read';
        final session = SuperadminSession()
          ..authorize(
            SuperadminAuthContext(
              platformRoleCode: 'test',
              scopeKind: SuperadminAuthScopeKind.platform,
              permissionCodes: {readPermission, 'locations.read'},
              aal: 'aal1',
            ),
            sessionId: 'selection-session',
          );
        final selection = _Selection();
        final bindings = _Bindings();
        final reservations = _Reservations();
        final router = createSuperadminRouter(
          session: session,
          login: unavailableSuperadminLogin,
          logout: unavailableSuperadminLogout,
          requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
          groupDetailRepository: _Groups(),
          activityReadDetailRepository: _Activities(),
          locationConsumerSelectionReader: selection,
          locationConsumerBindingsReader: bindings,
          locationReservationGateway: reservations,
          onThemeModeChanged: (_) {},
        );
        addTearDown(router.dispose);
        addTearDown(session.dispose);
        await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
        router.go(
          kind == LocationReservationConsumerKind.group
              ? '/groups/$groupId?institutionId=$institutionB'
              : '/activities/$groupId?institutionId=$institutionB',
        );
        await tester.pumpAndSettle();
        if (kind == LocationReservationConsumerKind.activity) {
          await tester.scrollUntilVisible(
            find.byKey(const Key('consumer-current-selection')),
            250,
            scrollable: find
                .descendant(
                  of: find.byKey(const Key('activity-read-scroll')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
        }
        expect(find.text('Local atual gravado'), findsOneWidget);
        expect(selection.consumers.single, LocationReservationConsumer(kind: kind, id: groupId));
        expect(bindings.consumers, isEmpty);
        expect(reservations.consumers, isEmpty);
        expect(find.byType(LocationReservationPanel), findsNothing);
        final context = tester.widget<LocationConsumerReservations>(
          find.byType(LocationConsumerReservations),
        );
        expect(context.canRead, isFalse);
        session.authorize(
          SuperadminAuthContext(
            platformRoleCode: 'test',
            scopeKind: SuperadminAuthScopeKind.platform,
            permissionCodes: {readPermission},
            aal: 'aal1',
          ),
          sessionId: 'selection-revoked',
        );
        await tester.pumpAndSettle();
        expect(find.text('Local atual gravado'), findsNothing);
        expect(selection.consumers, hasLength(1));
      },
    );
  }

  testWidgets(
    'normal activity route derives reservation scopes from reader and clears on revocation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const permissions = {
        'activities.read',
        'locations.read',
        'locations.reservations.read',
        'locations.reservations.manage',
      };
      final session = SuperadminSession()
        ..authorize(
          const SuperadminAuthContext(
            platformRoleCode: 'test',
            scopeKind: SuperadminAuthScopeKind.platform,
            permissionCodes: permissions,
            aal: 'aal1',
          ),
          sessionId: 'activity-consumer-session',
        );
      final reservations = _Reservations();
      final bindings = _Bindings();
      final router = createSuperadminRouter(
        session: session,
        login: unavailableSuperadminLogin,
        logout: unavailableSuperadminLogout,
        requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
        activityReadDetailRepository: _Activities(),
        locationCatalogReader: _Catalog(),
        locationReservationGateway: reservations,
        locationConsumerBindingsReader: bindings,
        onThemeModeChanged: (_) {},
      );
      addTearDown(router.dispose);
      addTearDown(session.dispose);
      await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
      router.go('/activities/$groupId?institutionId=$institutionB');
      await tester.pumpAndSettle();
      expect(
        tester.widget<OutlinedButton>(find.byKey(const Key('activity-read-edit'))).onPressed,
        isNull,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('consumer-binding-open-$locationB')),
        250,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('activity-read-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const Key('consumer-binding-open-$locationB'))),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      final section = tester.widget<LocationConsumerReservations>(
        find.byType(LocationConsumerReservations),
      );
      expect(
        section.consumer,
        const LocationReservationConsumer(
          kind: LocationReservationConsumerKind.activity,
          id: groupId,
        ),
      );
      expect(section.scopes.map((option) => option.scope.institutionId).toSet(), {institutionA});
      expect((section.scopes.last.scope as UnitLocationScope).unitId, unitA);
      await tester.tap(find.byKey(const Key('consumer-binding-open-$locationB')));
      await tester.pumpAndSettle();
      expect(reservations.consumers.single, section.consumer);
      expect(
        tester.widget<LocationReservationPanel>(find.byType(LocationReservationPanel)).canManage,
        isFalse,
      );
      final previousReads = bindings.consumers.length;
      session.authorize(
        const SuperadminAuthContext(
          platformRoleCode: 'test',
          scopeKind: SuperadminAuthScopeKind.platform,
          permissionCodes: {},
          aal: 'aal1',
        ),
        sessionId: 'activity-consumer-revoked',
      );
      await tester.pumpAndSettle();
      expect(find.text('Atividade autorizada'), findsNothing);
      expect(find.byType(LocationReservationPanel), findsNothing);
      expect(bindings.consumers, hasLength(previousReads));
      expect(reservations.consumers, hasLength(1));
    },
  );

  testWidgets(
    'normal group route composes reservations from authorized detail and confines revocation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const permissions = {
        'groups.read',
        'locations.read',
        'locations.reservations.read',
        'locations.reservations.manage',
      };
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
      final bindings = _Bindings();
      final router = createSuperadminRouter(
        session: session,
        login: unavailableSuperadminLogin,
        logout: unavailableSuperadminLogout,
        requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
        groupDetailRepository: _Groups(),
        locationCatalogReader: _Catalog(),
        locationReservationGateway: gateway,
        locationConsumerBindingsReader: bindings,
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
      expect(bindings.consumers.single, section.consumer);
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const Key('consumer-binding-open-$locationB'))),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('consumer-binding-open-$locationB')));
      await tester.pumpAndSettle();
      final historicalPanel = tester.widget<LocationReservationPanel>(
        find.byType(LocationReservationPanel),
      );
      expect(historicalPanel.locationId, locationB);
      expect(historicalPanel.scope, isA<UnitLocationScope>());
      expect(gateway.consumers.last, section.consumer);
      expect(bindings.consumers, hasLength(1));
      final historyReadsBeforeRevocation = bindings.consumers.length;
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
      expect(gateway.consumers, hasLength(2));
      expect(find.text('Sala antiga da unidade'), findsNothing);
      expect(bindings.consumers, hasLength(historyReadsBeforeRevocation));
    },
  );
}
