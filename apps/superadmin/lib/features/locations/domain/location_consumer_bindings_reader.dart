import 'package:coelo_domain/locations.dart';

abstract interface class LocationConsumerBindingsReader {
  Future<LocationConsumerBindingPage> fetchPage({
    required LocationReservationConsumer consumer,
    String? afterLocationId,
    int limit = 20,
  });
}

final class UnavailableLocationConsumerBindingsReader implements LocationConsumerBindingsReader {
  const UnavailableLocationConsumerBindingsReader();
  @override
  Future<LocationConsumerBindingPage> fetchPage({
    required LocationReservationConsumer consumer,
    String? afterLocationId,
    int limit = 20,
  }) async => throw StateError('Consumer bindings unavailable');
}
