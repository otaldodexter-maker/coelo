/// Minimum contract for the approved location reservations.
///
/// Published for review, deliberately without a reader, a writer, an adapter or
/// a single line of SQL. It exists because the weekly availability contract
/// ([LocationSchedule]) answers a different question and must not be widened
/// into this one by accident: availability says when a place is offered, a
/// reservation says that a named consumer holds it at a dated moment.
///
/// Availability is a subcomponent here, not a substitute. A reservation outside
/// every published window is still a reservation; the catalog decides what to
/// do about it through the scope's conflict policy, and neither the client nor
/// this file decides that.
///
/// Source of truth: the approved scope of
/// `docs/superpowers/specs/2026-09-02-superadmin-locais-mapas-agendamentos-design.md`.
/// Nothing here authorizes a table, a migration or a physical name.
library;

import 'location_catalog_entry.dart';

/// Who holds the reservation.
///
/// A reservation always belongs to something the actor was already working on.
/// There is no free-standing reservation, because nobody could later explain
/// why the room was held.
enum LocationReservationConsumerKind { group, activity, event, form }

final class LocationReservationConsumer {
  const LocationReservationConsumer({required this.kind, required this.id});

  final LocationReservationConsumerKind kind;

  /// The consumer's own stable id. Never a location id, never an option id.
  final String id;

  @override
  bool operator ==(Object other) =>
      other is LocationReservationConsumer && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

/// How a held moment repeats.
///
/// Only two shapes are approved: a single dated occurrence, and a weekly
/// repetition bounded by an end date. An unbounded recurrence is deliberately
/// absent - a room held forever is a room nobody can ever plan around.
sealed class LocationReservationRecurrence {
  const LocationReservationRecurrence();

  const factory LocationReservationRecurrence.once() = LocationReservationOnce;

  factory LocationReservationRecurrence.weekly({
    required Set<int> weekdays,
    required DateTime until,
    required String timeZone,
  }) = LocationReservationWeekly;
}

final class LocationReservationOnce extends LocationReservationRecurrence {
  const LocationReservationOnce();
}

final class LocationReservationWeekly extends LocationReservationRecurrence {
  LocationReservationWeekly({
    required Set<int> weekdays,
    required this.until,
    required this.timeZone,
  }) : weekdays = Set.unmodifiable(weekdays) {
    if (weekdays.isEmpty || weekdays.any((day) => day < 0 || day > 6)) {
      throw ArgumentError.value(weekdays, 'weekdays');
    }
    if (!until.isUtc || until != DateTime.utc(until.year, until.month, until.day)) {
      throw ArgumentError.value(until, 'until', 'use a date-only UTC representation');
    }
    if (timeZone.isEmpty || timeZone.trim() != timeZone || timeZone.length > 100) {
      throw ArgumentError.value(timeZone, 'timeZone');
    }
  }

  /// 0 is Sunday, matching [LocationScheduleWindow.weekday] so the two contracts
  /// can be compared without a translation nobody remembers to apply.
  final Set<int> weekdays;

  /// Inclusive local calendar date in [timeZone], represented at UTC midnight.
  /// This is a date, not the UTC instant at which recurrence ends.
  final DateTime until;

  /// Explicit IANA zone. The server validates the identifier and expands the
  /// rule using local wall-clock time, preserving it across offset changes.
  /// An occurrence's UTC offset alone cannot identify a recurrence's zone.
  final String timeZone;
}

/// What the scope does when a request lands on an occupied moment.
///
/// The policy belongs to the institution or the unit, never to the request, so
/// a caller cannot choose the lenient one for itself.
enum LocationSchedulingPolicy {
  /// The overlap is refused and nothing is written.
  block,

  /// The overlap may be confirmed, but only by an actor holding the specific
  /// capability, and only with a justification that is stored and audited.
  warn,
}

/// The answer to "may this be written?", decided server-side.
enum LocationReservationConflict {
  /// Nothing else holds the moment.
  none,

  /// Something holds it and the scope blocks overlaps. Terminal.
  refused,

  /// Something holds it, the scope allows a confirmed overlap, and this actor
  /// may confirm one. A justification becomes mandatory.
  confirmable,

  /// Something holds it, the scope allows a confirmed overlap, and this actor
  /// may not confirm one. Terminal for this actor.
  notConfirmable,
}

/// Where a reservation stands.
enum LocationReservationState { active, cancelled }

/// One dated moment a reservation holds.
///
/// Instants, not clock times: a reservation crosses a daylight-saving boundary
/// and a wall clock does not survive that. The weekly availability contract is
/// the opposite on purpose - it describes a rule, not a moment.
final class LocationReservationOccurrence {
  LocationReservationOccurrence({required this.startsAt, required this.endsAt}) {
    if (!startsAt.isUtc || !endsAt.isUtc) {
      throw ArgumentError('a reservation occurrence is stored in UTC');
    }
    if (!endsAt.isAfter(startsAt)) {
      throw ArgumentError.value(endsAt, 'endsAt', 'an occurrence with no duration');
    }
  }

  final DateTime startsAt;
  final DateTime endsAt;

  bool overlaps(LocationReservationOccurrence other) =>
      startsAt.isBefore(other.endsAt) && other.startsAt.isBefore(endsAt);
}

/// What a consumer asks the catalog to hold.
///
/// State, provenance, authorship, occurrence expansion and audit belong to the
/// server. This carries only what the actor chose, plus the justification when
/// the scope's policy demands one.
final class LocationReservationDraft {
  const LocationReservationDraft({
    required this.locationId,
    required this.consumer,
    required this.firstOccurrence,
    required this.recurrence,
    this.conflictJustification,
  });

  final String locationId;
  final LocationReservationConsumer consumer;

  /// The first dated moment. The server derives its wall-clock time in the
  /// weekly rule's explicit zone; clients never expand occurrences themselves.
  final LocationReservationOccurrence firstOccurrence;

  final LocationReservationRecurrence recurrence;

  /// Required, and only meaningful, when the server answered
  /// [LocationReservationConflict.confirmable] and the actor chose to proceed.
  /// Sending one otherwise is a client bug the server must reject rather than
  /// quietly store.
  final String? conflictJustification;
}

/// What the catalog answers about a request that has not been written yet.
///
/// A dry run exists because the alternative is worse: without it the actor
/// learns about a conflict only by failing to save, after typing everything.
final class LocationReservationAssessment {
  LocationReservationAssessment({
    required this.policy,
    required this.conflict,
    required List<LocationReservationOccurrence> conflicting,
  }) : conflicting = List.unmodifiable(conflicting);

  final LocationSchedulingPolicy policy;
  final LocationReservationConflict conflict;

  /// The occupied moments this request runs into. Empty when [conflict] is
  /// [LocationReservationConflict.none]. It never names the other consumer:
  /// who else holds a room is not this actor's business unless the catalog
  /// decides otherwise, and that decision has not been made.
  final List<LocationReservationOccurrence> conflicting;

  bool get requiresJustification => conflict == LocationReservationConflict.confirmable;
}

/// A reservation as the catalog reports it.
final class LocationReservation {
  LocationReservation({
    required this.id,
    required this.locationId,
    required this.consumer,
    required this.state,
    required this.recurrence,
    required List<LocationReservationOccurrence> occurrences,
    required this.managementVersion,
    this.confirmedOverConflict = false,
  }) : occurrences = List.unmodifiable(occurrences);

  final String id;
  final String locationId;
  final LocationReservationConsumer consumer;
  final LocationReservationState state;
  final LocationReservationRecurrence recurrence;

  /// Expanded server-side. The client never derives occurrences from a rule:
  /// two clients expanding the same rule differently is how double bookings
  /// become invisible.
  final List<LocationReservationOccurrence> occurrences;

  final int managementVersion;

  /// True when this reservation exists because someone confirmed an overlap
  /// under the `warn` policy. Kept on the reservation, not only in the audit
  /// trail, so the screen can say so without a second query.
  final bool confirmedOverConflict;
}

/// What is deliberately absent from this contract, and why.
///
/// - No writer, reader or adapter. C00 asked for the contract before the
///   plumbing, so the plumbing is not here.
/// - No physical table or column names. Those depend on a forward-only
///   inventory that is not mine to decide.
/// - No cancellation reason vocabulary. The approved scope does not define one,
///   and inventing one would put words in the product's mouth.
/// - No occurrence-level edit. The approved scope describes reservations
///   created and cancelled as a unit; editing one occurrence of a recurrence is
///   a real need that nobody has approved yet.
/// - No exposure of who else holds a conflicting moment. See
///   [LocationReservationAssessment.conflicting].
const String locationReservationsContractGaps = 'see the library comment above';
