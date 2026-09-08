/// Catalog owner, not the consumer's context or evidence of authorization.
///
/// Institution and unit catalogs are independent. The server must verify all
/// supplied identifiers and the unit's real institutional relationship.
sealed class LocationScope {
  const LocationScope();

  const factory LocationScope.institution({required String institutionId}) =
      InstitutionLocationScope;

  const factory LocationScope.unit({required String institutionId, required String unitId}) =
      UnitLocationScope;

  String get institutionId;
}

final class InstitutionLocationScope extends LocationScope {
  const InstitutionLocationScope({required this.institutionId});

  @override
  final String institutionId;
}

final class UnitLocationScope extends LocationScope {
  const UnitLocationScope({required this.institutionId, required this.unitId});

  @override
  final String institutionId;
  final String unitId;
}

enum LocationKind { internal, external }

/// Historical reference received from a catalog, not a full catalog entity.
///
/// This value does not establish current status, visibility or permission.
/// Address validation, ownership and access must be checked server-side.
/// Consumers retain their own version context and must not infer [kind] from
/// legacy options that do not supply it.
final class LocationReferenceSnapshot {
  const LocationReferenceSnapshot({
    required this.id,
    required this.scope,
    required this.kind,
    required this.label,
  });

  /// Stable location ID, not an option, reservation or source-copy ID.
  final String id;
  final LocationScope scope;
  final LocationKind kind;
  final String label;
}

/// A consumer's choice; absence is represented as nullable by that consumer.
///
/// Neither variant reserves a space or grants access. Saving a one-off choice
/// into a catalog is a separate, explicit, server-authorized operation.
sealed class LocationSelection {
  const LocationSelection();

  const factory LocationSelection.catalogued(LocationReferenceSnapshot snapshot) =
      CataloguedLocationSelection;

  const factory LocationSelection.oneOff(String text) = OneOffLocationSelection;
}

final class CataloguedLocationSelection extends LocationSelection {
  const CataloguedLocationSelection(this.snapshot);

  final LocationReferenceSnapshot snapshot;
}

/// Text kept only by the originating consumer, without a fabricated catalog ID.
final class OneOffLocationSelection extends LocationSelection {
  const OneOffLocationSelection(this.text);

  final String text;
}
