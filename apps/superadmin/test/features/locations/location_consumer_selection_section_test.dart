import 'dart:async';
import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/locations/domain/location_catalog_reader.dart';
import 'package:coelo_superadmin/features/locations/domain/location_consumer_selection_reader.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_consumer_selection_section.dart';
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
LocationConsumerCurrentSelection selection({
  LocationReservationConsumer consumer = group,
  LocationScope scope = scopeA,
  String label = 'Biblioteca externa',
  bool empty = false,
  LocationCatalogStatus status = LocationCatalogStatus.inactive,
}) => LocationConsumerCurrentSelection(
  consumer: consumer,
  location: empty
      ? null
      : LocationReferenceSnapshot(
          id: locationA,
          scope: scope,
          kind: LocationKind.external,
          label: label,
        ),
  status: empty ? null : status,
);

class _Reader implements LocationConsumerSelectionReader {
  _Reader({this.available = true});
  @override
  final bool available;
  final calls =
      <
        ({LocationReservationConsumer consumer, Completer<LocationConsumerCurrentSelection> result})
      >[];
  @override
  Future<LocationConsumerCurrentSelection> fetchSelection({
    required LocationReservationConsumer consumer,
  }) {
    final result = Completer<LocationConsumerCurrentSelection>();
    calls.add((consumer: consumer, result: result));
    return result.future;
  }
}

Widget _app(
  _Reader reader, {
  LocationReservationConsumer consumer = group,
  List<LocationScope> scopes = const [scopeA, scopeUnitA],
  bool canRead = true,
  bool session = true,
  int revision = 1,
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
      child: LocationConsumerSelectionSection(
        reader: reader,
        consumer: consumer,
        scopes: scopes,
        canRead: canRead,
        sessionAvailable: session,
        contextRevision: revision,
      ),
    ),
  ),
);
void main() {
  testWidgets('current reference displays status and never becomes a reservation or form value', (
    tester,
  ) async {
    final reader = _Reader();
    await tester.pumpWidget(_app(reader));
    expect(find.byKey(const Key('consumer-selection-loading')), findsOneWidget);
    reader.calls.single.result.complete(selection());
    await tester.pumpAndSettle();
    expect(find.text('Biblioteca externa'), findsOneWidget);
    expect(find.text('Inativo'), findsOneWidget);
    expect(find.text('Local externo'), findsOneWidget);
    expect(find.byType(DropdownButton<String>), findsNothing);
    expect(reader.calls.single.consumer, group);
  });
  testWidgets('authorized absence is distinct from unavailable', (tester) async {
    final reader = _Reader();
    await tester.pumpWidget(_app(reader));
    reader.calls.single.result.complete(selection(empty: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('consumer-selection-empty')), findsOneWidget);
    expect(find.byKey(const Key('consumer-selection-unavailable')), findsNothing);
  });
  testWidgets('closed deployment gate makes no request and offers no dead reload', (tester) async {
    final reader = _Reader(available: false);
    await tester.pumpWidget(_app(reader));
    expect(reader.calls, isEmpty);
    expect(find.byKey(const Key('consumer-selection-unavailable')), findsOneWidget);
    expect(find.byKey(const Key('consumer-selection-reload')), findsNothing);
  });
  testWidgets('capability or session loss blocks before request', (tester) async {
    final reader = _Reader();
    await tester.pumpWidget(_app(reader, canRead: false));
    expect(reader.calls, isEmpty);
    expect(find.byKey(const Key('consumer-selection-denied')), findsOneWidget);
    await tester.pumpWidget(_app(reader, session: false));
    expect(reader.calls, isEmpty);
  });
  testWidgets('consumer and auth revision changes clear pending and rendered data', (tester) async {
    final reader = _Reader();
    await tester.pumpWidget(_app(reader));
    await tester.pumpWidget(_app(reader, consumer: activity));
    reader.calls.first.result.complete(selection());
    await tester.pump();
    expect(find.text('Biblioteca externa'), findsNothing);
    reader.calls.last.result.complete(selection(consumer: activity));
    await tester.pumpAndSettle();
    expect(find.text('Biblioteca externa'), findsOneWidget);
    await tester.pumpWidget(_app(reader, consumer: activity, revision: 2));
    expect(find.text('Biblioteca externa'), findsNothing);
    await tester.pumpWidget(_app(reader, consumer: activity, revision: 3, canRead: false));
    reader.calls.last.result.complete(selection(consumer: activity));
    await tester.pumpAndSettle();
    expect(find.text('Biblioteca externa'), findsNothing);
    expect(reader.calls, hasLength(3));
  });
  testWidgets('foreign owner and wrong consumer never render their payload', (tester) async {
    final reader = _Reader();
    await tester.pumpWidget(_app(reader));
    reader.calls.last.result.complete(
      selection(scope: const LocationScope.institution(institutionId: institutionB)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Biblioteca externa'), findsNothing);
    expect(find.byKey(const Key('consumer-selection-unavailable')), findsOneWidget);
    await tester.tap(find.byKey(const Key('consumer-selection-reload')));
    reader.calls.last.result.complete(selection(consumer: activity));
    await tester.pumpAndSettle();
    expect(find.text('Biblioteca externa'), findsNothing);
  });
  testWidgets('changing owner scope invalidates rendered reference', (tester) async {
    final reader = _Reader();
    await tester.pumpWidget(_app(reader));
    reader.calls.last.result.complete(selection(scope: scopeUnitA));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app(reader, scopes: const [scopeA]));
    expect(find.text('Biblioteca externa'), findsNothing);
    reader.calls.last.result.complete(selection(empty: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('consumer-selection-empty')), findsOneWidget);
  });
  testWidgets('unknown error is sanitized and stale reload cannot query after revocation', (
    tester,
  ) async {
    final reader = _Reader();
    await tester.pumpWidget(_app(reader));
    reader.calls.single.result.completeError(StateError('private payload'));
    await tester.pumpAndSettle();
    expect(find.textContaining('private payload'), findsNothing);
    final callback = tester
        .widget<TextButton>(find.byKey(const Key('consumer-selection-reload')))
        .onPressed!;
    await tester.pumpWidget(_app(reader, canRead: false, revision: 2));
    callback();
    expect(reader.calls, hasLength(1));
  });
  testWidgets('authorized backend denial stays distinct and dispose ignores completion', (
    tester,
  ) async {
    final reader = _Reader();
    await tester.pumpWidget(_app(reader));
    reader.calls.single.result.completeError(const LocationCatalogAccessDeniedException());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('consumer-selection-denied')), findsOneWidget);
    await tester.tap(find.byKey(const Key('consumer-selection-reload')));
    await tester.pumpWidget(const SizedBox.shrink());
    reader.calls.last.result.complete(selection());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    for (final dark in [false, true]) {
      testWidgets('current selection fits width $width dark $dark at200%', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final reader = _Reader();
        await tester.pumpWidget(_app(reader, dark: dark, scale: 2));
        reader.calls.single.result.complete(
          selection(label: 'Biblioteca externa compartilhada com nome longo'),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
