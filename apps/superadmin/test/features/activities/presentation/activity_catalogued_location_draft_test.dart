import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_command.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_form_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../support/activities/fake_activity_directory_repository.dart';

const institution = 'institution-1';
const unit = 'institution-1-unit-1';
CataloguedLocationSelection selection({
  String owner = institution,
  String? unitId,
  String id = 'location-1',
}) => CataloguedLocationSelection(
  LocationReferenceSnapshot(
    id: id,
    scope: unitId == null
        ? LocationScope.institution(institutionId: owner)
        : LocationScope.unit(institutionId: owner, unitId: unitId),
    kind: LocationKind.internal,
    label: 'Local',
  ),
);
ActivityCreateReservationIntent reservation({
  int hour = 10,
  LocationReservationRecurrence recurrence = const LocationReservationRecurrence.once(),
  String? justification,
}) => ActivityCreateReservationIntent(
  firstOccurrence: LocationReservationOccurrence(
    startsAt: DateTime.utc(2026, 9, 10, hour),
    endsAt: DateTime.utc(2026, 9, 10, hour + 1),
  ),
  recurrence: recurrence,
  conflictJustification: justification,
);

void main() {
  Future<ActivityFormController> controller() async {
    final options = await FakeActivityDirectoryRepository().fetchFormOptions(
      institutionId: institution,
    );
    final result = ActivityFormController.create(
      options,
      initialInstitutionId: institution,
      initialUnitId: unit,
    );
    addTearDown(result.dispose);
    return result;
  }

  test('typed institution selection survives unit toggles and reaches draft', () async {
    final c = await controller();
    final value = selection();
    c.selectCataloguedLocation(value);
    c.setLocationReservation(reservation());
    c.toggleUnit(unit);
    expect(c.cataloguedLocationSelection, same(value));
    expect(c.toDraft().locationSelection, same(value));
    expect(c.toDraft().reservation, isNotNull);
    expect(c.toDraft().locationId, value.snapshot.id);
  });
  test('activity write freeze keeps catalog and reservation until submission ends', () async {
    final c = await controller();
    final a = selection();
    final intent = reservation();
    c.selectCataloguedLocation(a);
    c.setLocationReservation(intent);
    final signature = c.commandSignature;
    c.setSubmitting(true);
    c.selectCataloguedLocation(selection(id: 'location-2'));
    c.setLocationReservation(reservation(hour: 11));
    expect(c.cataloguedLocationSelection, same(a));
    expect(c.locationReservation, same(intent));
    expect(c.commandSignature, signature);
    c.setSubmitting(false);
    c.selectCataloguedLocation(selection(id: 'location-2'));
    expect(c.cataloguedLocationSelection!.snapshot.id, 'location-2');
  });
  test('unit selection and reservation are pruned with the actual unit', () async {
    final c = await controller();
    c.selectCataloguedLocation(selection(unitId: unit));
    c.setLocationReservation(reservation());
    c.toggleUnit(unit);
    expect(c.cataloguedLocationSelection, isNull);
    expect(c.toDraft().reservation, isNull);
  });
  test('foreign owner and unselected unit are rejected without changing selection', () async {
    final c = await controller();
    final value = selection();
    c.selectCataloguedLocation(value);
    expect(
      () => c.selectCataloguedLocation(selection(owner: 'institution-2')),
      throwsArgumentError,
    );
    expect(() => c.selectCataloguedLocation(selection(unitId: 'unit-other')), throwsArgumentError);
    expect(c.cataloguedLocationSelection, same(value));
  });
  test('institution change prunes catalog and reservation even with preserveSelection', () async {
    final c = await controller();
    c.selectCataloguedLocation(selection());
    c.setLocationReservation(reservation());
    await c.selectInstitution('institution-2', preserveSelection: true);
    expect(c.cataloguedLocationSelection, isNull);
    expect(c.toDraft().reservation, isNull);
  });
  test('legacy selection never impersonates a catalog snapshot and clears reservation', () async {
    final c = await controller();
    c.selectCataloguedLocation(selection());
    c.setLocationReservation(reservation());
    c.selectLocation('legacy');
    expect(c.cataloguedLocationSelection, isNull);
    expect(c.toDraft().reservation, isNull);
    expect(c.toDraft().locationId, 'legacy');
  });
  test('changing or clearing catalog requires a new reservation intention', () async {
    final c = await controller();
    c.selectCataloguedLocation(selection());
    c.setLocationReservation(reservation());
    c.selectCataloguedLocation(selection(id: 'location-2'));
    expect(c.toDraft().reservation, isNull);
    c.setLocationReservation(reservation());
    c.selectCataloguedLocation(null);
    expect(c.toDraft().reservation, isNull);
    expect(() => c.setLocationReservation(reservation()), throwsStateError);
  });
  test('every submitted reservation field participates in deterministic fingerprint', () async {
    final c = await controller();
    c.selectCataloguedLocation(selection());
    final values = <String>{c.commandSignature};
    for (final value in [
      reservation(),
      reservation(hour: 11),
      reservation(justification: 'Motivo'),
      reservation(
        recurrence: LocationReservationRecurrence.weekly(
          weekdays: {4, 1},
          until: DateTime.utc(2026, 9, 30),
          timeZone: 'America/Sao_Paulo',
        ),
      ),
    ]) {
      c.setLocationReservation(value);
      expect(values.add(c.commandSignature), isTrue);
    }
    final current = c.commandSignature;
    c.setLocationReservation(
      reservation(
        recurrence: LocationReservationRecurrence.weekly(
          weekdays: {1, 4},
          until: DateTime.utc(2026, 9, 30),
          timeZone: 'America/Sao_Paulo',
        ),
      ),
    );
    expect(c.commandSignature, current);
  });
}
