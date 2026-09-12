import 'dart:convert';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/platform_user.dart';

/// Production repository for already-provisioned Superadmin internal identities.
///
/// Auth invitation and recovery deliberately remain outside this repository
/// until OQ-039 defines their privileged gateway contract.
final class SupabasePlatformUserRepository
    implements PlatformUserRepository, PlatformUserRemoteLoader, PlatformUserServicePersonResolver {
  SupabasePlatformUserRepository(this._client);

  final SupabaseClient _client;
  final Map<String, PlatformUserRecord> _records = {};
  List<PlatformAccessProfile> _profiles = const [];
  int _cacheRevision = 0;
  final Map<String, ({String fingerprint, String requestId})> _pendingCommands = {};

  /// Discards this session's projection and invalidates its pending responses.
  void clearSessionCache() {
    _cacheRevision++;
    _records.clear();
    _profiles = const [];
    _pendingCommands.clear();
  }

  void _requireCurrentCache(int revision) {
    if (revision != _cacheRevision) {
      throw const PlatformUserRuleException('unauthorized', 'Acesso não autorizado.');
    }
  }

  Map<String, dynamic> _responsePayload(Object? response, int revision) {
    _requireCurrentCache(revision);
    try {
      return _payload(response);
    } on PlatformUserRuleException catch (error) {
      if (error.code == 'unauthorized') clearSessionCache();
      rethrow;
    }
  }

  Exception _requestError(PostgrestException error, int revision) {
    _requireCurrentCache(revision);
    final mapped = _mapError(error);
    if (mapped is PlatformUserRuleException && mapped.code == 'unauthorized') {
      clearSessionCache();
    }
    return mapped;
  }

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
    final revision = _cacheRevision;
    try {
      final response = await _client.rpc<Map<String, dynamic>>('superadmin_internal_user_profiles');
      final payload = _responsePayload(response, revision);
      final rows = payload['items'] as List<dynamic>? ?? const [];
      _profiles = rows
          .map((row) => _profile(Map<String, dynamic>.from(row as Map)))
          .where((profile) => profile.active)
          .toList(growable: false);
      return profiles;
    } on PostgrestException catch (error) {
      throw _requestError(error, revision);
    }
  }

  @override
  Future<PlatformUserPage> fetchPage(PlatformUserQuery query) async {
    final revision = _cacheRevision;
    try {
      if (_profiles.isEmpty) await fetchProfiles();
      _requireCurrentCache(revision);
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
      final payload = _responsePayload(response, revision);
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
      throw _requestError(error, revision);
    }
  }

  @override
  Future<PlatformUserRecord?> fetchById(String id) async {
    final revision = _cacheRevision;
    try {
      if (_profiles.isEmpty) await fetchProfiles();
      _requireCurrentCache(revision);
      final response = await _client.rpc<Map<String, dynamic>>(
        'superadmin_internal_user_detail',
        params: {'p_internal_identity_id': id},
      );
      final record = _record(_responsePayload(response, revision), expectedId: id);
      _records[record.id] = record;
      return record;
    } on PostgrestException catch (error) {
      _requireCurrentCache(revision);
      if (error.code == 'P0002') {
        _records.remove(id);
        return null;
      }
      throw _requestError(error, revision);
    }
  }

  @override
  Future<String?> servicePersonId(String internalUserId) async {
    try {
      final response = await _client.rpc<Object?>(
        'superadmin_internal_user_service_person_v1',
        params: {'p_internal_identity_id': internalUserId},
      );
      final envelope = Map<String, dynamic>.from(response as Map);
      final data = envelope['data'];
      return data == null ? null : (Map<String, dynamic>.from(data as Map)['person_id'] as String?);
    } on Object {
      // RPC ausente (PGRST202), negada ou fora do ar: a secao do @ nao aparece.
      return null;
    }
  }

  @override
  Future<PlatformUserCreateResult> create(PlatformUserDraft draft) async {
    // Edge Function internal-user-create (170800): autoriza com o token do
    // operador, cria o auth user pelo Admin API e grava a identidade interna.
    // Sem a funcao implantada (404) a acao continua honestamente indisponivel.
    final revision = _cacheRevision;
    try {
      final response = await _client.functions.invoke(
        'internal-user-create',
        body: {
          'request_id': _requestId(),
          'draft': {
            'identity': _identityDraft(draft.identity),
            'profile_id': draft.profile.id,
            'scope': draft.scope.name,
            'scope_ids': draft.scopeIds,
          },
        },
      );
      final data = response.data;
      final envelope = data is Map ? Map<String, dynamic>.from(data) : const <String, dynamic>{};
      if (response.status < 200 || response.status >= 300 || envelope['ok'] != true) {
        throw PlatformUserRuleException(
          envelope['error']?.toString() ?? 'backend',
          switch (envelope['error']) {
            'not_authorized' => 'Você não pode criar usuários internos neste escopo.',
            'auth_user_unavailable' => 'Já existe uma conta com este e-mail.',
            _ => 'Não foi possível criar o usuário interno. Tente novamente.',
          },
        );
      }
      final record = _record(Map<String, dynamic>.from(envelope['data'] as Map));
      _requireCurrentCache(revision);
      _records[record.id] = record;
      return PlatformUserCreateResult(
        record: record,
        message: 'Usuário interno criado. Entregue o link seguro de definição de senha.',
        passwordSetupLink: _passwordSetupLink(envelope['data']),
      );
    } on PlatformUserRuleException {
      rethrow;
    } on FunctionException catch (error) {
      throw PlatformUserRuleException(
        error.status == 404 ? 'invitation-contract' : 'backend',
        error.status == 404
            ? 'A criação de usuários internos ainda não está disponível.'
            : 'Não foi possível criar o usuário interno. Tente novamente.',
      );
    } on Object {
      throw const PlatformUserRuleException(
        'backend',
        'Não foi possível criar o usuário interno. Tente novamente.',
      );
    }
  }

  @override
  Future<PlatformUserRecord> update(String id, PlatformUserDraft draft) async {
    final revision = _cacheRevision;
    final current = await _required(id);
    return _command('superadmin_internal_user_update', {
      'p_internal_identity_id': id,
      'p_expected_version': current.version,
      'p_reason': 'Cadastro interno revisado no Superadmin.',
      'p_draft': {
        'identity': _identityDraft(draft.identity),
        'profile_id': draft.profile.id,
        'scope': draft.scope.name,
        'scope_ids': draft.scopeIds,
      },
    }, revision: revision);
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
    final revision = _cacheRevision;
    final current = await _required(id);
    return _command('superadmin_internal_user_change_status', {
      'p_internal_identity_id': id,
      'p_expected_version': current.version,
      'p_status': status,
      'p_reason': switch (status) {
        'suspended' => 'Acesso interno suspenso no Superadmin.',
        'active' => 'Acesso interno reativado no Superadmin.',
        _ => 'Vínculo interno revogado no Superadmin.',
      },
    }, revision: revision);
  }

  Future<PlatformUserRecord> _command(
    String function,
    Map<String, dynamic> params, {
    required int revision,
  }) async {
    _requireCurrentCache(revision);
    final commandKey = '$function:${params['p_internal_identity_id']}';
    final fingerprint = jsonEncode(params);
    var pending = _pendingCommands[commandKey];
    if (pending == null || pending.fingerprint != fingerprint) {
      pending = (fingerprint: fingerprint, requestId: _requestId());
      _pendingCommands[commandKey] = pending;
    }
    try {
      final response = await _client.rpc<Map<String, dynamic>>(
        function,
        params: {'p_request_id': pending.requestId, ...params},
      );
      final record = _record(
        _responsePayload(response, revision),
        expectedId: params['p_internal_identity_id'] as String,
      );
      _records[record.id] = record;
      if (_pendingCommands[commandKey] == pending) _pendingCommands.remove(commandKey);
      return record;
    } on PostgrestException catch (error) {
      throw _requestError(error, revision);
    } on Object catch (error) {
      _requireCurrentCache(revision);
      if (error is PlatformUserRuleException || error is PlatformUserConflictException) rethrow;
      throw const PlatformUserRuleException(
        'backend',
        'Não foi possível confirmar a operação. Tente novamente.',
      );
    }
  }

  Future<PlatformUserRecord> _required(String id) async {
    final record = _records[id] ?? await fetchById(id);
    if (record == null) {
      throw const PlatformUserRuleException('not-found', 'Usuário interno não encontrado.');
    }
    return record;
  }

  PlatformUserRecord _record(Map<String, dynamic> json, {String? expectedId}) {
    final identityJson = Map<String, dynamic>.from(json['identity'] as Map);
    if (expectedId != null &&
        (identityJson['id'] as String).toLowerCase() != expectedId.toLowerCase()) {
      throw const PlatformUserRuleException(
        'backend',
        'Não foi possível confirmar a operação. Tente novamente.',
      );
    }
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

Uri? _passwordSetupLink(Object? data) {
  final value = data is Map ? data['password_setup_link'] : null;
  if (value == null) {
    throw const PlatformUserRuleException('backend', 'Não foi possível preparar o link seguro.');
  }
  final link = Uri.tryParse(value.toString());
  if (link == null || link.scheme != 'https' || link.userInfo.isNotEmpty) {
    throw const PlatformUserRuleException('backend', 'Não foi possível preparar o link seguro.');
  }
  return link;
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
    'SAI_AUTH_REQUIRED' ||
    'SAI_SESSION_INVALID' ||
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
  'accepted' => PlatformInvitationStatus.accepted,
  'pending' => PlatformInvitationStatus.pending,
  'revoked' => PlatformInvitationStatus.revoked,
  'expired' => PlatformInvitationStatus.expired,
  _ => throw const PlatformUserRuleException(
    'backend',
    'Não foi possível carregar o usuário interno.',
  ),
};

SuperadminCredentialStatus _credentialStatus(String value) => switch (value) {
  'active' => SuperadminCredentialStatus.active,
  'blocked' => SuperadminCredentialStatus.blocked,
  'recoveryPending' || 'recovery_pending' => SuperadminCredentialStatus.recoveryPending,
  'noAccess' || 'no_access' => SuperadminCredentialStatus.noAccess,
  _ => throw const PlatformUserRuleException(
    'backend',
    'Não foi possível carregar o usuário interno.',
  ),
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
  if (const {'42501', 'PGRST301', 'PGRST302', 'PGRST303'}.contains(error.code)) {
    return const PlatformUserRuleException('unauthorized', 'Acesso não autorizado.');
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
