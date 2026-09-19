import 'institution_directory_item.dart';

/// Resultado de uma transição de ciclo de vida (spec 066).
final class InstitutionLifecycleResult {
  const InstitutionLifecycleResult({
    required this.institutionId,
    required this.status,
    required this.hardDeleted,
    this.managementVersion,
  });

  final String institutionId;

  /// `deleted` quando a exclusão foi real (linha removida).
  final String status;
  final bool hardDeleted;
  final int? managementVersion;
}

/// Comandos de ciclo de vida da instituição (spec 066, OQ-033 opção B).
/// Separado do repositório do diretório: o diretório funciona sem ele
/// (o menu de ações some) e os fakes de teste não precisam implementá-lo.
abstract interface class InstitutionLifecycleCommands {
  /// `active` ⇄ `inactive`; inativar exige [reason].
  Future<InstitutionLifecycleResult> changeStatus(
    String institutionId, {
    required int expectedVersion,
    required InstitutionStatus status,
    required String requestId,
    String? reason,
  });

  /// Exclusão real só sem dependentes (servidor decide); senão lógica.
  Future<InstitutionLifecycleResult> delete(
    String institutionId, {
    required int expectedVersion,
    required String requestId,
    required String reason,
  });
}
