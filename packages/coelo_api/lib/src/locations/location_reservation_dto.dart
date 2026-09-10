import 'package:coelo_domain/locations.dart';

/// Request body only. Authorization, policy and occurrence expansion belong to
/// the server. This codec does not call an endpoint or authorize an override.
Map<String, Object?> encodeLocationReservationDraftV2(LocationReservationDraft draft) => {
  'location_id': _uuid(draft.locationId),
  'consumer': _encodeConsumer(draft.consumer),
  'first_occurrence': {
    'starts_at': draft.firstOccurrence.startsAt.toIso8601String(),
    'ends_at': draft.firstOccurrence.endsAt.toIso8601String(),
  },
  'recurrence': switch (draft.recurrence) {
    LocationReservationOnce() => {'kind': 'once'},
    LocationReservationWeekly(:final weekdays, :final until, :final timeZone) => {
      'kind': 'weekly',
      'weekdays': weekdays.toList()..sort(),
      'until': _calendarDate(until),
      'time_zone': timeZone,
    },
  },
  'conflict_justification': _justification(draft.conflictJustification),
};

/// Decodes the success payload after the transport has handled its envelope.
/// Correlation checks provide integrity, never proof of authorization.
LocationReservation decodeLocationReservationV2(
  Object? raw, {
  required String requestedLocationId,
  required LocationReservationConsumer requestedConsumer,
}) {
  final data = _object(raw, {
    'id',
    'location_id',
    'consumer',
    'state',
    'recurrence',
    'occurrences',
    'management_version',
    'confirmed_over_conflict',
  });
  final consumer = _correlate(data, requestedLocationId, requestedConsumer);
  final version = data['management_version'];
  final confirmed = data['confirmed_over_conflict'];
  if (version is! int || version < 1 || confirmed is! bool) _invalid();
  final state = switch (data['state']) {
    'active' => LocationReservationState.active,
    'cancelled' => LocationReservationState.cancelled,
    _ => _invalid(),
  };
  final occurrences = _occurrences(data['occurrences']);
  final recurrence = _recurrence(data['recurrence']);
  if (occurrences.isEmpty || (recurrence is LocationReservationOnce && occurrences.length != 1)) {
    _invalid();
  }
  return LocationReservation(
    id: _uuid(data['id']),
    locationId: _uuid(data['location_id']),
    consumer: consumer,
    state: state,
    recurrence: recurrence,
    occurrences: occurrences,
    managementVersion: version,
    confirmedOverConflict: confirmed,
  );
}

/// Checks the intent of an atomic create after decoding its reservation.
/// The server expands weekly occurrences in the requested timezone, including
/// DST. Only the first interval and recurrence definition are echoed intent;
/// later UTC intervals must not be reconstructed with fixed client durations.
void requireLocationReservationIntentV2(
  LocationReservation reservation, {
  required LocationReservationOccurrence firstOccurrence,
  required LocationReservationRecurrence recurrence,
  required String? conflictJustification,
}) {
  if (reservation.occurrences.isEmpty) _invalid();
  final first = reservation.occurrences.first;
  if (!first.startsAt.isAtSameMomentAs(firstOccurrence.startsAt) ||
      !first.endsAt.isAtSameMomentAs(firstOccurrence.endsAt)) {
    _invalid();
  }
  final sameRecurrence = switch ((recurrence, reservation.recurrence)) {
    (LocationReservationOnce(), LocationReservationOnce()) => true,
    (LocationReservationWeekly expected, LocationReservationWeekly actual) =>
      expected.timeZone == actual.timeZone &&
          expected.until == actual.until &&
          expected.weekdays.length == actual.weekdays.length &&
          expected.weekdays.containsAll(actual.weekdays),
    _ => false,
  };
  if (!sameRecurrence ||
      reservation.confirmedOverConflict && (conflictJustification?.trim().isEmpty ?? true)) {
    _invalid();
  }
}

/// A conflict payload exposes occupied intervals, without another consumer's
/// identity. The writer must reassess after locking; this is not a reservation.
LocationReservationAssessment decodeLocationReservationAssessmentV2(
  Object? raw, {
  required String requestedLocationId,
  required LocationReservationConsumer requestedConsumer,
}) {
  final data = _object(raw, {'location_id', 'consumer', 'policy', 'conflict', 'conflicting'});
  _correlate(data, requestedLocationId, requestedConsumer);
  final policy = switch (data['policy']) {
    'block' => LocationSchedulingPolicy.block,
    'warn' => LocationSchedulingPolicy.warn,
    _ => _invalid(),
  };
  final conflict = switch (data['conflict']) {
    'none' => LocationReservationConflict.none,
    'refused' => LocationReservationConflict.refused,
    'confirmable' => LocationReservationConflict.confirmable,
    'not_confirmable' => LocationReservationConflict.notConfirmable,
    _ => _invalid(),
  };
  final intervals = _occurrences(data['conflicting']);
  if ((conflict == LocationReservationConflict.none) != intervals.isEmpty ||
      (policy == LocationSchedulingPolicy.block &&
          (conflict == LocationReservationConflict.confirmable ||
              conflict == LocationReservationConflict.notConfirmable)) ||
      (policy == LocationSchedulingPolicy.warn &&
          conflict == LocationReservationConflict.refused)) {
    _invalid();
  }
  return LocationReservationAssessment(policy: policy, conflict: conflict, conflicting: intervals);
}

Map<String, Object?> _encodeConsumer(LocationReservationConsumer consumer) => {
  'kind': consumer.kind.name,
  'id': _uuid(consumer.id),
};

LocationReservationConsumer _correlate(
  Map<String, Object?> data,
  String locationId,
  LocationReservationConsumer expected,
) {
  if (_uuid(data['location_id']) != _uuid(locationId)) _invalid();
  final raw = _object(data['consumer'], {'kind', 'id'});
  final consumer = LocationReservationConsumer(
    kind: switch (raw['kind']) {
      'group' => LocationReservationConsumerKind.group,
      'activity' => LocationReservationConsumerKind.activity,
      'event' => LocationReservationConsumerKind.event,
      'form' => LocationReservationConsumerKind.form,
      _ => _invalid(),
    },
    id: _uuid(raw['id']),
  );
  if (consumer.kind != expected.kind || consumer.id != _uuid(expected.id)) _invalid();
  return consumer;
}

LocationReservationRecurrence _recurrence(Object? raw) {
  if (raw is! Map) _invalid();
  if (raw['kind'] == 'once') {
    _object(raw, {'kind'});
    return const LocationReservationRecurrence.once();
  }
  final data = _object(raw, {'kind', 'weekdays', 'until', 'time_zone'});
  final days = data['weekdays'];
  final until = data['until'];
  final zone = data['time_zone'];
  if (data['kind'] != 'weekly' ||
      days is! List ||
      days.isEmpty ||
      days.length > 7 ||
      days.any((day) => day is! int || day < 0 || day > 6) ||
      days.toSet().length != days.length ||
      until is! String ||
      zone is! String ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(until)) {
    _invalid();
  }
  final date = DateTime.tryParse('${until}T00:00:00Z');
  if (date == null || _calendarDate(date) != until) _invalid();
  try {
    return LocationReservationRecurrence.weekly(
      weekdays: days.cast<int>().toSet(),
      until: date,
      timeZone: zone,
    );
  } on ArgumentError {
    _invalid();
  }
}

List<LocationReservationOccurrence> _occurrences(Object? raw) {
  // Protocol bound only; the server owns the product's expansion limit.
  if (raw is! List || raw.length > 1000) _invalid();
  return raw
      .map((item) {
        final data = _object(item, {'starts_at', 'ends_at'});
        try {
          return LocationReservationOccurrence(
            startsAt: _instant(data['starts_at']),
            endsAt: _instant(data['ends_at']),
          );
        } on ArgumentError {
          _invalid();
        }
      })
      .toList(growable: false);
}

DateTime _instant(Object? raw) {
  if (raw is! String ||
      raw.length > 40 ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?(Z|\+00:00)$').hasMatch(raw)) {
    _invalid();
  }
  final instant = DateTime.tryParse(raw);
  if (instant == null || !instant.isUtc || _calendarDate(instant) != raw.substring(0, 10)) {
    _invalid();
  }
  // DateTime.parse normalizes overflowing hours/minutes; the wire must not.
  if (instant.hour != int.parse(raw.substring(11, 13)) ||
      instant.minute != int.parse(raw.substring(14, 16)) ||
      instant.second != int.parse(raw.substring(17, 19))) {
    _invalid();
  }
  return instant;
}

String _calendarDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _uuid(Object? raw) {
  if (raw is! String ||
      !RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
      ).hasMatch(raw)) {
    _invalid();
  }
  return raw.toLowerCase();
}

String? _justification(String? raw) {
  if (raw == null) return null;
  final value = raw.trim();
  if (value.isEmpty || value.length > 2000) _invalid();
  return value;
}

Map<String, Object?> _object(Object? raw, Set<String> keys) {
  if (raw is! Map ||
      raw.length != keys.length ||
      raw.keys.any((key) => key is! String || !keys.contains(key))) {
    _invalid();
  }
  return Map<String, Object?>.from(raw);
}

Never _invalid() => throw const FormatException('Invalid location reservation payload');
