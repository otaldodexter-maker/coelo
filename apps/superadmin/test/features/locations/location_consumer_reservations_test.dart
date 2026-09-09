import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/locations/domain/location_catalog_reader.dart';
import 'package:coelo_superadmin/features/locations/domain/location_reservation_gateway.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_consumer_reservations.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_reservation_panel.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'location_read_fixtures.dart';

const activity = LocationReservationConsumer(
  kind: LocationReservationConsumerKind.activity,
  id: '40000000-0000-4000-8000-000000000001',
);
const group = LocationReservationConsumer(
  kind: LocationReservationConsumerKind.group,
  id: '40000000-0000-4000-8000-000000000002',
);

class _Reader implements LocationCatalogReader {
  final requests = <LocationDirectoryRequest>[];
  @override
  Future<LocationDirectoryResult> fetchDirectory(LocationDirectoryRequest request) async {
    requests.add(request);
    return locationPage(scope: request.scope);
  }

  @override
  Future<LocationCatalogEntry> fetchDetail(String id) async => locationFixture(id: id);
}

class _Gateway implements LocationReservationGateway {
  final reads = <({String locationId, LocationReservationConsumer consumer})>[];
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
    reads.add((locationId: locationId, consumer: consumer));
    return LocationReservationPage(
      locationId: locationId,
      consumer: consumer,
      items: [],
      nextId: null,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected reservation mutation');
}

void main() {
  Widget app(
    _Reader reader,
    _Gateway gateway, {
    LocationReservationConsumer consumer = activity,
    int revision = 1,
    bool canRead = true,
    List<({LocationScope scope, String label})> scopes = const [
      (scope: scopeA, label: 'Instituição'),
      (scope: scopeUnitA, label: 'Unidade'),
    ],
    bool dark = false,
    double textScale = 1,
  }) => MaterialApp(
    theme: dark ? CoeloTheme.dark : CoeloTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        child: LocationConsumerReservations(
          consumer: consumer,
          scopes: scopes,
          reader: reader,
          gateway: gateway,
          sessionAvailable: true,
          contextRevision: revision,
          canRead: canRead,
        ),
      ),
    ),
  );

  Future<void> selectLocation(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('location-selection-option')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sala de leitura').last);
    await tester.pumpAndSettle();
  }

  testWidgets('explicit catalog choice reads reservations for the actual persisted consumer', (
    tester,
  ) async {
    final reader = _Reader();
    final gateway = _Gateway();
    await tester.pumpWidget(app(reader, gateway));
    await tester.pumpAndSettle();
    expect(gateway.reads, isEmpty);
    expect(find.text('Pontual'), findsNothing);
    await selectLocation(tester);
    expect(gateway.reads.single, (locationId: locationA, consumer: activity));
    final panel = tester.widget<LocationReservationPanel>(find.byType(LocationReservationPanel));
    expect(panel.canManage, isFalse);
    expect(panel.scope.institutionId, institutionA);
  });

  testWidgets('changing consumer drops the previous selection before any reservation read', (
    tester,
  ) async {
    final reader = _Reader();
    final gateway = _Gateway();
    await tester.pumpWidget(app(reader, gateway));
    await tester.pumpAndSettle();
    await selectLocation(tester);
    await tester.pumpWidget(app(reader, gateway, consumer: group));
    await tester.pumpAndSettle();
    expect(find.byType(LocationReservationPanel), findsNothing);
    expect(gateway.reads, hasLength(1));
    await selectLocation(tester);
    expect(gateway.reads.last.consumer, group);
  });

  testWidgets('changing owner uses its catalog and removes previous reservation context', (
    tester,
  ) async {
    final reader = _Reader();
    final gateway = _Gateway();
    await tester.pumpWidget(app(reader, gateway));
    await tester.pumpAndSettle();
    await selectLocation(tester);
    await tester.tap(find.byKey(const Key('reservation-catalog-owner')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unidade').last);
    await tester.pumpAndSettle();
    expect(find.byType(LocationReservationPanel), findsNothing);
    expect(reader.requests.last.scope, isA<UnitLocationScope>());
    expect(gateway.reads, hasLength(1));
    await selectLocation(tester);
    expect(
      tester.widget<LocationReservationPanel>(find.byType(LocationReservationPanel)).scope,
      isA<UnitLocationScope>(),
    );
  });

  testWidgets('authorization revision and revocation clear the selected location', (tester) async {
    final reader = _Reader();
    final gateway = _Gateway();
    await tester.pumpWidget(app(reader, gateway));
    await tester.pumpAndSettle();
    await selectLocation(tester);
    await tester.pumpWidget(app(reader, gateway, revision: 2));
    await tester.pumpAndSettle();
    expect(find.byType(LocationReservationPanel), findsNothing);
    await selectLocation(tester);
    final before = reader.requests.length;
    await tester.pumpWidget(app(reader, gateway, revision: 3, canRead: false));
    await tester.pumpAndSettle();
    expect(find.byType(LocationReservationPanel), findsNothing);
    expect(find.byKey(const Key('consumer-reservations-denied')), findsOneWidget);
    expect(reader.requests, hasLength(before));
  });

  testWidgets('missing or unsupported consumer never reaches the catalog', (tester) async {
    final reader = _Reader();
    final gateway = _Gateway();
    await tester.pumpWidget(
      app(
        reader,
        gateway,
        consumer: const LocationReservationConsumer(
          kind: LocationReservationConsumerKind.activity,
          id: 'draft',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(reader.requests, isEmpty);
    await tester.pumpWidget(
      app(
        reader,
        gateway,
        consumer: LocationReservationConsumer(
          kind: LocationReservationConsumerKind.event,
          id: activity.id,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(reader.requests, isEmpty);
    expect(gateway.reads, isEmpty);
  });

  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    for (final dark in [false, true]) {
      testWidgets('consumer picker fits width $width dark=$dark at 200 percent', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(app(_Reader(), _Gateway(), dark: dark, textScale: 2));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
