/// Productive invitation contracts.
///
/// The client only submits intent. Every scope, profile, transition and
/// capability must be recalculated by the authorised server RPC.
library;

enum InviteStatus {
  pending('pending', 'Pendente'),
  accepted('accepted', 'Aceito'),
  expired('expired', 'Expirado'),
  revoked('revoked', 'Revogado');

  const InviteStatus(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static InviteStatus fromDatabase(String value) => switch (value) {
    'pending' => pending,
    'accepted' => accepted,
    'expired' => expired,
    'revoked' => revoked,
    _ => throw FormatException('Unsupported invitation status.'),
  };
}

enum InviteDeliveryStatus {
  notRequested('not_requested'),
  queued('queued'),
  sent('sent'),
  failed('failed');

  const InviteDeliveryStatus(this.databaseValue);

  final String databaseValue;

  static InviteDeliveryStatus fromDatabase(String value) => switch (value) {
    'not_requested' => notRequested,
    'queued' => queued,
    'sent' => sent,
    'failed' => failed,
    _ => throw FormatException('Unsupported invitation delivery status.'),
  };
}

enum InviteChannel {
  email('email', 'E-mail'),
  link('link', 'Link copiável');

  const InviteChannel(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static InviteChannel fromDatabase(String value) => switch (value) {
    'email' => email,
    'link' => link,
    _ => throw FormatException('Unsupported invitation channel.'),
  };
}

enum InviteScopeKind {
  institution('institution', 'Instituição'),
  unit('unit', 'Unidade'),
  group('group', 'Turma');

  const InviteScopeKind(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static InviteScopeKind fromDatabase(String value) => switch (value) {
    'institution' => institution,
    'unit' => unit,
    'group' => group,
    _ => throw FormatException('Unsupported invitation scope.'),
  };
}

final class InviteScope {
  const InviteScope({
    required this.kind,
    required this.institutionId,
    required this.label,
    this.unitId,
    this.groupId,
  }) : assert(institutionId != ''),
       assert(label != ''),
       assert(
         (kind == InviteScopeKind.institution && unitId == null && groupId == null) ||
             (kind == InviteScopeKind.unit && unitId != null && unitId != '' && groupId == null) ||
             (kind == InviteScopeKind.group &&
                 unitId != null &&
                 unitId != '' &&
                 groupId != null &&
                 groupId != ''),
       );

  final InviteScopeKind kind;
  final String institutionId;
  final String? unitId;
  final String? groupId;
  final String label;

  String get id => switch (kind) {
    InviteScopeKind.institution => institutionId,
    InviteScopeKind.unit => unitId!,
    InviteScopeKind.group => groupId!,
  };
}

final class InviteProfileReference {
  const InviteProfileReference({required this.id, required this.label})
    : assert(id != ''),
      assert(label != '');

  final String id;
  final String label;
}

final class InviteRecipient {
  const InviteRecipient({this.personId, this.label, this.maskedEmail});

  final String? personId;
  final String? label;
  final String? maskedEmail;
}

final class InviteIssuer {
  const InviteIssuer({required this.personId, required this.label})
    : assert(personId != ''),
      assert(label != '');

  final String personId;
  final String label;
}

final class InviteTimelineEntry {
  const InviteTimelineEntry(this.label, this.occurredAt);

  final String label;
  final DateTime occurredAt;
}

final class PlatformInvite {
  const PlatformInvite({
    required this.id,
    required this.scope,
    required this.profile,
    required this.recipient,
    required this.channels,
    required this.status,
    required this.issuer,
    required this.createdAt,
    required this.expiresAt,
    required this.emailDeliveryStatus,
    required this.managementVersion,
    this.acceptedAt,
    this.revokedAt,
    this.timeline = const [],
  });

  final String id;
  final InviteScope scope;
  final InviteProfileReference profile;
  final InviteRecipient recipient;
  final Set<InviteChannel> channels;
  final InviteStatus status;
  final InviteIssuer issuer;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? acceptedAt;
  final DateTime? revokedAt;
  final InviteDeliveryStatus emailDeliveryStatus;
  final int managementVersion;
  final List<InviteTimelineEntry> timeline;

  String get recipientMasked => recipient.maskedEmail ?? recipient.label ?? 'Destinatário';
  bool get canResend => canResendAt(DateTime.now().toUtc());

  bool canResendAt(DateTime now) =>
      status == InviteStatus.expired ||
      (status == InviteStatus.pending && !expiresAt.isAfter(now.toUtc()));
  bool get canRevoke => status == InviteStatus.pending;
}

final class InviteDirectoryQuery {
  static const cardPageSizes = <int>[11, 20, 50, 100];
  static const tablePageSizes = <int>[8, 20, 50, 100];
  static const allowedPageSizes = <int>[8, 11, 20, 50, 100];

  InviteDirectoryQuery({
    this.search = '',
    Set<InviteStatus> statuses = const {},
    Set<InviteChannel> channels = const {},
    Set<String> institutionIds = const {},
    Set<String> unitIds = const {},
    Set<String> groupIds = const {},
    Set<String> profileIds = const {},
    this.createdFrom,
    this.createdTo,
    this.page = 1,
    this.pageSize = 8,
    this.sortAscending = false,
  }) : assert(page >= 1),
       assert(allowedPageSizes.contains(pageSize)),
       statuses = Set.unmodifiable(statuses),
       channels = Set.unmodifiable(channels),
       institutionIds = Set.unmodifiable(institutionIds),
       unitIds = Set.unmodifiable(unitIds),
       groupIds = Set.unmodifiable(groupIds),
       profileIds = Set.unmodifiable(profileIds);

  final String search;
  final Set<InviteStatus> statuses;
  final Set<InviteChannel> channels;
  final Set<String> institutionIds;
  final Set<String> unitIds;
  final Set<String> groupIds;
  final Set<String> profileIds;
  final DateTime? createdFrom;
  final DateTime? createdTo;
  final int page;
  final int pageSize;
  final bool sortAscending;

  int get offset => (page - 1) * pageSize;
  bool get hasActiveFilters =>
      search.trim().isNotEmpty ||
      statuses.isNotEmpty ||
      channels.isNotEmpty ||
      institutionIds.isNotEmpty ||
      unitIds.isNotEmpty ||
      groupIds.isNotEmpty ||
      profileIds.isNotEmpty ||
      createdFrom != null ||
      createdTo != null;
}

final class InviteDirectoryResult {
  const InviteDirectoryResult({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  final List<PlatformInvite> items;
  final int totalCount;
  final int page;
  final int pageSize;

  int get totalPages => totalCount == 0 ? 1 : (totalCount + pageSize - 1) ~/ pageSize;
}

enum InviteDirectoryLoadState { loading, ready, empty, noResults, failure, unauthorized }

final class InviteDirectorySnapshot {
  const InviteDirectorySnapshot._(this.state, {this.page, this.error});

  const InviteDirectorySnapshot.loading() : this._(InviteDirectoryLoadState.loading);
  const InviteDirectorySnapshot.failure(Object error)
    : this._(InviteDirectoryLoadState.failure, error: error);
  const InviteDirectorySnapshot.unauthorized(Object error)
    : this._(InviteDirectoryLoadState.unauthorized, error: error);

  factory InviteDirectorySnapshot.loaded(InviteDirectoryResult page, {required String search}) {
    if (page.items.isNotEmpty) {
      return InviteDirectorySnapshot._(InviteDirectoryLoadState.ready, page: page);
    }
    return InviteDirectorySnapshot._(
      search.trim().isEmpty ? InviteDirectoryLoadState.empty : InviteDirectoryLoadState.noResults,
      page: page,
    );
  }

  final InviteDirectoryLoadState state;
  final InviteDirectoryResult? page;
  final Object? error;
}

final class InviteOptionsQuery {
  const InviteOptionsQuery({
    this.search = '',
    this.institutionId,
    this.unitId,
    this.groupId,
    this.pageSize = 25,
  }) : assert(pageSize > 0 && pageSize <= 100);

  final String search;
  final String? institutionId;
  final String? unitId;
  final String? groupId;
  final int pageSize;
}

final class InviteScopeOption {
  const InviteScopeOption({required this.scope});

  final InviteScope scope;
  InviteScopeKind get kind => scope.kind;
  String get id => scope.id;
  String get label => scope.label;
}

final class InviteProfileOption {
  const InviteProfileOption({
    required this.id,
    required this.label,
    required this.institutionId,
    this.unitId,
    this.groupId,
  });

  final String id;
  final String label;
  final String institutionId;
  final String? unitId;
  final String? groupId;
}

final class InviteRecipientOption {
  const InviteRecipientOption({required this.personId, required this.label, this.maskedEmail});

  final String personId;
  final String label;
  final String? maskedEmail;
}

final class InviteFormOptions {
  const InviteFormOptions({required this.scopes, required this.profiles, required this.recipients});

  final List<InviteScopeOption> scopes;
  final List<InviteProfileOption> profiles;
  final List<InviteRecipientOption> recipients;
}

final class InviteRecipientDraft {
  const InviteRecipientDraft({this.personId, this.email})
    : assert(
        (personId != null && personId != '') != (email != null && email != ''),
        'Exactly one recipient target is required.',
      );

  final String? personId;
  final String? email;
}

final class InviteIssueCommand {
  InviteIssueCommand({
    required this.requestId,
    required this.scope,
    required this.profileId,
    required this.recipient,
    required Set<InviteChannel> channels,
    this.expiresInHours = 48,
  }) : assert(requestId != ''),
       assert(profileId != ''),
       assert(channels.isNotEmpty),
       assert(expiresInHours > 0 && expiresInHours <= 168),
       channels = Set.unmodifiable(channels);

  final String requestId;
  final InviteScope scope;
  final String profileId;
  final InviteRecipientDraft recipient;
  final Set<InviteChannel> channels;
  final int expiresInHours;
}

final class InviteResendCommand {
  const InviteResendCommand({
    required this.inviteId,
    required this.requestId,
    required this.expectedVersion,
  }) : assert(inviteId != ''),
       assert(requestId != ''),
       assert(expectedVersion >= 0);

  final String inviteId;
  final String requestId;
  final int expectedVersion;
}

final class InviteRevokeCommand {
  const InviteRevokeCommand({
    required this.inviteId,
    required this.requestId,
    required this.expectedVersion,
    required this.reason,
  }) : assert(inviteId != ''),
       assert(requestId != ''),
       assert(expectedVersion >= 0),
       assert(reason != '');

  final String inviteId;
  final String requestId;
  final int expectedVersion;
  final String reason;
}

final class InviteCommandResult {
  const InviteCommandResult({required this.invite, required this.replayed, this.link});

  final PlatformInvite invite;
  final bool replayed;

  /// Returned only by the issue/resend receipt. It is never reconstructed from
  /// an invitation id and must not be persisted by the Flutter client.
  final Uri? link;
}

abstract interface class InviteRepository {
  Future<InviteDirectoryResult> fetchPage(InviteDirectoryQuery query);
  Future<InviteFormOptions> fetchOptions(InviteOptionsQuery query);
  Future<PlatformInvite?> fetchById(String inviteId);
  Future<InviteCommandResult> issue(InviteIssueCommand command);
  Future<InviteCommandResult> resend(InviteResendCommand command);
  Future<InviteCommandResult> revoke(InviteRevokeCommand command);
}

final class InviteUnauthorizedException implements Exception {
  const InviteUnauthorizedException();
}

final class InviteNotFoundException implements Exception {
  const InviteNotFoundException();
}

final class InviteValidationException implements Exception {
  const InviteValidationException();
}

final class InviteConflictException implements Exception {
  const InviteConflictException();
}

final class InviteUnavailableException implements Exception {
  const InviteUnavailableException();
}

final class UnavailableInviteRepository implements InviteRepository {
  const UnavailableInviteRepository();

  @override
  Future<PlatformInvite?> fetchById(String inviteId) => _unavailable();

  @override
  Future<InviteFormOptions> fetchOptions(InviteOptionsQuery query) => _unavailable();

  @override
  Future<InviteDirectoryResult> fetchPage(InviteDirectoryQuery query) => _unavailable();

  @override
  Future<InviteCommandResult> issue(InviteIssueCommand command) => _unavailable();

  @override
  Future<InviteCommandResult> resend(InviteResendCommand command) => _unavailable();

  @override
  Future<InviteCommandResult> revoke(InviteRevokeCommand command) => _unavailable();
}

Future<T> _unavailable<T>() async => throw const InviteUnavailableException();

String maskInviteRecipient(String recipient, InviteChannel channel) {
  if (channel == InviteChannel.link) return channel.label;
  final separator = recipient.indexOf('@');
  if (separator <= 0 || separator == recipient.length - 1) return 'E-mail protegido';
  return '${recipient.substring(0, 1)}***${recipient.substring(separator)}';
}
