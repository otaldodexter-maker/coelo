/// What this actor may do to a location, one action at a time.
///
/// A render gate, never authorization. The server checks each capability on its
/// own and answers a refusal as a refusal; this type only decides what is worth
/// drawing, and drawing less than the server allows is a smaller mistake than
/// drawing more.
///
/// It exists because the four writes do not have to be granted together and the
/// catalog assumed they were: one flag drew the create button, the edit button,
/// the status actions, the copy and the schedule. An actor allowed to change a
/// status was therefore shown a delete-shaped surface for everything else, and
/// an actor allowed only to schedule was shown nothing at all unless they could
/// also create.
final class LocationCapabilities {
  const LocationCapabilities({
    this.create = false,
    this.update = false,
    this.status = false,
    this.copy = false,
    this.schedule = false,
  });

  /// The derivation the catalog used before the capabilities had names.
  ///
  /// Kept so a caller passing only the old flags keeps the old behaviour to the
  /// pixel: `canCreate` draws creation, and `canManage` - falling back to
  /// `canCreate` - draws the other four together.
  factory LocationCapabilities.fromLegacyFlags({required bool canCreate, bool? canManage}) {
    final manage = canManage ?? canCreate;
    return LocationCapabilities(
      create: canCreate,
      update: manage,
      status: manage,
      copy: manage,
      schedule: manage,
    );
  }

  /// Nothing granted, which is what every default resolves to. A composition
  /// that forgets to pass capabilities gets a read-only catalog, not an open
  /// one.
  static const none = LocationCapabilities();

  /// Every write granted.
  ///
  /// For a caller that has already decided the actor may write - the detail
  /// panel keeps this as its default so that handing it a writer behaves
  /// exactly as it did before this type existed.
  static const all = LocationCapabilities(
    create: true,
    update: true,
    status: true,
    copy: true,
    schedule: true,
  );

  /// May create a new location in this scope.
  final bool create;

  /// May edit an existing location's fields.
  final bool update;

  /// May move a location between statuses.
  final bool status;

  /// May duplicate a location, including bringing one down from the
  /// institution to a unit.
  final bool copy;

  /// May read and set the weekly availability windows.
  final bool schedule;

  /// Whether any write at all is granted.
  ///
  /// What decides if a writer is worth handing to a surface: a panel with no
  /// granted write should not hold one, so that a bug cannot turn into a
  /// request.
  bool get writesAnything => create || update || status || copy || schedule;

  /// Whether nothing is granted, which is the read-only catalog.
  bool get isReadOnly => !writesAnything;

  LocationCapabilities copyWith({
    bool? create,
    bool? update,
    bool? status,
    bool? copy,
    bool? schedule,
  }) => LocationCapabilities(
    create: create ?? this.create,
    update: update ?? this.update,
    status: status ?? this.status,
    copy: copy ?? this.copy,
    schedule: schedule ?? this.schedule,
  );

  @override
  bool operator ==(Object other) =>
      other is LocationCapabilities &&
      other.create == create &&
      other.update == update &&
      other.status == status &&
      other.copy == copy &&
      other.schedule == schedule;

  @override
  int get hashCode => Object.hash(create, update, status, copy, schedule);

  @override
  String toString() =>
      'LocationCapabilities(create: $create, update: $update, status: $status, '
      'copy: $copy, schedule: $schedule)';
}
