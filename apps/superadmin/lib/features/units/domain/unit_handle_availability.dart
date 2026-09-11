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

/// Resultado da troca do @ por `superadmin_structure_handle_set_v1` (trava de
/// 30 dias, ADR 0034 Decisao 16). O servidor e quem decide; o cliente mostra a
/// mensagem honesta de cada recusa.
enum StructureHandleChangeOutcome { changed, cooldown, taken, invalid, stale, unavailable }

final class StructureHandleChange {
  const StructureHandleChange({
    required this.outcome,
    this.handle = '',
    this.managementVersion = 0,
    this.serverMessage,
  });

  final StructureHandleChangeOutcome outcome;
  final String handle;
  final int managementVersion;

  /// Mensagem devolvida pelo servidor (ex.: data da proxima troca permitida).
  final String? serverMessage;

  bool get changed => outcome == StructureHandleChangeOutcome.changed;

  String get message => switch (outcome) {
    StructureHandleChangeOutcome.changed => '@ alterado para @$handle.',
    StructureHandleChangeOutcome.cooldown =>
      serverMessage ?? 'O @ só pode ser alterado uma vez a cada 30 dias.',
    StructureHandleChangeOutcome.taken => 'Este @ já está em uso. Escolha outro.',
    StructureHandleChangeOutcome.invalid =>
      'Use letras minúsculas, números, ponto e sublinhado, começando e terminando com letra ou número.',
    StructureHandleChangeOutcome.stale =>
      'Este registro foi alterado por outra pessoa. Recarregue e tente novamente.',
    StructureHandleChangeOutcome.unavailable =>
      'Não foi possível alterar o @ agora. Tente novamente.',
  };
}

/// `kind` e `unit`, `group` ou `activity`; `expectedVersion` e a
/// `management_version` corrente da entidade.
typedef StructureHandleSetter =
    Future<StructureHandleChange> Function(
      String kind,
      String entityId,
      int expectedVersion,
      String handle,
    );
