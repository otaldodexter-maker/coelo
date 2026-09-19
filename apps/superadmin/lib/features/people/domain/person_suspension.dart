/// Suspensão por período de uma pessoa (spec 066 §3, lote 98): enquanto vale,
/// a conta não resolve para a pessoa e ela some do app. Interface pequena
/// implementada pelo repositório Supabase; a tela só a recebe quando o ator
/// pode mutar a estrutura. Erros reutilizam as exceções do ciclo de vida.
abstract interface class PersonSuspensionCommands {
  /// [until] nulo = até reativar manualmente.
  Future<PersonSuspensionResult> suspend(
    String personId, {
    required String requestId,
    required String reason,
    DateTime? from,
    DateTime? until,
  });

  Future<PersonSuspensionResult> reactivate(
    String personId, {
    required String requestId,
    String? reason,
  });
}

final class PersonSuspensionResult {
  const PersonSuspensionResult({
    required this.personId,
    required this.suspendedNow,
    this.suspendedFrom,
    this.suspendedUntil,
  });

  final String personId;
  final bool suspendedNow;
  final DateTime? suspendedFrom;
  final DateTime? suspendedUntil;
}
