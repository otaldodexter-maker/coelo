import '../../../app/dev_menu/development_access_health_fixture_catalog.dart';
import '../../institutions/data/fake_institution_directory_repository.dart';
import '../domain/platform_user.dart';

final class FakePlatformUserRepository implements PlatformUserRepository {
  FakePlatformUserRepository({List<PlatformUserRecord>? seed})
    : _records = seed == null
          ? _seedRecords(DevelopmentAccessHealthFixtureCatalog.standard())
          : List.of(seed);

  factory FakePlatformUserRepository.content({DevelopmentAccessHealthFixtureCatalog? catalog}) =>
      FakePlatformUserRepository(
        seed: _seedRecords(catalog ?? DevelopmentAccessHealthFixtureCatalog.standard()),
      );

  final List<PlatformUserRecord> _records;

  @override
  List<PlatformAccessProfile> get profiles => PlatformAccessProfiles.values;
  @override
  List<PlatformUserRecord> get records => List.unmodifiable(_records);
  @override
  PlatformUserRecord? findById(String id) => _records.where((item) => item.id == id).firstOrNull;

  @override
  Future<PlatformUserPage> fetchPage(PlatformUserQuery query) async {
    final search = query.search.trim().toLowerCase();
    final filtered = _records.where((record) {
      final matchesSearch =
          search.isEmpty ||
          [
            record.fullName,
            record.firstName,
            record.lastName,
            record.email,
            record.maskedEmail,
            record.identity.cpf,
            record.maskedMobile,
            record.identity.mobile,
            record.maskedCpf,
            record.identity.jobTitle,
          ].any((value) => value.toLowerCase().contains(search));
      return matchesSearch &&
          (query.profileIds.isEmpty || query.profileIds.contains(record.profile.id)) &&
          (query.statuses.isEmpty || query.statuses.contains(record.status)) &&
          (query.scopes.isEmpty || query.scopes.contains(record.scope));
    }).toList()..sort((a, b) => a.fullName.compareTo(b.fullName));
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
    _validate(draft);
    _ensureUnique(draft.identity);
    final id = 'platform-user-${_records.length + 1}';
    final now = _now(_records.length);
    final identity = _normalizedIdentity(draft.identity, id);
    final record = PlatformUserRecord(
      identity: identity,
      credential: const SuperadminCredentialSnapshot(status: SuperadminCredentialStatus.noAccess),
      memberships: [_membership(id, draft, now)],
      invitation: _invitation(id, identity.professionalEmail, now),
      history: [_event(now, 'Acesso interno criado', 'Convite preparado.')],
    );
    _records.add(record);
    return PlatformUserCreateResult(record: record, message: 'Cadastro salvo.');
  }

  @override
  Future<PlatformUserRecord> update(String id, PlatformUserDraft draft) async {
    final current = _required(id);
    if (current.status == PlatformMembershipStatus.revoked) {
      throw const PlatformUserRuleException(
        'revoked',
        'Vínculo revogado é somente leitura. Crie um novo vínculo.',
      );
    }
    _validate(draft);
    _ensureUnique(draft.identity, excludingId: id);
    if (_lastOwner(current) &&
        (!draft.profile.isOwner || draft.scope != PlatformUserScope.platform)) {
      throw const PlatformUserRuleException(
        'last-owner',
        'O último Owner ativo deve permanecer Owner com acesso global.',
      );
    }
    final emailChanged =
        normalizePlatformUserEmail(current.email) !=
        normalizePlatformUserEmail(draft.identity.professionalEmail);
    if (emailChanged && current.credentialStatus == SuperadminCredentialStatus.active) {
      throw const PlatformUserRuleException(
        'credential-email',
        'O e-mail de uma credencial ativa exige fluxo produtivo verificado.',
      );
    }
    final now = _now(current.history.length + 30);
    final membership = current.membership.copyWith(
      profile: draft.profile,
      scope: draft.scope,
      scopeIds: draft.scopeIds,
      scopeNames: draft.scopeNames,
    );
    return _replace(
      current.copyWith(
        identity: _normalizedIdentity(draft.identity, id),
        memberships: [...current.memberships.take(current.memberships.length - 1), membership],
        invitation: emailChanged
            ? _invitation(id, draft.identity.professionalEmail, now)
            : current.invitation,
        history: [
          ...current.history,
          _event(
            now,
            'Cadastro atualizado',
            emailChanged
                ? 'Novo convite preparado para o e-mail atualizado.'
                : 'Dados, perfil ou escopo revisados localmente.',
          ),
        ],
      ),
    );
  }

  @override
  Future<PlatformUserRecord> resendInvitation(String id) async {
    final current = _required(id);
    if (!{
      PlatformInvitationStatus.pending,
      PlatformInvitationStatus.expired,
    }.contains(current.invitationStatus)) {
      throw const PlatformUserRuleException('invitation', 'Este convite não pode ser reenviado.');
    }
    final now = _now(current.history.length + 60);
    return _replace(
      current.copyWith(
        invitation: InternalInvitation(
          id: current.invitation.id,
          email: current.invitation.email,
          status: PlatformInvitationStatus.pending,
          attempts: current.invitation.attempts + 1,
          updatedAt: now,
        ),
        history: [
          ...current.history,
          _event(now, 'Convite reenviado', 'Solicitação de reenvio registrada.'),
        ],
      ),
    );
  }

  @override
  Future<PlatformUserRecord> revokeInvitation(String id) async {
    final current = _required(id);
    if (!{
      PlatformInvitationStatus.pending,
      PlatformInvitationStatus.expired,
    }.contains(current.invitationStatus)) {
      throw const PlatformUserRuleException(
        'invitation',
        'Somente convite pendente ou expirado pode ser revogado.',
      );
    }
    final now = _now(current.history.length + 70);
    return _replace(
      current.copyWith(
        invitation: InternalInvitation(
          id: current.invitation.id,
          email: current.invitation.email,
          status: PlatformInvitationStatus.revoked,
          attempts: current.invitation.attempts,
          updatedAt: now,
        ),
        history: [...current.history, _event(now, 'Convite revogado', 'Revogação registrada.')],
      ),
    );
  }

  @override
  Future<PlatformUserRecord> suspend(String id) async {
    final current = _required(id);
    _protectOwner(current);
    if (current.status != PlatformMembershipStatus.active) {
      throw const PlatformUserRuleException(
        'membership',
        'Somente vínculo ativo pode ser suspenso.',
      );
    }
    return _changeStatus(current, PlatformMembershipStatus.suspended, 'Acesso suspenso');
  }

  @override
  Future<PlatformUserRecord> reactivate(String id) async {
    final current = _required(id);
    if (current.status != PlatformMembershipStatus.suspended) {
      throw const PlatformUserRuleException(
        'membership',
        'Somente vínculo suspenso pode ser reativado.',
      );
    }
    return _changeStatus(current, PlatformMembershipStatus.active, 'Acesso reativado');
  }

  @override
  Future<PlatformUserRecord> revoke(String id) async {
    final current = _required(id);
    _protectOwner(current);
    if (current.status == PlatformMembershipStatus.revoked) {
      throw const PlatformUserRuleException('membership', 'Revogação é terminal.');
    }
    final next = await _changeStatus(current, PlatformMembershipStatus.revoked, 'Vínculo revogado');
    final invitation =
        {
          PlatformInvitationStatus.pending,
          PlatformInvitationStatus.expired,
        }.contains(next.invitationStatus)
        ? InternalInvitation(
            id: next.invitation.id,
            email: next.invitation.email,
            status: PlatformInvitationStatus.revoked,
            attempts: next.invitation.attempts,
            updatedAt: _now(next.history.length + 1),
          )
        : next.invitation;
    return _replace(
      next.copyWith(
        credential: const SuperadminCredentialSnapshot(status: SuperadminCredentialStatus.noAccess),
        invitation: invitation,
      ),
    );
  }

  @override
  Future<PlatformUserRecord> createReplacementMembership(String id) async {
    final current = _required(id);
    if (current.status != PlatformMembershipStatus.revoked) {
      throw const PlatformUserRuleException(
        'membership',
        'Novo vínculo só é criado após revogação.',
      );
    }
    final now = _now(current.history.length + 90);
    final draft = PlatformUserDraft(
      identity: current.identity,
      profile: current.profile,
      scope: current.scope,
      scopeIds: current.membership.scopeIds,
      scopeNames: current.membership.scopeNames,
    );
    return _replace(
      current.copyWith(
        memberships: [
          ...current.memberships,
          _membership(id, draft, now, sequence: current.memberships.length + 1),
        ],
        invitation: _invitation(id, current.email, now, sequence: current.memberships.length + 1),
        history: [
          ...current.history,
          _event(
            now,
            'Novo vínculo criado',
            'O ciclo revogado foi preservado e um novo convite foi preparado.',
          ),
        ],
      ),
    );
  }

  Future<PlatformUserRecord> _changeStatus(
    PlatformUserRecord current,
    PlatformMembershipStatus status,
    String title,
  ) async {
    final now = _now(current.history.length + 80);
    final membership = current.membership.copyWith(
      status: status,
      endedAt: status == PlatformMembershipStatus.revoked ? now : null,
    );
    return _replace(
      current.copyWith(
        memberships: [...current.memberships.take(current.memberships.length - 1), membership],
        history: [...current.history, _event(now, title, 'Alteração registrada.')],
      ),
    );
  }

  void _validate(PlatformUserDraft draft) {
    final identity = draft.identity;
    if (identity.firstName.trim().isEmpty ||
        identity.lastName.trim().isEmpty ||
        identity.jobTitle.trim().isEmpty) {
      throw const PlatformUserRuleException(
        'required',
        'Nome, sobrenome e cargo são obrigatórios.',
      );
    }
    if (!isValidPlatformUserCpf(identity.cpf)) {
      throw const PlatformUserRuleException('cpf', 'Informe um CPF válido.');
    }
    if (!RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(normalizePlatformUserEmail(identity.professionalEmail))) {
      throw const PlatformUserRuleException('email', 'Informe um e-mail profissional válido.');
    }
    if (draft.scope == PlatformUserScope.platform && !draft.profile.allowsGlobal) {
      throw PlatformUserRuleException(
        'scope-profile',
        'O perfil ${draft.profile.name} não autoriza acesso global.',
      );
    }
    if (draft.scope == PlatformUserScope.limited && draft.scopeIds.isEmpty) {
      throw const PlatformUserRuleException(
        'scope-required',
        'Selecione ao menos um escopo permitido.',
      );
    }
    if (identity.birthDate?.isAfter(DateTime(2026, 8, 5)) ?? false) {
      throw const PlatformUserRuleException(
        'birth-date',
        'A data de nascimento não pode ser futura.',
      );
    }
    final addressStarted = [
      identity.postalCode,
      identity.street,
      identity.number,
      identity.complement,
      identity.neighborhood,
      identity.city,
      identity.state,
    ].any((value) => value.trim().isNotEmpty);
    if (addressStarted &&
        [
          identity.postalCode,
          identity.street,
          identity.number,
          identity.neighborhood,
          identity.city,
          identity.state,
          identity.country,
        ].any((value) => value.trim().isEmpty)) {
      throw const PlatformUserRuleException(
        'address-required',
        'Complete CEP, logradouro, número, bairro, cidade, estado e país.',
      );
    }
  }

  void _ensureUnique(InternalUserIdentity identity, {String? excludingId}) {
    for (final record in _records.where((item) => item.id != excludingId)) {
      if (normalizePlatformUserDigits(record.identity.cpf) ==
          normalizePlatformUserDigits(identity.cpf)) {
        throw const PlatformUserConflictException(
          'cpf',
          'Já existe um Usuário Interno com este CPF.',
        );
      }
      if (normalizePlatformUserEmail(record.email) ==
          normalizePlatformUserEmail(identity.professionalEmail)) {
        throw const PlatformUserConflictException(
          'email',
          'Já existe um Usuário Interno com este e-mail.',
        );
      }
    }
  }

  void _protectOwner(PlatformUserRecord record) {
    if (_lastOwner(record)) {
      throw const PlatformUserRuleException(
        'last-owner',
        'O último Owner ativo e global não pode perder acesso.',
      );
    }
  }

  bool _lastOwner(PlatformUserRecord record) =>
      record.profile.isOwner &&
      record.status == PlatformMembershipStatus.active &&
      record.scope == PlatformUserScope.platform &&
      _records
              .where(
                (item) =>
                    item.profile.isOwner &&
                    item.status == PlatformMembershipStatus.active &&
                    item.scope == PlatformUserScope.platform,
              )
              .length ==
          1;

  PlatformUserRecord _required(String id) => findById(id) ?? (throw ArgumentError.value(id, 'id'));
  PlatformUserRecord _replace(PlatformUserRecord record) {
    _records[_records.indexWhere((item) => item.id == record.id)] = record;
    return record;
  }

  static DateTime _now(int minute) => DateTime(2026, 8, 5, 12, minute % 60);
  static InternalUserHistoryEvent _event(DateTime at, String title, String detail) =>
      InternalUserHistoryEvent(at: at, title: title, detail: detail);
  static InternalAccessMembership _membership(
    String id,
    PlatformUserDraft draft,
    DateTime at, {
    int sequence = 1,
  }) => InternalAccessMembership(
    id: 'membership-$id-$sequence',
    profile: draft.profile,
    status: PlatformMembershipStatus.invited,
    scope: draft.scope,
    scopeIds: List.unmodifiable(draft.scopeIds),
    scopeNames: List.unmodifiable(draft.scopeNames),
    startedAt: at,
  );
  static InternalInvitation _invitation(String id, String email, DateTime at, {int sequence = 1}) =>
      InternalInvitation(
        id: 'invitation-$id-$sequence',
        email: normalizePlatformUserEmail(email),
        status: PlatformInvitationStatus.pending,
        attempts: 1,
        updatedAt: at,
      );

  static InternalUserIdentity _normalizedIdentity(InternalUserIdentity value, String id) =>
      InternalUserIdentity(
        id: id,
        firstName: value.firstName.trim(),
        lastName: value.lastName.trim(),
        displayName: value.displayName.trim(),
        birthDate: value.birthDate,
        cpf: normalizePlatformUserDigits(value.cpf),
        professionalEmail: normalizePlatformUserEmail(value.professionalEmail),
        mobile: value.mobile.trim(),
        additionalPhone: value.additionalPhone.trim(),
        jobTitle: value.jobTitle.trim(),
        department: value.department.trim(),
        internalFunction: value.internalFunction.trim(),
        professionalNotes: value.professionalNotes.trim(),
        postalCode: value.postalCode.trim(),
        street: value.street.trim(),
        number: value.number.trim(),
        complement: value.complement.trim(),
        neighborhood: value.neighborhood.trim(),
        city: value.city.trim(),
        state: value.state.trim(),
        country: value.country.trim().isEmpty ? 'Brasil' : value.country.trim(),
        avatarBytes: value.avatarBytes,
      );

  static List<PlatformUserRecord> _seedRecords(DevelopmentAccessHealthFixtureCatalog catalog) {
    final institutions = {
      for (final institution in demoInstitutionRecords) institution.id: institution,
    };
    return List.generate(catalog.teamMembers.length, (index) {
      final adult = catalog.teamMembers[index];
      final id = adult.id;
      final institution = institutions[adult.institutionIds.first]!;
      final unit = institution.units[index % institution.units.length];
      final profile = PlatformAccessProfiles.values[index == 0 ? 0 : 1 + index % 5];
      final status = index == 0
          ? PlatformMembershipStatus.active
          : index % 17 == 3
          ? PlatformMembershipStatus.revoked
          : index % 13 == 2
          ? PlatformMembershipStatus.suspended
          : index % 10 == 1
          ? PlatformMembershipStatus.invited
          : PlatformMembershipStatus.active;
      final scope = index == 0 ? PlatformUserScope.platform : PlatformUserScope.limited;
      final at = DateTime(2026, 7, 1 + index % 20);
      final name = adult.name.trim().split(RegExp(r'\s+'));
      final identity = InternalUserIdentity(
        id: id,
        firstName: name.first,
        lastName: name.skip(1).join(' '),
        cpf: _cpfFor(index + 1),
        professionalEmail: adult.email,
        mobile: adult.mobilePhone,
        jobTitle: const [
          'Coordenador pedagógico',
          'Especialista de atendimento',
          'Analista de operações',
          'Assistente institucional',
        ][index % 4],
        department: const ['Pedagógico', 'Atendimento', 'Operações', 'Cuidado'][index % 4],
        internalFunction: unit.name,
        professionalNotes: 'Atuação vinculada a ${institution.publicName}, ${unit.name}.',
        postalCode: institution.postalCode.isEmpty ? '00000-000' : institution.postalCode,
        street: institution.street.isEmpty ? 'Endereço institucional' : institution.street,
        number: institution.addressNumber.isEmpty ? 'S/N' : institution.addressNumber,
        complement: institution.complement,
        neighborhood: institution.district.isEmpty ? 'Centro' : institution.district,
        city: institution.city,
        state: institution.state,
        country: institution.country,
      );
      final invitationStatus = status == PlatformMembershipStatus.invited
          ? (index ~/ 4).isEven
                ? PlatformInvitationStatus.pending
                : PlatformInvitationStatus.expired
          : status == PlatformMembershipStatus.revoked
          ? PlatformInvitationStatus.revoked
          : PlatformInvitationStatus.accepted;
      return PlatformUserRecord(
        identity: identity,
        credential: SuperadminCredentialSnapshot(
          status: status == PlatformMembershipStatus.active
              ? SuperadminCredentialStatus.active
              : status == PlatformMembershipStatus.suspended
              ? index % 8 == 2
                    ? SuperadminCredentialStatus.blocked
                    : SuperadminCredentialStatus.recoveryPending
              : SuperadminCredentialStatus.noAccess,
        ),
        memberships: [
          InternalAccessMembership(
            id: 'membership-$id-1',
            profile: profile,
            status: status,
            scope: scope,
            scopeIds: scope == PlatformUserScope.limited ? adult.institutionIds : const [],
            scopeNames: scope == PlatformUserScope.limited ? [institution.publicName] : const [],
            startedAt: at,
            endedAt: status == PlatformMembershipStatus.revoked
                ? at.add(const Duration(days: 30))
                : null,
          ),
        ],
        invitation: InternalInvitation(
          id: 'invitation-$id-1',
          email: identity.professionalEmail,
          status: invitationStatus,
          attempts: 1,
          updatedAt: at,
        ),
        history: [_event(at, 'Registro criado', 'Identidade exclusiva do Superadmin.')],
      );
    });
  }

  static String _cpfFor(int seed) {
    var digits = (100000000 + seed * 7919).toString().substring(0, 9);
    for (var length = 9; length <= 10; length++) {
      var sum = 0;
      for (var index = 0; index < length; index++) {
        sum += int.parse(digits[index]) * (length + 1 - index);
      }
      final value = (sum * 10) % 11;
      digits += (value == 10 ? 0 : value).toString();
    }
    return digits;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
