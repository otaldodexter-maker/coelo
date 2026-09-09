import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_catalogued_location_section.dart';
import 'package:coelo_superadmin/features/locations/domain/location_catalog_reader.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_selection_field.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../locations/location_read_fixtures.dart';

class _Reader implements LocationCatalogReader {
  final calls = <LocationDirectoryRequest>[];
  @override
  Future<LocationDirectoryResult> fetchDirectory(LocationDirectoryRequest request) async {
    calls.add(request);
    return locationPage(scope: request.scope);
  }

  @override
  Future<LocationCatalogEntry> fetchDetail(String id) async => locationFixture(id: id);
}

void main() {
  Widget app(
    _Reader reader,
    List<CataloguedLocationSelection?> selections, {
    bool available = true,
    int revision = 1,
    bool session = true,
    bool dark = false,
    double scale = 1,
    List<({LocationScope scope, String label})> scopes = const [
      (scope: scopeA, label: 'Instituicao'),
      (scope: scopeUnitA, label: 'Unidade'),
    ],
  }) => MaterialApp(
    theme: dark ? CoeloTheme.dark : CoeloTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        child: ActivityCataloguedLocationSection(
          scopes: scopes,
          reader: reader,
          sessionAvailable: session,
          contextRevision: revision,
          available: available,
          onChanged: selections.add,
        ),
      ),
    ),
  );
  testWidgets('closed gate offers honest state and never reads catalogs', (tester) async {
    final reader = _Reader();
    await tester.pumpWidget(app(reader, [], available: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('activity-catalogued-location-unavailable')), findsOneWidget);
    expect(reader.calls, isEmpty);
    expect(find.byType(LocationSelectionField), findsNothing);
  });
  testWidgets('catalog selection stays typed and changing owner clears it', (tester) async {
    final reader = _Reader();
    final values = <CataloguedLocationSelection?>[];
    await tester.pumpWidget(app(reader, values));
    await tester.pumpAndSettle();
    expect(find.text('Pontual'), findsNothing);
    final field = tester.widget<LocationSelectionField>(find.byType(LocationSelectionField));
    field.onChanged(
      CataloguedLocationSelection(
        LocationReferenceSnapshot(
          id: locationA,
          scope: scopeA,
          kind: LocationKind.internal,
          label: 'Local',
        ),
      ),
    );
    expect(values.last!.snapshot.id, locationA);
    tester
        .widget<CoeloAdminSingleSelectField<String>>(
          find.byKey(const Key('activity-location-owner')),
        )
        .onChanged('unit:$unitA');
    await tester.pumpAndSettle();
    expect(values.last, isNull);
    expect(reader.calls.last.scope, isA<UnitLocationScope>());
    field.onChanged(
      CataloguedLocationSelection(
        LocationReferenceSnapshot(
          id: locationA,
          scope: scopeA,
          kind: LocationKind.internal,
          label: 'Obsolete',
        ),
      ),
    );
    expect(values.last, isNull);
  });
  testWidgets('revocation clears selection and rejects held callback', (tester) async {
    final reader = _Reader();
    final values = <CataloguedLocationSelection?>[];
    await tester.pumpWidget(app(reader, values));
    await tester.pumpAndSettle();
    final field = tester.widget<LocationSelectionField>(find.byType(LocationSelectionField));
    await tester.pumpWidget(app(reader, values, session: false, revision: 2));
    await tester.pumpAndSettle();
    expect(values.last, isNull);
    final count = values.length;
    field.onChanged(
      CataloguedLocationSelection(
        LocationReferenceSnapshot(
          id: locationA,
          scope: scopeA,
          kind: LocationKind.internal,
          label: 'Obsolete',
        ),
      ),
    );
    expect(values, hasLength(count));
    expect(reader.calls, hasLength(1));
    expect(find.byType(LocationSelectionField), findsNothing);
  });
  testWidgets('invalid or duplicate owner scope cannot reach catalog', (tester) async {
    final reader = _Reader();
    await tester.pumpWidget(
      app(reader, [], scopes: const [(scope: scopeA, label: 'A'), (scope: scopeA, label: 'Again')]),
    );
    await tester.pumpAndSettle();
    expect(reader.calls, isEmpty);
  });
  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    for (final dark in [false, true]) {
      testWidgets('catalog owner width=$width dark=$dark text200', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(app(_Reader(), [], dark: dark, scale: 2));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('location-selection-option')), findsOneWidget);
      });
    }
  }
}
