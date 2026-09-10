import 'dart:async';

import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/locations/domain/location_catalog_reader.dart';
import 'package:coelo_superadmin/features/locations/domain/location_consumer_bindings_reader.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_consumer_bindings_section.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'location_read_fixtures.dart';

const group = LocationReservationConsumer(
  kind: LocationReservationConsumerKind.group,
  id: '40000000-0000-4000-8000-000000000001',
);
const activity = LocationReservationConsumer(
  kind: LocationReservationConsumerKind.activity,
  id: '40000000-0000-4000-8000-000000000002',
);
LocationConsumerBinding binding({
  String id = locationA,
  LocationScope scope = scopeA,
  String name = 'Sala anterior',
}) => LocationConsumerBinding(
  location: LocationReferenceSnapshot(
    id: id,
    scope: scope,
    kind: LocationKind.internal,
    label: name,
  ),
  status: LocationCatalogStatus.inactive,
);
LocationConsumerBindingPage page({
  LocationReservationConsumer consumer = group,
  List<LocationConsumerBinding>? items,
  String? next,
}) => LocationConsumerBindingPage(
  consumer: consumer,
  items: items ?? [binding()],
  nextLocationId: next,
);

class _Reader implements LocationConsumerBindingsReader {
  final requests =
      <
        ({
          LocationReservationConsumer consumer,
          String? after,
          Completer<LocationConsumerBindingPage> result,
        })
      >[];
  @override
  Future<LocationConsumerBindingPage> fetchPage({
    required LocationReservationConsumer consumer,
    String? afterLocationId,
    int limit = 20,
  }) {
    final result = Completer<LocationConsumerBindingPage>();
    requests.add((consumer: consumer, after: afterLocationId, result: result));
    return result.future;
  }
}

void main() {
  Widget app(
    _Reader reader, {
    LocationReservationConsumer consumer = group,
    int revision = 1,
    bool canRead = true,
    ValueChanged<LocationConsumerBinding>? onSelect,
    bool dark = false,
    double scale = 1,
  }) => MaterialApp(
    theme: dark ? CoeloTheme.dark : CoeloTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        child: LocationConsumerBindingsSection(
          reader: reader,
          consumer: consumer,
          scopes: const [scopeA, scopeUnitA],
          sessionAvailable: true,
          canRead: canRead,
          contextRevision: revision,
          onSelected: onSelect ?? (_) {},
        ),
      ),
    ),
  );

  testWidgets('history is explicit and never auto-selects an inactive location', (tester) async {
    final reader = _Reader();
    final selected = <LocationConsumerBinding>[];
    await tester.pumpWidget(app(reader, onSelect: selected.add));
    expect(find.byKey(const Key('consumer-bindings-loading')), findsOneWidget);
    reader.requests.single.result.complete(page());
    await tester.pumpAndSettle();
    expect(find.text('Sala anterior'), findsOneWidget);
    expect(find.text('Inativo'), findsOneWidget);
    expect(selected, isEmpty);
    await tester.tap(find.byKey(const Key('consumer-binding-open-$locationA')));
    expect(selected.single.location.id, locationA);
  });

  testWidgets('old response after consumer change cannot disclose or select', (tester) async {
    final reader = _Reader();
    await tester.pumpWidget(app(reader));
    await tester.pumpWidget(app(reader, consumer: activity));
    reader.requests.first.result.complete(page());
    await tester.pump();
    expect(find.text('Sala anterior'), findsNothing);
    reader.requests.last.result.complete(page(consumer: activity, items: []));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('consumer-bindings-empty')), findsOneWidget);
  });

  testWidgets('revision and capability loss clear history and revoke retained callbacks', (
    tester,
  ) async {
    final reader = _Reader();
    final selected = <LocationConsumerBinding>[];
    await tester.pumpWidget(app(reader, onSelect: selected.add));
    reader.requests.last.result.complete(page());
    await tester.pumpAndSettle();
    final stale = tester
        .widget<OutlinedButton>(find.byKey(const Key('consumer-binding-open-$locationA')))
        .onPressed!;
    await tester.pumpWidget(app(reader, revision: 2, onSelect: selected.add));
    expect(find.text('Sala anterior'), findsNothing);
    stale();
    expect(selected, isEmpty);
    reader.requests.last.result.complete(page());
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(reader, revision: 3, canRead: false, onSelect: selected.add));
    expect(find.text('Sala anterior'), findsNothing);
    expect(reader.requests, hasLength(2));
    expect(find.byKey(const Key('consumer-bindings-denied')), findsOneWidget);
  });

  testWidgets('foreign scope response is unavailable and never rendered', (tester) async {
    final reader = _Reader();
    await tester.pumpWidget(app(reader));
    reader.requests.single.result.complete(
      page(
        items: [
          binding(
            scope: const LocationScope.institution(
              institutionId: '20000000-0000-4000-8000-000000000099',
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sala anterior'), findsNothing);
    expect(find.byKey(const Key('consumer-bindings-unavailable')), findsOneWidget);
  });

  testWidgets('denied reload removes old references and permits explicit retry', (tester) async {
    final reader = _Reader();
    await tester.pumpWidget(app(reader));
    reader.requests.single.result.complete(page());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('consumer-bindings-reload')));
    await tester.pump();
    expect(find.text('Sala anterior'), findsNothing);
    reader.requests.last.result.completeError(const LocationCatalogAccessDeniedException());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('consumer-bindings-denied')), findsOneWidget);
    await tester.tap(find.byKey(const Key('consumer-bindings-reload')));
    expect(reader.requests, hasLength(3));
  });

  testWidgets('pagination sends last location and replaces visible page without auto-selection', (
    tester,
  ) async {
    final reader = _Reader();
    await tester.pumpWidget(app(reader));
    final entries = List.generate(
      20,
      (i) => binding(
        id: '50000000-0000-4000-8000-${(i + 1).toString().padLeft(12, '0')}',
        name: 'Local ${i + 1}',
      ),
    );
    reader.requests.single.result.complete(page(items: entries, next: entries.last.location.id));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('consumer-bindings-next')));
    await tester.tap(find.byKey(const Key('consumer-bindings-next')));
    await tester.pump();
    expect(reader.requests.last.after, entries.last.location.id);
    expect(find.text('Local 1'), findsNothing);
    reader.requests.last.result.complete(
      page(
        items: [binding(id: '60000000-0000-4000-8000-000000000001', name: 'Último local')],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Último local'), findsOneWidget);
    expect(find.byKey(const Key('consumer-bindings-next')), findsNothing);
  });

  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    for (final dark in [false, true]) {
      testWidgets('history width=$width dark=$dark text200', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final reader = _Reader();
        await tester.pumpWidget(app(reader, dark: dark, scale: 2));
        reader.requests.single.result.complete(page());
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('consumer-binding-open-$locationA')));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
