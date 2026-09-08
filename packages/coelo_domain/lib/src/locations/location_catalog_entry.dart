import 'location_selection.dart';

// The reservations contract rides this file's existing place in the package
// barrel. Adding a line to lib/locations.dart would change an export surface
// that is outside this executor's reservation; exporting from here does not.
export 'location_reservations.dart';

/// Classification only; none of these values grants access to a reader.
enum LocationVisibility { team, guardians, students, all }

enum LocationCatalogStatus { draft, active, inactive, suspended, archived }

/// Read projection of the prepared catalog contract, not proof of access.
final class LocationCatalogEntry {
  LocationCatalogEntry({
    required this.id,
    required this.scope,
    required this.kind,
    required this.name,
    required this.description,
    required this.floor,
    required Map<String, String?>? address,
    required this.visibility,
    required this.status,
    required this.managementVersion,
    required this.createdAt,
    required this.updatedAt,
  }) : address = address == null ? null : Map.unmodifiable(address);

  final String id;
  final LocationScope scope;
  final LocationKind kind;
  final String name;
  final String? description;
  final String? floor;
  final Map<String, String?>? address;
  final LocationVisibility visibility;
  final LocationCatalogStatus status;
  final int managementVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
}

final class LocationDirectoryResult {
  LocationDirectoryResult({required List<LocationCatalogEntry> items, required this.totalCount})
    : items = List.unmodifiable(items);

  final List<LocationCatalogEntry> items;
  final int totalCount;
}

/// A location's weekly availability, as the catalog publishes it.
///
/// Minutes from midnight rather than a clock time: the window is then an
/// integer range that sorts and compares the same way in every client, and no
/// timezone can move it by an hour twice a year. 1440 is midnight at the end of
/// the day, which is why it is a valid end and never a valid start.
final class LocationScheduleWindow implements Comparable<LocationScheduleWindow> {
  LocationScheduleWindow({
    required this.weekday,
    required this.startsMinute,
    required this.endsMinute,
  }) {
    if (weekday < 0 || weekday > 6) {
      throw ArgumentError.value(weekday, 'weekday', 'the week has seven days');
    }
    if (startsMinute < 0 || startsMinute > 1439) {
      throw ArgumentError.value(startsMinute, 'startsMinute', 'outside the day');
    }
    if (endsMinute < 1 || endsMinute > 1440) {
      throw ArgumentError.value(endsMinute, 'endsMinute', 'outside the day');
    }
    if (startsMinute >= endsMinute) {
      throw ArgumentError.value(endsMinute, 'endsMinute', 'a window with no duration');
    }
  }

  /// 0 is Sunday, matching the catalog's own numbering.
  final int weekday;
  final int startsMinute;
  final int endsMinute;

  /// Two windows overlap when one starts before the other ends on the same day.
  /// Touching is not overlapping: 08:00-12:00 and 12:00-14:00 are two windows.
  bool overlaps(LocationScheduleWindow other) =>
      weekday == other.weekday && startsMinute < other.endsMinute && other.startsMinute < endsMinute;

  @override
  int compareTo(LocationScheduleWindow other) {
    final byDay = weekday.compareTo(other.weekday);
    return byDay != 0 ? byDay : startsMinute.compareTo(other.startsMinute);
  }

  @override
  bool operator ==(Object other) =>
      other is LocationScheduleWindow &&
      other.weekday == weekday &&
      other.startsMinute == startsMinute &&
      other.endsMinute == endsMinute;

  @override
  int get hashCode => Object.hash(weekday, startsMinute, endsMinute);

  @override
  String toString() => 'LocationScheduleWindow($weekday, $startsMinute-$endsMinute)';
}

/// The whole week for one location, plus the version it was read at.
///
/// An empty [windows] is a real answer and means nothing is published. It must
/// never be read as "available at all times": the catalog says what was
/// declared, and silence is not a declaration.
final class LocationSchedule {
  LocationSchedule({
    required this.locationId,
    required this.managementVersion,
    required List<LocationScheduleWindow> windows,
  }) : windows = List.unmodifiable([...windows]..sort());

  final String locationId;
  final int managementVersion;
  final List<LocationScheduleWindow> windows;

  bool get isPublished => windows.isNotEmpty;
}
