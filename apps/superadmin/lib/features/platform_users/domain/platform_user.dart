enum PlatformUserRole { owner, operations, support, content, auditor }

extension PlatformUserRoleLabel on PlatformUserRole {
  String get label => switch (this) {
    PlatformUserRole.owner => 'Owner',
    PlatformUserRole.operations => 'Operations',
    PlatformUserRole.support => 'Support',
    PlatformUserRole.content => 'Content',
    PlatformUserRole.auditor => 'Auditor',
  };

  List<String> get permissions => switch (this) {
    PlatformUserRole.owner => const [
      'platform.read',
      'institution.activate',
      'institution.status.change',
      'plan.change',
      'platform.member.invite',
      'notice.publish',
      'support.manage',
      'audit.read',
    ],
    PlatformUserRole.operations => const [
      'platform.read',
      'institution.activate',
      'institution.status.change',
      'plan.change',
    ],
    PlatformUserRole.support => const ['platform.read', 'support.manage'],
    PlatformUserRole.content => const ['platform.read', 'notice.publish'],
    PlatformUserRole.auditor => const ['platform.read', 'audit.read'],
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

enum PlatformUserScope { platform, institution }

extension PlatformUserScopeLabel on PlatformUserScope {
  String get label => switch (this) {
    PlatformUserScope.platform => 'Plataforma',
    PlatformUserScope.institution => 'Instituição',
  };
}

enum PlatformUserDirectoryView { cards, table }

enum PlatformUserCapability { owner, auditor, unauthorized }

final class PlatformUserRecord {
  const PlatformUserRecord({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.status,
    required this.scope,
    required this.invitationStatus,
    this.institutionId,
    this.institutionName,
    this.lastReviewedAt,
  }) : assert(
         scope != PlatformUserScope.institution ||
             (institutionId != null && institutionName != null),
       );

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final PlatformUserRole role;
  final PlatformMembershipStatus status;
  final PlatformUserScope scope;
  final String? institutionId;
  final String? institutionName;
  final PlatformInvitationStatus invitationStatus;
  final DateTime? lastReviewedAt;

  String get fullName => '$firstName $lastName'.trim();
  String get initials =>
      '${firstName.isEmpty ? '' : firstName[0]}${lastName.isEmpty ? '' : lastName[0]}';
  String get maskedEmail => maskPlatformUserEmail(email);
  String get scopeLabel => institutionName ?? scope.label;

  PlatformUserRecord copyWith({
    String? firstName,
    String? lastName,
    PlatformUserRole? role,
    PlatformMembershipStatus? status,
    PlatformUserScope? scope,
    String? institutionId,
    String? institutionName,
    PlatformInvitationStatus? invitationStatus,
    DateTime? lastReviewedAt,
  }) {
    final nextScope = scope ?? this.scope;
    return PlatformUserRecord(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email,
      role: role ?? this.role,
      status: status ?? this.status,
      scope: nextScope,
      institutionId: nextScope == PlatformUserScope.platform
          ? null
          : institutionId ?? this.institutionId,
      institutionName: nextScope == PlatformUserScope.platform
          ? null
          : institutionName ?? this.institutionName,
      invitationStatus: invitationStatus ?? this.invitationStatus,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
    );
  }
}

final class PlatformUserDraft {
  PlatformUserDraft({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.scope,
    this.institutionId,
    this.institutionName,
  }) {
    if (scope == PlatformUserScope.institution &&
        (institutionId == null || institutionName == null)) {
      throw ArgumentError('Institution scope requires an institution.');
    }
  }

  final String firstName;
  final String lastName;
  final String email;
  final PlatformUserRole role;
  final PlatformUserScope scope;
  final String? institutionId;
  final String? institutionName;
}

final class PlatformUserQuery {
  const PlatformUserQuery({
    this.search = '',
    this.roles = const {},
    this.statuses = const {},
    this.page = 1,
    this.view = PlatformUserDirectoryView.cards,
    int? pageSize,
  }) : pageSize =
           pageSize ?? (view == PlatformUserDirectoryView.cards ? cardsPageSize : tablePageSize);

  static const cardsPageSize = 11;
  static const tablePageSize = 8;

  final String search;
  final Set<PlatformUserRole> roles;
  final Set<PlatformMembershipStatus> statuses;
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
  const PlatformUserCreateResult({
    required this.record,
    required this.invitationSent,
    required this.message,
  });

  final PlatformUserRecord record;
  final bool invitationSent;
  final String message;
}

abstract interface class PlatformUserRepository {
  List<PlatformUserRecord> get records;
  PlatformUserRecord? findById(String id);
  Future<PlatformUserPage> fetchPage(PlatformUserQuery query);
  Future<PlatformUserCreateResult> create(PlatformUserDraft draft);
  Future<void> update(PlatformUserRecord record);
}

String maskPlatformUserEmail(String email) {
  final parts = email.split('@');
  if (parts.length != 2 || parts.first.isEmpty) return email;
  final local = parts.first;
  return '${local[0]}${'*' * (local.length > 2 ? 2 : 1)}@${parts.last}';
}
