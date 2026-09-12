/// O @ de uma pessoa (ADR 0034, Decisão 16): identidade pública única,
/// gerada pelo servidor ao nascer e trocável uma vez a cada 30 dias por quem
/// responde pela pessoa. Contrato das RPCs `superadmin_person_handle_*`.
final class PersonHandle {
  const PersonHandle({
    required this.personId,
    required this.handle,
    required this.canEdit,
    this.lastChangedAt,
    this.canChangeAt,
  });

  factory PersonHandle.fromJson(Map<String, dynamic> json) => PersonHandle(
    personId: json['person_id'] as String,
    handle: json['handle'] as String,
    canEdit: json['can_edit'] as bool? ?? false,
    lastChangedAt: DateTime.tryParse(json['last_changed_at'] as String? ?? ''),
    canChangeAt: DateTime.tryParse(json['can_change_at'] as String? ?? ''),
  );

  final String personId;
  final String handle;
  final bool canEdit;
  final DateTime? lastChangedAt;
  final DateTime? canChangeAt;

  // Before the first change, canChangeAt is the server's current time.
  // Clock skew must not turn that timestamp into a first-change cooldown.
  bool get inCooldown =>
      lastChangedAt != null && canChangeAt != null && canChangeAt!.isAfter(DateTime.now());
}

enum PersonHandleAvailability {
  available('Disponível'),
  invalidFormat(
    'Use de 3 a 30 caracteres: letras minúsculas, números, sublinhado e no máximo um ponto.',
  ),
  reserved('Este @ é reservado.'),
  taken('Este @ já está em uso.');

  const PersonHandleAvailability(this.message);

  final String message;

  static PersonHandleAvailability fromReason(String? reason) => switch (reason) {
    'ok' => PersonHandleAvailability.available,
    'reserved' => PersonHandleAvailability.reserved,
    'taken' => PersonHandleAvailability.taken,
    _ => PersonHandleAvailability.invalidFormat,
  };
}

abstract interface class PersonHandleRepository {
  /// `null` quando a pessoa ainda não tem @ (pessoa de serviço, por exemplo).
  Future<PersonHandle?> fetch(String personId);

  Future<PersonHandleAvailability> checkAvailability(String handle, {String? personId});

  Future<PersonHandle> change({
    required String requestId,
    required String personId,
    required String handle,
    required String reason,
  });
}

final class PersonHandleException implements Exception {
  const PersonHandleException(this.message);
  final String message;
}

final class PersonHandleUnauthorizedException extends PersonHandleException {
  const PersonHandleUnauthorizedException() : super('Você não tem permissão para ver este @.');
}

final class PersonHandleUnavailableException extends PersonHandleException {
  const PersonHandleUnavailableException()
    : super('A consulta do @ não está disponível nesta composição.');
}

final class UnavailablePersonHandleRepository implements PersonHandleRepository {
  const UnavailablePersonHandleRepository();

  @override
  Future<PersonHandle?> fetch(String personId) async =>
      throw const PersonHandleUnavailableException();

  @override
  Future<PersonHandleAvailability> checkAvailability(String handle, {String? personId}) async =>
      throw const PersonHandleUnavailableException();

  @override
  Future<PersonHandle> change({
    required String requestId,
    required String personId,
    required String handle,
    required String reason,
  }) async => throw const PersonHandleUnavailableException();
}
