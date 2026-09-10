import 'location_catalog_entry.dart';
import 'location_selection.dart';

/// Current persisted catalog choice returned for an authorized consumer.
/// This is separate from reservation history and never reserves a time slot.
final class LocationConsumerCurrentSelection {
  const LocationConsumerCurrentSelection({
    required this.consumer,
    required this.location,
    required this.status,
  }) : assert((location == null) == (status == null));

  final LocationReservationConsumer consumer;
  final LocationReferenceSnapshot? location;
  final LocationCatalogStatus? status;
}
