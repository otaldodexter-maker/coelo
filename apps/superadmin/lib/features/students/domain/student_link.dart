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


final class StudentGroupLink {
  const StudentGroupLink({
    required this.groupLinkId,
    required this.groupId,
    required this.groupName,
    required this.status,
    this.startsAt,
    this.endsAt,
  });

  final String groupLinkId;
  final String groupId;
  final String groupName;
  final String status;
  final DateTime? startsAt;
  final DateTime? endsAt;

  bool get isActive => status == 'active';
}

final class StudentUnitLink {
  StudentUnitLink({
    required this.unitLinkId,
    required this.unitId,
    required this.unitName,
    required this.status,
    List<StudentGroupLink> groupLinks = const [],
    this.acceptedAt,
    this.revokedAt,
  }) : groupLinks = List.unmodifiable(groupLinks);

  final String unitLinkId;
  final String unitId;
  final String unitName;
  final String status;
  final List<StudentGroupLink> groupLinks;
  final DateTime? acceptedAt;
  final DateTime? revokedAt;

  /// Revogar não apaga, então um vínculo revogado continua na lista e precisa
  /// ser distinguido na tela em vez de sumir.
  bool get isRevoked => status == 'revoked';
  bool get isCurrent => status == 'active' || status == 'awaiting_allocation';
}

final class StudentLinks {
  StudentLinks({
    required this.childContextId,
    required this.childPersonId,
    required this.displayName,
    required this.institutionId,
    required this.canManage,
    List<StudentUnitLink> unitLinks = const [],
  }) : unitLinks = List.unmodifiable(unitLinks);

  final String childContextId;
  final String childPersonId;
  final String displayName;
  final String institutionId;

  /// Ler onde a criança está é leitura de diretório; mover exige
  /// `people.assign_children`. O servidor calcula os dois separadamente e a
  /// tela só desenha as ações quando este for verdadeiro — sem nunca depender
  /// disso para autorizar, porque a autorização é refeita em cada comando.
  final bool canManage;
  final List<StudentUnitLink> unitLinks;
}

abstract interface class StudentLinkRepository {
  /// Lê onde a criança está hoje: unidades, turmas e vigências.
  Future<StudentLinks> fetchLinks(String childContextId);

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
  Future<StudentLinks> fetchLinks(String childContextId) async => _unavailable();

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
