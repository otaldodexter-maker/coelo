/// Resultado da verificacao de disponibilidade do @ enquanto o usuario digita
/// (ADR 0034 Decisao 16). O servidor normaliza o valor (minusculas, sem o @
/// inicial) e diz se esta livre; o cliente so exibe.
enum UnitHandleAvailabilityReason { available, taken, invalid, empty, unavailable }

final class UnitHandleAvailability {
  const UnitHandleAvailability({required this.reason, this.normalized = ''});

  final UnitHandleAvailabilityReason reason;
  final String normalized;

  bool get isAvailable => reason == UnitHandleAvailabilityReason.available;
}

/// `kind` e `institution`, `unit`, `group` ou `activity`; `excludeId` deixa a
/// propria entidade fora da checagem (edicao).
typedef StructureHandleAvailabilityChecker =
    Future<UnitHandleAvailability> Function(String kind, String handle, {String? excludeId});
