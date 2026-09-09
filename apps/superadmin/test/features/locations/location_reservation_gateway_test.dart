import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/locations/domain/location_reservation_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

const _locationId = '30000000-0000-4000-8000-000000000001';
const _consumer = LocationReservationConsumer(
  kind: LocationReservationConsumerKind.group,
  id: '40000000-0000-4000-8000-000000000001',
);
final _draft = LocationReservationDraft(
  locationId: _locationId,
  consumer: _consumer,
  firstOccurrence: LocationReservationOccurrence(
    startsAt: DateTime.utc(2026, 9, 10, 13),
    endsAt: DateTime.utc(2026, 9, 10, 14),
  ),
  recurrence: const LocationReservationRecurrence.once(),
);

void main() {
  test('the default gateway reports unavailability and never succeeds silently', () async {
    const gateway = UnavailableLocationReservationGateway();

    expect(gateway.available, isFalse);
    await expectLater(
      gateway.assess(_draft),
      throwsA(isA<LocationReservationGatewayUnavailableException>()),
    );
    await expectLater(
      gateway.listPaged(locationId: _locationId, consumer: _consumer),
      throwsA(isA<LocationReservationGatewayUnavailableException>()),
    );
  });
}
