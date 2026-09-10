import 'location_catalog_entry.dart';
import 'location_selection.dart';

/// A historical reservation relationship, never a consumer's current choice.
final class LocationConsumerBinding {
  const LocationConsumerBinding({required this.location, required this.status});
  final LocationReferenceSnapshot location;
  final LocationCatalogStatus status;
}

final class LocationConsumerBindingPage {
  LocationConsumerBindingPage({
    required this.consumer,
    required List<LocationConsumerBinding> items,
    required this.nextLocationId,
  }) : items = List.unmodifiable(items);
  final LocationReservationConsumer consumer;
  final List<LocationConsumerBinding> items;
  final String? nextLocationId;
}
