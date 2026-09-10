/// Vínculo de uma criança com unidade e turma: vincular, transferir, editar e
/// revogar.
///
/// As quatro ações mexem em onde uma criança está dentro da instituição, e é
/// disso que dependem chamada, rotina e cuidado. Por isso o contrato aqui é
/// deliberadamente estreito: o cliente descreve a intenção e o servidor decide
/// tudo o mais. A instituição não aparece em lugar nenhum destes tipos, porque
/// ela é derivada do contexto infantil no banco — aceitar uma instituição vinda
/// do cliente permitiria mover a criança de um tenant para outro.
library;

enum StudentLinkFailureKind {
  /// A sessão não tem `people.assign_children` no escopo pedido.
  unauthorized,

  /// A criança, a unidade ou a turma não existem, ou existem fora do escopo.
  /// O servidor responde a mesma coisa nos dois casos, de propósito: separar
  /// confirmaria a existência do que está fora do alcance.
  notFound,

  /// Faltou algo que o comando exige: unidade, turma ou motivo.
  invalidInput,

  /// O vínculo mudou entre a leitura e a escrita.
  conflict,

  /// O ambiente não tem o backend de vínculo ligado.
  unavailable,
}

final class StudentLinkException implements Exception {
  const StudentLinkException(this.kind, this.message);
  final StudentLinkFailureKind kind;
  final String message;

  @override
  String toString() => message;
}

final class StudentLinkResult {
  const StudentLinkResult({
    required this.childContextId,
    required this.unitLinkId,
    required this.status,
    this.groupLinkId,
  });

  final String childContextId;
  final String unitLinkId;
  final String? groupLinkId;
  final String status;
}

abstract interface class StudentLinkRepository {
  /// Vincula a criança a uma unidade e, opcionalmente, a uma turma.
  ///
  /// Vincular de novo a mesma unidade reativa o vínculo que existe em vez de
  /// criar um segundo.
  Future<StudentLinkResult> link({
    required String requestId,
    required String childContextId,
    required String unitId,
    String? groupId,
    DateTime? startsAt,
  });

  /// Move a criança de uma unidade para outra.
  ///
  /// Exige motivo e autoriza os dois lados: quem só pode gerir a unidade de
  /// destino não pode retirar a criança da origem. As turmas da origem
  /// encerram junto, senão a criança continuaria aparecendo em chamada e
  /// rotina de uma unidade onde já não está.
  Future<StudentLinkResult> transfer({
    required String requestId,
    required String childContextId,
    required String fromUnitId,
    required String toUnitId,
    required String reason,
    String? toGroupId,
  });

  /// Ajusta a vigência da criança numa turma.
  Future<StudentLinkResult> edit({
    required String requestId,
    required String childContextId,
    required String unitId,
    required String groupId,
    DateTime? startsAt,
    DateTime? endsAt,
    bool clearEndsAt = false,
  });

  /// Revoga o vínculo com uma unidade, com motivo.
  ///
  /// Revogar não apaga: o vínculo fica marcado e carimbado, e o histórico
  /// continua legível, porque presença, rotina e cuidado passados apontam para
  /// um vínculo que existiu.
  Future<StudentLinkResult> revoke({
    required String requestId,
    required String childContextId,
    required String unitId,
    required String reason,
  });
}

/// Composição padrão enquanto o pacote de vínculo não estiver ligado.
///
/// Falha fechada e diz o motivo, em vez de deixar a tela achar que escreveu.
final class UnavailableStudentLinkRepository implements StudentLinkRepository {
  const UnavailableStudentLinkRepository();

  Never _unavailable() => throw const StudentLinkException(
    StudentLinkFailureKind.unavailable,
    'A gestão de vínculo de alunos está indisponível neste ambiente.',
  );

  @override
  Future<StudentLinkResult> link({
    required String requestId,
    required String childContextId,
    required String unitId,
    String? groupId,
    DateTime? startsAt,
  }) async => _unavailable();

  @override
  Future<StudentLinkResult> transfer({
    required String requestId,
    required String childContextId,
    required String fromUnitId,
    required String toUnitId,
    required String reason,
    String? toGroupId,
  }) async => _unavailable();

  @override
  Future<StudentLinkResult> edit({
    required String requestId,
    required String childContextId,
    required String unitId,
    required String groupId,
    DateTime? startsAt,
    DateTime? endsAt,
    bool clearEndsAt = false,
  }) async => _unavailable();

  @override
  Future<StudentLinkResult> revoke({
    required String requestId,
    required String childContextId,
    required String unitId,
    required String reason,
  }) async => _unavailable();
}
