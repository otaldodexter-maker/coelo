enum PlatformUserRole { owner, operations, support, content, auditor }

extension PlatformUserRoleLabel on PlatformUserRole {
  String get label => switch (this) {
    PlatformUserRole.owner => 'Owner',
    PlatformUserRole.operations => 'Operations',
    PlatformUserRole.support => 'Support',
    PlatformUserRole.content => 'Content',
    PlatformUserRole.auditor => 'Auditor',
  };
}

enum PlatformMembershipStatus { invited, active, suspended, revoked }

extension PlatformMembershipStatusLabel on PlatformMembershipStatus {
  String get label => switch (this) {
    PlatformMembershipStatus.invited => 'Convidado',
    PlatformMembershipStatus.active => 'Ativo',
    PlatformMembershipStatus.suspended => 'Suspenso',
    PlatformMembershipStatus.revoked => 'Revogado',
  };
}

enum PlatformInvitationStatus { pending, accepted, revoked, expired }

extension PlatformInvitationStatusLabel on PlatformInvitationStatus {
  String get label => switch (this) {
    PlatformInvitationStatus.pending => 'Pendente',
    PlatformInvitationStatus.accepted => 'Aceito',
    PlatformInvitationStatus.revoked => 'Revogado',
    PlatformInvitationStatus.expired => 'Expirado',
  };
}

enum SuperadminCredentialStatus { noAccess, active, blocked, recoveryPending }

extension SuperadminCredentialStatusLabel on SuperadminCredentialStatus {
  String get label => switch (this) {
    SuperadminCredentialStatus.noAccess => 'Sem acesso',
    SuperadminCredentialStatus.active => 'Ativa',
    SuperadminCredentialStatus.blocked => 'Bloqueada',
    SuperadminCredentialStatus.recoveryPending => 'Recuperação pendente',
  };
}

enum PlatformUserScope { platform, limited }

extension PlatformUserScopeLabel on PlatformUserScope {
  String get label => switch (this) {
    PlatformUserScope.platform => 'Global à plataforma',
    PlatformUserScope.limited => 'Limitado por escopo',
  };
}

enum PlatformUserDirectoryView { cards, table }

enum PlatformUserTableView { grouped }

extension PlatformUserTableViewLabel on PlatformUserTableView {
  String get label => 'Agrupado';
}

enum PlatformUserCapability { owner, auditor, unauthorized }

final class PlatformAccessProfile {
  const PlatformAccessProfile({
    required this.id,
    required this.name,
    required this.permissions,
    this.baseRole,
    this.allowsGlobal = false,
    this.active = true,
  });

  final String id;
  final String name;
  final List<String> permissions;
  final PlatformUserRole? baseRole;
  final bool allowsGlobal;
  final bool active;

  bool get isOwner => baseRole == PlatformUserRole.owner;
}

abstract final class PlatformAccessProfiles {
  static const values = <PlatformAccessProfile>[
    PlatformAccessProfile(
      id: 'owner',
      name: 'Owner',
      baseRole: PlatformUserRole.owner,
      allowsGlobal: true,
      permissions: [
        'platform.read',
        'platform.roles.manage',
        'platform.members.manage',
        'audit.read',
      ],
    ),
    PlatformAccessProfile(
      id: 'operations',
      name: 'Operations',
      baseRole: PlatformUserRole.operations,
      allowsGlobal: true,
      permissions: ['platform.read', 'institution.activate', 'institution.status.change'],
    ),
    PlatformAccessProfile(
      id: 'support',
      name: 'Support',
      baseRole: PlatformUserRole.support,
      permissions: ['platform.read', 'support.manage'],
    ),
    PlatformAccessProfile(
      id: 'content',
      name: 'Content',
      baseRole: PlatformUserRole.content,
      permissions: ['platform.read', 'notice.publish'],
    ),
    PlatformAccessProfile(
      id: 'auditor',
      name: 'Auditor',
      baseRole: PlatformUserRole.auditor,
      allowsGlobal: true,
      permissions: ['platform.read', 'audit.read'],
    ),
    PlatformAccessProfile(
      id: 'privacy-reviewer',
      name: 'Revisor de privacidade',
      permissions: ['platform.read', 'audit.read', 'privacy.review'],
    ),
  ];

  static PlatformAccessProfile byId(String id) => values.firstWhere((item) => item.id == id);
}

final class InternalUserIdentity {
  const InternalUserIdentity({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.cpf,
    required this.professionalEmail,
    required this.jobTitle,
    this.displayName = '',
    this.birthDate,
    this.mobile = '',
    this.additionalPhone = '',
    this.department = '',
    this.internalFunction = '',
    this.professionalNotes = '',
    this.postalCode = '',
    this.street = '',
    this.number = '',
    this.complement = '',
    this.neighborhood = '',
    this.city = '',
    this.state = '',
    this.country = 'Brasil',
    this.avatarBytes,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String displayName;
  final DateTime? birthDate;
  final String cpf;
  final String professionalEmail;
  final String mobile;
  final String additionalPhone;
  final String jobTitle;
  final String department;
  final String internalFunction;
  final String professionalNotes;
  final String postalCode;
  final String street;
  final String number;
  final String complement;
  final String neighborhood;
  final String city;
  final String state;
  final String country;
  final List<int>? avatarBytes;

  String get fullName => '$firstName $lastName'.trim();
  String get visibleName => displayName.trim().isEmpty ? fullName : displayName.trim();
  String get initials =>
      '${firstName.isEmpty ? '' : firstName[0]}${lastName.isEmpty ? '' : lastName[0]}';
  String get maskedEmail => maskPlatformUserEmail(professionalEmail);
  String get maskedCpf => maskPlatformUserCpf(cpf);
  String get maskedMobile => maskPlatformUserPhone(mobile);

  InternalUserIdentity copyWith({
    String? firstName,
    String? lastName,
    String? displayName,
    DateTime? birthDate,
    String? cpf,
    String? professionalEmail,
    String? mobile,
    String? additionalPhone,
    String? jobTitle,
    String? department,
    String? internalFunction,
    String? professionalNotes,
    String? postalCode,
    String? street,
    String? number,
    String? complement,
    String? neighborhood,
    String? city,
    String? state,
    String? country,
    List<int>? avatarBytes,
  }) => InternalUserIdentity(
    id: id,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    displayName: displayName ?? this.displayName,
    birthDate: birthDate ?? this.birthDate,
    cpf: cpf ?? this.cpf,
    professionalEmail: professionalEmail ?? this.professionalEmail,
    mobile: mobile ?? this.mobile,
    additionalPhone: additionalPhone ?? this.additionalPhone,
    jobTitle: jobTitle ?? this.jobTitle,
    department: department ?? this.department,
    internalFunction: internalFunction ?? this.internalFunction,
    professionalNotes: professionalNotes ?? this.professionalNotes,
    postalCode: postalCode ?? this.postalCode,
    street: street ?? this.street,
    number: number ?? this.number,
    complement: complement ?? this.complement,
    neighborhood: neighborhood ?? this.neighborhood,
    city: city ?? this.city,
    state: state ?? this.state,
    country: country ?? this.country,
    avatarBytes: avatarBytes ?? this.avatarBytes,
  );
}

final class SuperadminCredentialSnapshot {
  const SuperadminCredentialSnapshot({required this.status});
  final SuperadminCredentialStatus status;
}

final class InternalAccessMembership {
  const InternalAccessMembership({
    required this.id,
    required this.profile,
    required this.status,
    required this.scope,
    this.scopeIds = const [],
    this.scopeNames = const [],
    required this.startedAt,
    this.endedAt,
  });

  final String id;
  final PlatformAccessProfile profile;
  final PlatformMembershipStatus status;
  final PlatformUserScope scope;
  final List<String> scopeIds;
  final List<String> scopeNames;
  final DateTime startedAt;
  final DateTime? endedAt;

  String get scopeLabel => scope == PlatformUserScope.platform
      ? scope.label
      : scopeNames.isEmpty
      ? 'Escopo obrigatório'
      : scopeNames.join(', ');

  InternalAccessMembership copyWith({
    PlatformAccessProfile? profile,
    PlatformMembershipStatus? status,
    PlatformUserScope? scope,
    List<String>? scopeIds,
    List<String>? scopeNames,
    DateTime? endedAt,
  }) => InternalAccessMembership(
    id: id,
    profile: profile ?? this.profile,
    status: status ?? this.status,
    scope: scope ?? this.scope,
    scopeIds: scope == PlatformUserScope.platform ? const [] : scopeIds ?? this.scopeIds,
    scopeNames: scope == PlatformUserScope.platform ? const [] : scopeNames ?? this.scopeNames,
    startedAt: startedAt,
    endedAt: endedAt ?? this.endedAt,
  );
}

final class InternalInvitation {
  const InternalInvitation({
    required this.id,
    required this.email,
    required this.status,
    required this.attempts,
    required this.updatedAt,
  });
  final String id;
  final String email;
  final PlatformInvitationStatus status;
  final int attempts;
  final DateTime updatedAt;
}

final class InternalUserHistoryEvent {
  const InternalUserHistoryEvent({required this.at, required this.title, required this.detail});
  final DateTime at;
  final String title;
  final String detail;
}

final class PlatformUserRecord {
  const PlatformUserRecord({
    required this.identity,
    required this.credential,
    required this.memberships,
    required this.invitation,
    this.version = 1,
    this.history = const [],
  }) : assert(memberships.length > 0);

  final InternalUserIdentity identity;
  final SuperadminCredentialSnapshot credential;
  final List<InternalAccessMembership> memberships;
  final InternalInvitation invitation;
  final int version;
  final List<InternalUserHistoryEvent> history;

  String get id => identity.id;
  String get firstName => identity.firstName;
  String get lastName => identity.lastName;
  String get fullName => identity.fullName;
  String get initials => identity.initials;
  String get email => identity.professionalEmail;
  String get maskedEmail => identity.maskedEmail;
  String get maskedCpf => identity.maskedCpf;
  String get maskedMobile => identity.maskedMobile;
  InternalAccessMembership get membership => memberships.last;
  PlatformAccessProfile get profile => membership.profile;
  PlatformUserRole get role => profile.baseRole ?? PlatformUserRole.support;
  PlatformMembershipStatus get status => membership.status;
  PlatformUserScope get scope => membership.scope;
  String get scopeLabel => membership.scopeLabel;
  PlatformInvitationStatus get invitationStatus => invitation.status;
  SuperadminCredentialStatus get credentialStatus => credential.status;

  PlatformUserRecord copyWith({
    InternalUserIdentity? identity,
    SuperadminCredentialSnapshot? credential,
    List<InternalAccessMembership>? memberships,
    InternalInvitation? invitation,
    int? version,
    List<InternalUserHistoryEvent>? history,
  }) => PlatformUserRecord(
    identity: identity ?? this.identity,
    credential: credential ?? this.credential,
    memberships: memberships ?? this.memberships,
    invitation: invitation ?? this.invitation,
    version: version ?? this.version,
    history: history ?? this.history,
  );
}

final class PlatformUserDraft {
  const PlatformUserDraft({
    required this.identity,
    required this.profile,
    required this.scope,
    this.scopeIds = const [],
    this.scopeNames = const [],
  });
  final InternalUserIdentity identity;
  final PlatformAccessProfile profile;
  final PlatformUserScope scope;
  final List<String> scopeIds;
  final List<String> scopeNames;
}

final class PlatformUserQuery {
  const PlatformUserQuery({
    this.search = '',
    this.profileIds = const {},
    this.statuses = const {},
    this.scopes = const {},
    this.page = 1,
    this.view = PlatformUserDirectoryView.cards,
    int? pageSize,
  }) : pageSize = pageSize ?? (view == PlatformUserDirectoryView.cards ? 11 : 8);

  static const cardsPageSize = 11;
  static const tablePageSize = 8;

  final String search;
  final Set<String> profileIds;
  final Set<PlatformMembershipStatus> statuses;
  final Set<PlatformUserScope> scopes;
  final int page;
  final int pageSize;
  final PlatformUserDirectoryView view;
  int get offset => (page - 1) * pageSize;
}

final class PlatformUserPage {
  const PlatformUserPage({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });
  final List<PlatformUserRecord> items;
  final int totalCount;
  final int page;
  final int pageSize;
  int get pageCount => totalCount == 0 ? 1 : (totalCount / pageSize).ceil();
}

final class PlatformUserCreateResult {
  const PlatformUserCreateResult({required this.record, required this.message});
  final PlatformUserRecord record;
  final String message;
  bool get invitationSent => false;
}

abstract interface class PlatformUserRepository {
  bool get isDemo => false;
  List<PlatformAccessProfile> get profiles;
  List<PlatformUserRecord> get records;
  PlatformUserRecord? findById(String id);
  Future<PlatformUserPage> fetchPage(PlatformUserQuery query);
  Future<PlatformUserCreateResult> create(PlatformUserDraft draft);
  Future<PlatformUserRecord> update(String id, PlatformUserDraft draft);
  Future<PlatformUserRecord> resendInvitation(String id);
  Future<PlatformUserRecord> revokeInvitation(String id);
  Future<PlatformUserRecord> suspend(String id);
  Future<PlatformUserRecord> reactivate(String id);
  Future<PlatformUserRecord> revoke(String id);
  Future<PlatformUserRecord> createReplacementMembership(String id);
}

/// Optional production loader used by deep links before the directory cache exists.
abstract interface class PlatformUserRemoteLoader {
  Future<List<PlatformAccessProfile>> fetchProfiles();
  Future<PlatformUserRecord?> fetchById(String id);
}

final class PlatformUserConflictException implements Exception {
  const PlatformUserConflictException(this.field, this.message);
  final String field;
  final String message;
  @override
  String toString() => message;
}

final class PlatformUserRuleException implements Exception {
  const PlatformUserRuleException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

String normalizePlatformUserEmail(String value) => value.trim().toLowerCase();
String normalizePlatformUserDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

String maskPlatformUserEmail(String email) {
  final parts = email.split('@');
  if (parts.length != 2 || parts.first.isEmpty) return email;
  final visible = parts.first.substring(0, 1);
  return '$visible***@${parts.last}';
}

String maskPlatformUserCpf(String cpf) {
  final digits = normalizePlatformUserDigits(cpf);
  return digits.length == 11 ? '***.***.***-${digits.substring(9)}' : 'CPF protegido';
}

String maskPlatformUserPhone(String phone) {
  final digits = normalizePlatformUserDigits(phone);
  return digits.length >= 4 ? '(**) *****-${digits.substring(digits.length - 4)}' : 'Não informado';
}

bool isValidPlatformUserCpf(String value) {
  final digits = normalizePlatformUserDigits(value);
  if (digits.length != 11 || RegExp(r'^(\d)\1{10}$').hasMatch(digits)) return false;
  int digitAt(int index) => int.parse(digits[index]);
  int verifier(int length) {
    var sum = 0;
    for (var index = 0; index < length; index++) {
      sum += digitAt(index) * (length + 1 - index);
    }
    final remainder = (sum * 10) % 11;
    return remainder == 10 ? 0 : remainder;
  }

  return verifier(9) == digitAt(9) && verifier(10) == digitAt(10);
}
