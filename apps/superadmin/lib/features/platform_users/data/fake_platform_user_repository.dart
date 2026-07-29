import '../domain/platform_user.dart';

final class FakePlatformUserRepository implements PlatformUserRepository {
  FakePlatformUserRepository()
    : _records = List.generate(24, (index) {
        final role = PlatformUserRole.values[index % PlatformUserRole.values.length];
        final status =
            PlatformMembershipStatus.values[index % PlatformMembershipStatus.values.length];
        final institutionScoped = index % 4 == 1;
        return PlatformUserRecord(
          id: 'platform-user-${index + 1}',
          firstName: const ['Ana', 'Bruno', 'Clara', 'Diego', 'Elisa', 'Fábio'][index % 6],
          lastName: const ['Lima', 'Coelho', 'Rocha', 'Melo'][index % 4],
          email: 'equipe${index + 1}@coelo.me',
          role: role,
          status: status,
          scope: institutionScoped ? PlatformUserScope.institution : PlatformUserScope.platform,
          institutionId: institutionScoped ? 'institution-${(index % 3) + 1}' : null,
          institutionName: institutionScoped ? 'Instituição ${(index % 3) + 1}' : null,
          invitationStatus: switch (status) {
            PlatformMembershipStatus.invited => PlatformInvitationStatus.pending,
            PlatformMembershipStatus.active => PlatformInvitationStatus.accepted,
            PlatformMembershipStatus.suspended => PlatformInvitationStatus.accepted,
            PlatformMembershipStatus.revoked => PlatformInvitationStatus.revoked,
          },
          lastReviewedAt: index % 3 == 0 ? null : DateTime(2026, 7, 1 + (index % 20)),
        );
      });

  final List<PlatformUserRecord> _records;

  @override
  List<PlatformUserRecord> get records => List.unmodifiable(_records);

  @override
  PlatformUserRecord? findById(String id) {
    for (final record in _records) {
      if (record.id == id) return record;
    }
    return null;
  }

  @override
  Future<PlatformUserPage> fetchPage(PlatformUserQuery query) async {
    final search = query.search.trim().toLowerCase();
    final filtered = _records.where((record) {
      final matchesIdentity =
          search.isEmpty ||
          record.fullName.toLowerCase().contains(search) ||
          record.maskedEmail.toLowerCase().contains(search);
      return matchesIdentity &&
          (query.roles.isEmpty || query.roles.contains(record.role)) &&
          (query.statuses.isEmpty || query.statuses.contains(record.status));
    }).toList()..sort((first, second) => first.fullName.compareTo(second.fullName));
    final start = query.offset.clamp(0, filtered.length);
    final end = (start + query.pageSize).clamp(start, filtered.length);
    return PlatformUserPage(
      items: List.unmodifiable(filtered.sublist(start, end)),
      totalCount: filtered.length,
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  @override
  Future<PlatformUserCreateResult> create(PlatformUserDraft draft) async {
    final record = PlatformUserRecord(
      id: 'platform-user-${_records.length + 1}',
      firstName: draft.firstName.trim(),
      lastName: draft.lastName.trim(),
      email: draft.email.trim(),
      role: draft.role,
      status: PlatformMembershipStatus.invited,
      scope: draft.scope,
      institutionId: draft.institutionId,
      institutionName: draft.institutionName,
      invitationStatus: PlatformInvitationStatus.pending,
    );
    _records.add(record);
    return PlatformUserCreateResult(
      record: record,
      invitationSent: false,
      message: 'Preview salvo localmente; nenhum convite real foi enviado.',
    );
  }

  @override
  Future<void> update(PlatformUserRecord record) async {
    final index = _records.indexWhere((candidate) => candidate.id == record.id);
    if (index == -1) throw ArgumentError.value(record.id, 'record.id');
    if (_records[index].email != record.email) {
      throw ArgumentError('O e-mail da identidade não pode ser alterado neste preview.');
    }
    _records[index] = record;
  }
}
