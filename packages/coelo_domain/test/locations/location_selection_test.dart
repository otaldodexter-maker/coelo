import 'package:coelo_domain/locations.dart';
import 'package:test/test.dart';

void main() {
  const institution = LocationScope.institution(institutionId: 'institution-a');
  const unit = LocationScope.unit(institutionId: 'institution-a', unitId: 'unit-a');
  const snapshot = LocationReferenceSnapshot(
    id: 'location-a',
    scope: institution,
    kind: LocationKind.internal,
    label: 'Biblioteca',
  );

  test('institution scope identifies the catalog owner', () {
    expect(institution, isA<InstitutionLocationScope>());
    expect(institution.institutionId, 'institution-a');
    expect(institution, isNot(isA<UnitLocationScope>()));
  });

  test('unit scope retains both explicit owner identifiers', () {
    expect(unit, isA<UnitLocationScope>());
    expect(unit.institutionId, 'institution-a');
    expect((unit as UnitLocationScope).unitId, 'unit-a');
  });

  test('scope variants support exhaustive matching', () {
    String owner(LocationScope scope) => switch (scope) {
      InstitutionLocationScope(:final institutionId) => institutionId,
      UnitLocationScope(:final unitId) => unitId,
    };
    expect(owner(institution), 'institution-a');
    expect(owner(unit), 'unit-a');
  });

  test('catalogued selection preserves the complete received snapshot', () {
    const selection = LocationSelection.catalogued(snapshot);
    expect(selection, isA<CataloguedLocationSelection>());
    final reference = (selection as CataloguedLocationSelection).snapshot;
    expect(reference, same(snapshot));
    expect(reference.id, 'location-a');
    expect(reference.scope, same(institution));
    expect(reference.kind, LocationKind.internal);
    expect(reference.label, 'Biblioteca');
  });

  test('external kind is explicit and does not invent an address', () {
    const external = LocationReferenceSnapshot(
      id: 'location-b',
      scope: unit,
      kind: LocationKind.external,
      label: 'Museu',
    );
    expect(external.kind, LocationKind.external);
    expect(external.scope, same(unit));
  });

  test('one-off selection preserves text without catalog promotion', () {
    const selection = LocationSelection.oneOff('  Pátio coberto — piso 2  ');
    expect(selection, isA<OneOffLocationSelection>());
    expect((selection as OneOffLocationSelection).text, '  Pátio coberto — piso 2  ');
    expect(selection, isNot(isA<CataloguedLocationSelection>()));
  });

  test('selection variants support exhaustive matching', () {
    String label(LocationSelection selection) => switch (selection) {
      CataloguedLocationSelection(:final snapshot) => snapshot.label,
      OneOffLocationSelection(:final text) => text,
    };
    expect(label(const LocationSelection.catalogued(snapshot)), 'Biblioteca');
    expect(label(const LocationSelection.oneOff('Sala temporária')), 'Sala temporária');
  });

  test('captured snapshot does not follow a later catalog replacement', () {
    var current = snapshot;
    final captured = LocationSelection.catalogued(current) as CataloguedLocationSelection;
    current = const LocationReferenceSnapshot(
      id: 'location-a',
      scope: institution,
      kind: LocationKind.external,
      label: 'Nome posterior',
    );
    expect(current.label, 'Nome posterior');
    expect(captured.snapshot.label, 'Biblioteca');
    expect(captured.snapshot.kind, LocationKind.internal);
  });

  test('absence stays nullable in the consumer', () {
    LocationSelection? selection;
    expect(selection, isNull);
    selection = const LocationSelection.oneOff('Pátio');
    expect(selection, isA<OneOffLocationSelection>());
  });
}
