import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/platform_user.dart';

/// Production repository for already-provisioned Superadmin internal identities.
///
/// Auth invitation and recovery deliberately remain outside this repository
/// until OQ-039 defines their privileged gateway contract.
final class SupabasePlatformUserRepository
    implements PlatformUserRepository, PlatformUserRemoteLoader {
  SupabasePlatformUserRepository(this._client);

  final SupabaseClient _client;
  final Map<String, PlatformUserRecord> _records = {};
  List<PlatformAccessProfile> _profiles = const [];

  @override
  bool get isDemo => false;

  @override
  List<PlatformAccessProfile> get profiles => List.unmodifiable(_profiles);

  @override
  List<PlatformUserRecord> get records => List.unmodifiable(_records.values);

  @override
  PlatformUserRecord? findById(String id) => _records[id];

  @override
  Future<List<PlatformAccessProfile>> fetchProfiles() async {
    try {
      final response = await _client.rpc<Map<String, dynamic>>('superadmin_internal_user_profiles');
      final payload = _payload(response);
      final rows = payload['items'] as List<dynamic>? ?? const [];
      _profiles = rows
          .map((row) => _profile(Map<String, dynamic>.from(row as Map)))
          .where((profile) => profile.active)
          .toList(growable: false);
      return profiles;
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<PlatformUserPage> fetchPage(PlatformUserQuery query) async {
    try {
      if (_profiles.isEmpty) await fetchProfiles();
      final response = await _client.rpc<Map<String, dynamic>>(
        'superadmin_internal_users_list',
        params: {
          'p_search': query.search.trim().isEmpty ? null : query.search.trim(),
          'p_profile_ids': query.profileIds.isEmpty ? null : query.profileIds.toList(),
          'p_statuses': query.statuses.isEmpty
              ? null
              : query.statuses.map((status) => status.name).toList(),
          'p_scopes': query.scopes.isEmpty
              ? null
              : query.scopes.map((scope) => scope.name).toList(),
          'p_page': query.page,
          'p_page_size': query.pageSize,
        },
      );
      final payload = _payload(response);
      final items = (payload['items'] as List<dynamic>? ?? const [])
          .map((row) => _record(Map<String, dynamic>.from(row as Map)))
          .toList(growable: false);
      for (final item in items) {
        _records[item.id] = item;
      }
      return PlatformUserPage(
        items: items,
        totalCount: (payload['total'] as num?)?.toInt() ?? 0,
        page: (payload['page'] as num?)?.toInt() ?? query.page,
        pageSize: (payload['page_size'] as num?)?.toInt() ?? query.pageSize,
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<PlatformUserRecord?> fetchById(String id) async {
    try {
      if (_profiles.isEmpty) await fetchProfiles();
      final response = await _client.rpc<Map<String, dynamic>>(
        'superadmin_internal_user_detail',
        params: {'p_internal_identity_id': id},
      );
      final record = _record(_payload(response));
      _records[record.id] = record;
      return record;
    } on PostgrestException catch (error) {
      if (error.code == 'P0002') return null;
      throw _mapError(error);
    }
  }

  @override
  Future<PlatformUserCreateResult> create(PlatformUserDraft draft) =>
      throw const PlatformUserRuleException(
        'invitation-contract',
        'Convites produtivos aguardam o contrato privilegiado de Auth.',
      );

  @override
  Future<PlatformUserRecord> update(String id, PlatformUserDraft draft) async {
    final current = await _required(id);
    return _command('superadmin_internal_user_update', {
      'p_request_id': _requestId(),
      'p_internal_identity_id': id,
      'p_expected_version': current.version,
      'p_reason': 'Cadastro interno revisado no Superadmin.',
      'p_draft': {
        'identity': _identityDraft(draft.identity),
        'profile_id': draft.profile.id,
        'scope': draft.scope.name,
        'scope_ids': draft.scopeIds,
      },
    });
  }

  @override
  Future<PlatformUserRecord> suspend(String id) => _changeStatus(id, 'suspended');

  @override
  Future<PlatformUserRecord> reactivate(String id) => _changeStatus(id, 'active');

  @override
  Future<PlatformUserRecord> revoke(String id) => _changeStatus(id, 'revoked');

  @override
  Future<PlatformUserRecord> resendInvitation(String id) => throw const PlatformUserRuleException(
    'invitation-contract',
    'O reenvio produtivo aguarda o contrato privilegiado de Auth.',
  );

  @override
  Future<PlatformUserRecord> revokeInvitation(String id) => throw const PlatformUserRuleException(
    'invitation-contract',
    'A revogação do convite aguarda o contrato privilegiado de Auth.',
  );

  @override
  Future<PlatformUserRecord> createReplacementMembership(String id) =>
      throw const PlatformUserRuleException(
        'invitation-contract',
        'Um novo vínculo produtivo exige novo convite pelo gateway de Auth.',
      );

  Future<PlatformUserRecord> _changeStatus(String id, String status) async {
    final current = await _required(id);
    return _command('superadmin_internal_user_change_status', {
      'p_request_id': _requestId(),
      'p_internal_identity_id': id,
      'p_expected_version': current.version,
      'p_status': status,
      'p_reason': switch (status) {
        'suspended' => 'Acesso interno suspenso no Superadmin.',
        'active' => 'Acesso interno reativado no Superadmin.',
        _ => 'Vínculo interno revogado no Superadmin.',
      },
    });
  }

  Future<PlatformUserRecord> _command(String function, Map<String, dynamic> params) async {
    try {
      final response = await _client.rpc<Map<String, dynamic>>(function, params: params);
      final record = _record(_payload(response));
      _records[record.id] = record;
      return record;
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  Future<PlatformUserRecord> _required(String id) async {
    final record = _records[id] ?? await fetchById(id);
    if (record == null) {
      throw const PlatformUserRuleException('not-found', 'Usuário interno não encontrado.');
    }
    return record;
  }

  PlatformUserRecord _record(Map<String, dynamic> json) {
    final identityJson = Map<String, dynamic>.from(json['identity'] as Map);
    final credentialJson = Map<String, dynamic>.from(json['credential'] as Map);
    final membershipRows = json['memberships'] as List<dynamic>? ?? const [];
    final invitationJson = Map<String, dynamic>.from(json['invitation'] as Map);
    final historyRows = json['history'] as List<dynamic>? ?? const [];
    return PlatformUserRecord(
      identity: InternalUserIdentity(
        id: identityJson['id'] as String,
        firstName: identityJson['first_name'] as String,
        lastName: identityJson['last_name'] as String,
        displayName: identityJson['display_name'] as String? ?? '',
        birthDate: _date(identityJson['birth_date']),
        cpf: identityJson['cpf'] as String,
        professionalEmail: identityJson['professional_email'] as String,
        mobile: identityJson['mobile'] as String? ?? '',
        additionalPhone: identityJson['additional_phone'] as String? ?? '',
        jobTitle: identityJson['job_title'] as String,
        department: identityJson['department'] as String? ?? '',
        internalFunction: identityJson['internal_function'] as String? ?? '',
        professionalNotes: identityJson['professional_notes'] as String? ?? '',
        postalCode: identityJson['postal_code'] as String? ?? '',
        street: identityJson['street'] as String? ?? '',
        number: identityJson['number'] as String? ?? '',
        complement: identityJson['complement'] as String? ?? '',
        neighborhood: identityJson['neighborhood'] as String? ?? '',
        city: identityJson['city'] as String? ?? '',
        state: identityJson['state'] as String? ?? '',
        country: identityJson['country'] as String? ?? 'Brasil',
      ),
      credential: SuperadminCredentialSnapshot(
        status: _credentialStatus(credentialJson['status'] as String),
      ),
      memberships: membershipRows
          .map((row) => _membership(Map<String, dynamic>.from(row as Map)))
          .toList(growable: false),
      invitation: InternalInvitation(
        id: invitationJson['id'] as String,
        email: invitationJson['email'] as String,
        status: _invitationStatus(invitationJson['status'] as String),
        attempts: (invitationJson['attempts'] as num?)?.toInt() ?? 1,
        updatedAt: DateTime.parse(invitationJson['updated_at'] as String).toUtc(),
      ),
      version: (json['version'] as num?)?.toInt() ?? 1,
      history: historyRows
          .map((row) {
            final item = Map<String, dynamic>.from(row as Map);
            return InternalUserHistoryEvent(
              at: DateTime.parse(item['at'] as String).toUtc(),
              title: item['title'] as String,
              detail: item['detail'] as String,
            );
          })
          .toList(growable: false),
    );
  }

  InternalAccessMembership _membership(Map<String, dynamic> json) => InternalAccessMembership(
    id: json['id'] as String,
    profile: _profile(Map<String, dynamic>.from(json['profile'] as Map)),
    status: PlatformMembershipStatus.values.byName(json['status'] as String),
    scope: PlatformUserScope.values.byName(json['scope'] as String),
    scopeIds: (json['scope_ids'] as List<dynamic>? ?? const []).cast<String>(),
    scopeNames: (json['scope_names'] as List<dynamic>? ?? const []).cast<String>(),
    startedAt: DateTime.parse(json['started_at'] as String).toUtc(),
    endedAt: _dateTime(json['ended_at']),
  );

  PlatformAccessProfile _profile(Map<String, dynamic> json) {
    final code = json['code'] as String? ?? '';
    return PlatformAccessProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      baseRole: PlatformUserRole.values.where((role) => role.name == code).firstOrNull,
      allowsGlobal: json['allows_global'] as bool? ?? json['max_scope_kind'] == 'platform',
      active: json['active'] as bool? ?? json['status'] == 'active',
      permissions: (json['permissions'] as List<dynamic>? ?? const []).cast<String>(),
    );
  }

  Map<String, dynamic> _identityDraft(InternalUserIdentity identity) => {
    'first_name': identity.firstName,
    'last_name': identity.lastName,
    'display_name': identity.displayName,
    'birth_date': identity.birthDate?.toIso8601String().split('T').first,
    'cpf': identity.cpf,
    'professional_email': identity.professionalEmail,
    'mobile': identity.mobile,
    'additional_phone': identity.additionalPhone,
    'job_title': identity.jobTitle,
    'department': identity.department,
    'internal_function': identity.internalFunction,
    'professional_notes': identity.professionalNotes,
    'postal_code': identity.postalCode,
    'street': identity.street,
    'number': identity.number,
    'complement': identity.complement,
    'neighborhood': identity.neighborhood,
    'city': identity.city,
    'state': identity.state,
    'country': identity.country,
  };
}

Map<String, dynamic> _payload(Object? response) {
  final payload = Map<String, dynamic>.from(response as Map);
  if (payload['ok'] == false) {
    final error = Map<String, dynamic>.from(payload['error'] as Map? ?? const {});
    throw _mapEnvelope(error);
  }
  return payload;
}

Exception _mapEnvelope(Map<String, dynamic> error) {
  final code = error['code'] as String? ?? 'SAI_INTERNAL_ERROR';
  return switch (code) {
    'SAI_MFA_REQUIRED' => const PlatformUserRuleException(
      'mfa',
      'Confirme o segundo fator para continuar.',
    ),
    'SAI_CONCURRENT_CHANGE' => const PlatformUserRuleException(
      'conflict',
      'O cadastro mudou. Recarregue e tente novamente.',
    ),
    'SAI_LAST_OWNER_PROTECTED' => const PlatformUserRuleException(
      'last-owner',
      'O último Owner global ativo permanece protegido.',
    ),
    'SAI_INVALID_INPUT' => const PlatformUserRuleException(
      'invalid-input',
      'Revise os dados enviados.',
    ),
    'SAI_PERMISSION_DENIED' ||
    'SAI_INTERNAL_CONTEXT_DENIED' ||
    'SAI_MEMBERSHIP_SUSPENDED' ||
    'SAI_MEMBERSHIP_REVOKED' => const PlatformUserRuleException(
      'unauthorized',
      'Acesso não autorizado.',
    ),
    _ => const PlatformUserRuleException('backend', 'Não foi possível concluir a operação.'),
  };
}

PlatformInvitationStatus _invitationStatus(String value) => switch (value) {
  'pending' => PlatformInvitationStatus.pending,
  'revoked' => PlatformInvitationStatus.revoked,
  'expired' => PlatformInvitationStatus.expired,
  _ => PlatformInvitationStatus.accepted,
};

SuperadminCredentialStatus _credentialStatus(String value) => switch (value) {
  'blocked' => SuperadminCredentialStatus.blocked,
  'recoveryPending' || 'recovery_pending' => SuperadminCredentialStatus.recoveryPending,
  'noAccess' || 'no_access' => SuperadminCredentialStatus.noAccess,
  _ => SuperadminCredentialStatus.active,
};

DateTime? _date(Object? value) => value == null ? null : DateTime.tryParse(value as String);
DateTime? _dateTime(Object? value) =>
    value == null ? null : DateTime.parse(value as String).toUtc();

Exception _mapError(PostgrestException error) {
  final text = '${error.code} ${error.message} ${error.details}'.toLowerCase();
  if (text.contains('sai_mfa_required')) {
    return const PlatformUserRuleException('mfa', 'Confirme o segundo fator para continuar.');
  }
  if (text.contains('sai_concurrent_change') || error.code == '40001') {
    return const PlatformUserRuleException(
      'conflict',
      'O cadastro mudou. Recarregue e tente novamente.',
    );
  }
  if (text.contains('sai_last_owner_protected')) {
    return const PlatformUserRuleException(
      'last-owner',
      'O último Owner global ativo permanece protegido.',
    );
  }
  if (error.code == '23505') {
    return const PlatformUserConflictException('identity', 'CPF ou e-mail já cadastrado.');
  }
  return const PlatformUserRuleException('backend', 'Não foi possível concluir a operação.');
}

String _requestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String part(int start, int end) =>
      bytes.sublist(start, end).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${part(0, 4)}-${part(4, 6)}-${part(6, 8)}-${part(8, 10)}-${part(10, 16)}';
}
