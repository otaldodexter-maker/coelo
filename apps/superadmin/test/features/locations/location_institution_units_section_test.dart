import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_record.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_institution_units_section.dart';
import 'package:coelo_superadmin/features/locations/presentation/locations_page.dart';
import 'package:coelo_superadmin/features/units/data/fake_unit_directory_repository.dart';
import 'package:coelo_superadmin/features/units/domain/unit_directory.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'location_read_fixtures.dart';

const _unitB = '30000000-0000-4000-8000-000000000002';
const _unitOfB = '30000000-0000-4000-8000-000000000003';

/// Instituicoes com id em UUID, como a rota exige, cada uma com as unidades
/// pedidas. A instituicao B existe para provar que as unidades dela nunca
/// aparecem no catalogo da instituicao A.
FakeInstitutionDirectoryRepository _institutions({List<InstitutionUnit>? unitsOfA}) {
  final template = demoInstitutionRecords.first;
  return FakeInstitutionDirectoryRepository(
    records: [
      template.copyWith(
        id: institutionA,
        publicName: 'Instituição A',
        units:
            unitsOfA ??
            const [
              InstitutionUnit(id: unitA, name: 'Unidade Centro', groups: [], city: 'São Paulo'),
              InstitutionUnit(id: _unitB, name: 'Unidade Norte', groups: [], city: 'Guarulhos'),
            ],
      ),
      template.copyWith(
        id: institutionB,
        publicName: 'Instituição B',
        units: const [InstitutionUnit(id: _unitOfB, name: 'Unidade da outra', groups: [])],
      ),
    ],
  );
}

final class _FailingUnitRepository implements UnitDirectoryRepository {
  _FailingUnitRepository(this._inner);

  final UnitDirectoryRepository _inner;
  Object? failure;
  int calls = 0;

  @override
  Future<UnitDirectoryPage> fetchPage(UnitDirectoryQuery query) {
    ++calls;
    if (failure case final failure?) return Future.error(failure);
    return _inner.fetchPage(query);
  }

  @override
  List<UnitRecord> get records => _inner.records;
  @override
  UnitRecord? findById(String id) => _inner.findById(id);
  @override
  String createId(String institutionId, String slug) => _inner.createId(institutionId, slug);
  @override
  Future<void> upsert(UnitRecord record) => _inner.upsert(record);
  @override
  Future<UnitFormData> loadForm({String? unitId}) => _inner.loadForm(unitId: unitId);
  @override
  Future<UnitDirectoryFilterOptions> fetchFilterOptions({
    Set<String> states = const {},
    Set<String> cities = const {},
  }) => _inner.fetchFilterOptions(states: states, cities: cities);
}

void main() {
  Widget page({
    required ControlledLocationReader reader,
    LocationScope scope = scopeA,
    UnitDirectoryRepository? units,
    ValueChanged<String>? onUnitLocationsOpened,
    bool sessionAvailable = true,
    int contextRevision = 0,
  }) => MaterialApp(
    theme: CoeloTheme.light,
    home: LocationsPage(
      scope: scope,
      logout: unavailableSuperadminLogout,
      reader: reader,
      sessionAvailable: sessionAvailable,
      contextRevision: contextRevision,
      unitDirectoryRepository: units,
      onUnitLocationsOpened: onUnitLocationsOpened,
    ),
  );

  Future<void> settleDirectory(WidgetTester tester, ControlledLocationReader reader) async {
    reader.directories.last.result.complete(locationPage());
    await tester.pumpAndSettle();
  }

  final section = find.byKey(const Key('locations-units'));
  final heading = find.byKey(const Key('location-group-units'));

  /// O grupo mora no fim da ListView do diretorio; a janela alta deixa os
  /// grupos de locais e o de unidades construidos de uma vez.
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('without a unit repository the institution catalog has no Unidades group', (
    tester,
  ) async {
    final reader = ControlledLocationReader();
    await tester.pumpWidget(page(reader: reader));
    await settleDirectory(tester, reader);
    expect(section, findsNothing);
    expect(heading, findsNothing);
    expect(find.byType(LocationInstitutionUnitsSection), findsNothing);
  });

  testWidgets('a unit catalog never shows the Unidades group even with a repository', (
    tester,
  ) async {
    final reader = ControlledLocationReader();
    final units = FakeUnitDirectoryRepository(_institutions());
    await tester.pumpWidget(page(reader: reader, scope: scopeUnitA, units: units));
    reader.directories.last.result.complete(locationPage(scope: scopeUnitA));
    await tester.pumpAndSettle();
    expect(section, findsNothing);
    expect(find.byType(LocationInstitutionUnitsSection), findsNothing);
  });

  testWidgets('the institution catalog lists only its own units as cards', (tester) async {
    tall(tester);
    final reader = ControlledLocationReader();
    final units = FakeUnitDirectoryRepository(_institutions());
    await tester.pumpWidget(page(reader: reader, units: units, onUnitLocationsOpened: (_) {}));
    await settleDirectory(tester, reader);

    expect(section, findsOneWidget);
    expect(heading, findsOneWidget);
    expect(find.text('Unidades'), findsWidgets);
    await tester.ensureVisible(find.byKey(const Key('unit-card-$unitA')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unit-card-$unitA')), findsOneWidget);
    expect(find.byKey(const Key('unit-card-$_unitB')), findsOneWidget);
    expect(find.text('Unidade Centro'), findsOneWidget);
    expect(find.text('Unidade Norte'), findsOneWidget);
    // A unidade da instituicao B nao entra no catalogo da instituicao A.
    expect(find.byKey(const Key('unit-card-$_unitOfB')), findsNothing);
    expect(find.text('Unidade da outra'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Unidades group comes after the location groups', (tester) async {
    tall(tester);
    final reader = ControlledLocationReader();
    final units = FakeUnitDirectoryRepository(_institutions());
    await tester.pumpWidget(page(reader: reader, units: units));
    await settleDirectory(tester, reader);
    await tester.ensureVisible(heading);
    await tester.pumpAndSettle();
    final external = tester.getTopLeft(find.byKey(const Key('location-group-external')));
    final unitsTop = tester.getTopLeft(heading);
    expect(unitsTop.dy, greaterThan(external.dy));
  });

  testWidgets('an institution without units says so instead of hiding the group', (tester) async {
    tall(tester);
    final reader = ControlledLocationReader();
    final units = FakeUnitDirectoryRepository(_institutions(unitsOfA: const []));
    await tester.pumpWidget(page(reader: reader, units: units));
    await settleDirectory(tester, reader);
    await tester.ensureVisible(heading);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location-units-empty')), findsOneWidget);
    expect(find.text('Nenhuma unidade cadastrada'), findsOneWidget);
    expect(find.byKey(const Key('location-units-reload')), findsNothing);
  });

  testWidgets('touching a unit card reports the unit whose catalog should open', (tester) async {
    tall(tester);
    final reader = ControlledLocationReader();
    final units = FakeUnitDirectoryRepository(_institutions());
    final opened = <String>[];
    await tester.pumpWidget(page(reader: reader, units: units, onUnitLocationsOpened: opened.add));
    await settleDirectory(tester, reader);

    final card = find.byKey(const Key('unit-card-$_unitB'));
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pump();
    expect(opened, [_unitB]);
    // Tocar um card de unidade nao abre um detalhe de local nesta tela.
    expect(reader.details, isEmpty);
  });

  testWidgets('without a destination the unit cards stay visible and inert', (tester) async {
    tall(tester);
    final reader = ControlledLocationReader();
    final units = FakeUnitDirectoryRepository(_institutions());
    await tester.pumpWidget(page(reader: reader, units: units));
    await settleDirectory(tester, reader);
    final card = find.byKey(const Key('unit-card-$unitA'));
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card, warnIfMissed: false);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(reader.details, isEmpty);
  });

  testWidgets('a failed unit read shows Recarregar and reads again on demand', (tester) async {
    tall(tester);
    final reader = ControlledLocationReader();
    final units = _FailingUnitRepository(FakeUnitDirectoryRepository(_institutions()))
      ..failure = StateError('offline');
    await tester.pumpWidget(page(reader: reader, units: units));
    await settleDirectory(tester, reader);
    await tester.ensureVisible(heading);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location-units-unavailable')), findsOneWidget);
    expect(find.text('Não foi possível carregar as unidades'), findsOneWidget);
    final reload = find.byKey(const Key('location-units-reload'));
    expect(reload, findsOneWidget);
    expect(units.calls, 1);

    units.failure = null;
    await tester.ensureVisible(reload);
    await tester.pumpAndSettle();
    await tester.tap(reload);
    await tester.pumpAndSettle();
    expect(units.calls, 2);
    expect(find.byKey(const Key('location-units-unavailable')), findsNothing);
    expect(find.byKey(const Key('unit-card-$unitA')), findsOneWidget);
  });

  testWidgets('a refused unit read is denied without Recarregar', (tester) async {
    tall(tester);
    final reader = ControlledLocationReader();
    final units = _FailingUnitRepository(FakeUnitDirectoryRepository(_institutions()))
      ..failure = const UnitDirectoryUnauthorizedException();
    await tester.pumpWidget(page(reader: reader, units: units));
    await settleDirectory(tester, reader);
    await tester.ensureVisible(heading);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location-units-denied')), findsOneWidget);
    expect(find.byKey(const Key('location-units-reload')), findsNothing);
  });

  testWidgets('without a session the units are never read', (tester) async {
    tall(tester);
    final reader = ControlledLocationReader();
    final units = _FailingUnitRepository(FakeUnitDirectoryRepository(_institutions()));
    await tester.pumpWidget(page(reader: reader, units: units, sessionAvailable: false));
    await tester.pumpAndSettle();
    expect(units.calls, 0);
    expect(find.byKey(const Key('location-units-denied')), findsOneWidget);
  });

  testWidgets('the units query asks only for this institution', (tester) async {
    tall(tester);
    final reader = ControlledLocationReader();
    final queries = <UnitDirectoryQuery>[];
    final units = _QueryRecordingUnitRepository(queries);
    await tester.pumpWidget(page(reader: reader, units: units));
    await settleDirectory(tester, reader);
    expect(queries, hasLength(1));
    expect(queries.single.institutionIds, {institutionA});
    expect(queries.single.pageSize, LocationInstitutionUnitsSection.pageSize);
  });

  testWidgets('a new context reads the units again', (tester) async {
    tall(tester);
    final reader = ControlledLocationReader();
    final units = _FailingUnitRepository(FakeUnitDirectoryRepository(_institutions()));
    await tester.pumpWidget(page(reader: reader, units: units));
    await settleDirectory(tester, reader);
    expect(units.calls, 1);
    await tester.pumpWidget(page(reader: reader, units: units, contextRevision: 1));
    await settleDirectory(tester, reader);
    expect(units.calls, 2);
  });
}

final class _QueryRecordingUnitRepository implements UnitDirectoryRepository {
  _QueryRecordingUnitRepository(this.queries);

  final List<UnitDirectoryQuery> queries;

  @override
  Future<UnitDirectoryPage> fetchPage(UnitDirectoryQuery query) async {
    queries.add(query);
    return UnitDirectoryPage(items: const [], totalCount: 0, page: 0, pageSize: query.pageSize);
  }

  @override
  List<UnitRecord> get records => const [];
  @override
  UnitRecord? findById(String id) => null;
  @override
  String createId(String institutionId, String slug) => throw UnimplementedError();
  @override
  Future<void> upsert(UnitRecord record) => throw UnimplementedError();
  @override
  Future<UnitFormData> loadForm({String? unitId}) => throw UnimplementedError();
  @override
  Future<UnitDirectoryFilterOptions> fetchFilterOptions({
    Set<String> states = const {},
    Set<String> cities = const {},
  }) => throw UnimplementedError();
}
