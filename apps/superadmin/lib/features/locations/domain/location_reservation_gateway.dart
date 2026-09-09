import 'package:coelo_domain/locations.dart';

/// App-local boundary for reservation RPCs. Authorization and conflict
/// decisions remain server-side; [available] only describes composition.
abstract interface class LocationReservationGateway {
  bool get available;

  Future<LocationReservationAssessment> assess(LocationReservationDraft draft);

  Future<LocationReservation> create({
    required LocationReservationDraft draft,
    required String requestId,
  });

  Future<LocationReservation> cancel({
    required String locationId,
    required LocationReservationConsumer consumer,
    required String reservationId,
    required int expectedVersion,
    required String requestId,
  });

  Future<LocationReservationPage> listPaged({
    required String locationId,
    required LocationReservationConsumer consumer,
    String? afterId,
    int limit = 50,
  });

  Future<LocationSchedulingPolicyState> getPolicy({
    required String locationId,
    required LocationScope scope,
  });

  Future<LocationSchedulingPolicyState> setPolicy({
    required String locationId,
    required LocationScope scope,
    required LocationSchedulingPolicy policy,
    required int expectedVersion,
    required String requestId,
  });
}

final class LocationReservationPage {
  LocationReservationPage({
    required this.locationId,
    required this.consumer,
    required List<LocationReservation> items,
    required this.nextId,
  }) : items = List.unmodifiable(items);

  final String locationId;
  final LocationReservationConsumer consumer;
  final List<LocationReservation> items;
  final String? nextId;
}

/// Explicit policy stored on the location catalog owner. A null policy at
/// version zero means that no policy has been configured.
final class LocationSchedulingPolicyState {
  const LocationSchedulingPolicyState({
    required this.scope,
    required this.policy,
    required this.managementVersion,
  });

  final LocationScope scope;
  final LocationSchedulingPolicy? policy;
  final int managementVersion;
}

final class UnavailableLocationReservationGateway implements LocationReservationGateway {
  const UnavailableLocationReservationGateway();

  @override
  bool get available => false;

  Never _unavailable() => throw const LocationReservationGatewayUnavailableException();

  @override
  Future<LocationReservationAssessment> assess(LocationReservationDraft draft) async =>
      _unavailable();

  @override
  Future<LocationReservation> create({
    required LocationReservationDraft draft,
    required String requestId,
  }) async => _unavailable();

  @override
  Future<LocationReservation> cancel({
    required String locationId,
    required LocationReservationConsumer consumer,
    required String reservationId,
    required int expectedVersion,
    required String requestId,
  }) async => _unavailable();

  @override
  Future<LocationReservationPage> listPaged({
    required String locationId,
    required LocationReservationConsumer consumer,
    String? afterId,
    int limit = 50,
  }) async => _unavailable();

  @override
  Future<LocationSchedulingPolicyState> getPolicy({
    required String locationId,
    required LocationScope scope,
  }) async => _unavailable();

  @override
  Future<LocationSchedulingPolicyState> setPolicy({
    required String locationId,
    required LocationScope scope,
    required LocationSchedulingPolicy policy,
    required int expectedVersion,
    required String requestId,
  }) async => _unavailable();
}

final class LocationReservationDeniedException implements Exception {
  const LocationReservationDeniedException();
}

final class LocationReservationRejectedException implements Exception {
  const LocationReservationRejectedException();
}

final class LocationReservationConflictException implements Exception {
  const LocationReservationConflictException();
}

final class LocationReservationGatewayUnavailableException implements Exception {
  const LocationReservationGatewayUnavailableException();

  @override
  String toString() => 'Location reservation unavailable';
}
