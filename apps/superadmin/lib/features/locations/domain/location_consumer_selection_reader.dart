import 'package:coelo_domain/locations.dart';

abstract interface class LocationConsumerSelectionReader {
  /// Candidate composition availability, never actor authorization.
  bool get available;
  Future<LocationConsumerCurrentSelection> fetchSelection({
    required LocationReservationConsumer consumer,
  });
}

final class UnavailableLocationConsumerSelectionReader implements LocationConsumerSelectionReader {
  const UnavailableLocationConsumerSelectionReader();
  @override
  bool get available => false;
  @override
  Future<LocationConsumerCurrentSelection> fetchSelection({
    required LocationReservationConsumer consumer,
  }) async => throw StateError('Consumer selection unavailable');
}
