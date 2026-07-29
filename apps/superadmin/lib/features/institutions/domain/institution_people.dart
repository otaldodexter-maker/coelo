import 'dart:typed_data';

enum InstitutionAdministratorLevel {
  adminMaster('Admin Master'),
  authorizedAdministrator('Administrador autorizado'),
  coordinator('Coordenador');

  const InstitutionAdministratorLevel(this.label);
  final String label;
}

enum InstitutionInvitationStatus {
  notSent('Não enviado'),
  sent('Enviado'),
  accepted('Aceito'),
  expired('Expirado');

  const InstitutionInvitationStatus(this.label);
  final String label;
}

enum InstitutionPersonField { firstName, lastName, displayName, email, mobilePhone, cpf }

final class InstitutionPersonDraft {
  const InstitutionPersonDraft({
    required this.firstName,
    required this.lastName,
    required this.displayName,
    this.email = '',
    this.mobilePhone = '',
    this.cpf = '',
  });

  final String firstName;
  final String lastName;
  final String displayName;
  final String email;
  final String mobilePhone;
  final String cpf;

  InstitutionPersonDraft copyWith({
    String? firstName,
    String? lastName,
    String? displayName,
    String? email,
    String? mobilePhone,
    String? cpf,
  }) => InstitutionPersonDraft(
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    displayName: displayName ?? this.displayName,
    email: email ?? this.email,
    mobilePhone: mobilePhone ?? this.mobilePhone,
    cpf: cpf ?? this.cpf,
  );
}

final class InstitutionLegalRepresentative {
  const InstitutionLegalRepresentative({required this.id, required this.person});

  final String id;
  final InstitutionPersonDraft person;

  InstitutionLegalRepresentative copyWith({InstitutionPersonDraft? person}) =>
      InstitutionLegalRepresentative(id: id, person: person ?? this.person);
}

final class InstitutionInvitationHistoryEntry {
  const InstitutionInvitationHistoryEntry({required this.status, required this.occurredAt});

  final InstitutionInvitationStatus status;
  final DateTime occurredAt;
}

final class InstitutionAdministratorDraft {
  const InstitutionAdministratorDraft({
    required this.id,
    required this.person,
    required this.handle,
    required this.level,
    required this.invitationStatus,
    required this.invitationHistory,
    this.sourceRepresentativeId,
    this.avatarBytes,
    this.avatarFileName,
  });

  final String id;
  final InstitutionPersonDraft person;
  final String handle;
  final InstitutionAdministratorLevel level;
  final InstitutionInvitationStatus invitationStatus;
  final List<InstitutionInvitationHistoryEntry> invitationHistory;
  final String? sourceRepresentativeId;
  final Uint8List? avatarBytes;
  final String? avatarFileName;

  InstitutionAdministratorDraft copyWith({
    InstitutionPersonDraft? person,
    String? handle,
    InstitutionAdministratorLevel? level,
    InstitutionInvitationStatus? invitationStatus,
    List<InstitutionInvitationHistoryEntry>? invitationHistory,
    String? sourceRepresentativeId,
    bool clearSourceRepresentativeId = false,
    Uint8List? avatarBytes,
    String? avatarFileName,
    bool clearAvatar = false,
  }) => InstitutionAdministratorDraft(
    id: id,
    person: person ?? this.person,
    handle: handle ?? this.handle,
    level: level ?? this.level,
    invitationStatus: invitationStatus ?? this.invitationStatus,
    invitationHistory: invitationHistory ?? this.invitationHistory,
    sourceRepresentativeId: clearSourceRepresentativeId
        ? null
        : sourceRepresentativeId ?? this.sourceRepresentativeId,
    avatarBytes: clearAvatar ? null : avatarBytes ?? this.avatarBytes,
    avatarFileName: clearAvatar ? null : avatarFileName ?? this.avatarFileName,
  );
}
