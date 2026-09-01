import 'dart:async';

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/platform_invite.dart';

/// Productive adapter for the internal Superadmin invitation gateway.
///
/// The client never reads `public.invitations` directly. Authorization,
/// tenant scope, MFA and audit are revalidated by every RPC.
final class SupabaseInviteRepository implements InviteRepository {
  const SupabaseInviteRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<InviteDirectoryResult> fetchPage(InviteDirectoryQuery query) => _guard(() async {
    final data = _map(
      _unwrap(
        await _client.rpc<Object?>(
          'superadmin_invite_directory_v2',
          params: {
            'p_search': _nullable(query.search),
            'p_statuses': query.statuses.isEmpty
                ? null
                : query.statuses.map((value) => value.databaseValue).toList(growable: false),
            'p_channels': query.channels.isEmpty
                ? null
                : query.channels.map((value) => value.databaseValue).toList(growable: false),
            'p_institution_ids': query.institutionIds.isEmpty
                ? null
                : query.institutionIds.toList(growable: false),
            'p_unit_ids': query.unitIds.isEmpty ? null : query.unitIds.toList(growable: false),
            'p_group_ids': query.groupIds.isEmpty ? null : query.groupIds.toList(growable: false),
            'p_profile_ids': query.profileIds.isEmpty
                ? null
                : query.profileIds.toList(growable: false),
            'p_created_from': query.createdFrom?.toUtc().toIso8601String(),
            'p_created_to': query.createdTo?.toUtc().toIso8601String(),
            'p_limit': query.pageSize,
            'p_offset': query.offset,
            'p_sort_ascending': query.sortAscending,
          },
        ),
      ),
    );
    return InviteDirectoryResult(
      items: _rows(data['items']).map(_invite).toList(growable: false),
      totalCount: _integer(data['total_count']),
      page: query.page,
      pageSize: query.pageSize,
    );
  });

  @override
  Future<InviteFormOptions> fetchOptions(InviteOptionsQuery query) => _guard(() async {
    final data = _map(
      _unwrap(
        await _client.rpc<Object?>(
          'superadmin_invite_options_v2',
          params: {
            'p_search': _nullable(query.search),
            'p_institution_id': query.institutionId,
            'p_unit_id': query.unitId,
            'p_group_id': query.groupId,
            'p_limit': query.pageSize,
          },
        ),
      ),
    );
    return InviteFormOptions(
      scopes: _rows(data['scopes']).map(_scopeOption).toList(growable: false),
      profiles: _rows(data['profiles']).map(_profileOption).toList(growable: false),
      recipients: _rows(data['recipients']).map(_recipientOption).toList(growable: false),
    );
  });

  @override
  Future<PlatformInvite?> fetchById(String inviteId) => _guard(() async {
    final data = _unwrap(
      await _client.rpc<Object?>('superadmin_invite_detail_v2', params: {'p_invite_id': inviteId}),
    );
    return _invite(_map(data));
  });

  @override
  Future<InviteCommandResult> issue(InviteIssueCommand command) => _guard(() async {
    final data = _unwrap(
      await _client.rpc<Object?>(
        'superadmin_invite_issue_v2',
        params: {
          'p_request_id': command.requestId,
          'p_institution_id': command.scope.institutionId,
          'p_unit_id': command.scope.unitId,
          'p_group_id': command.scope.groupId,
          'p_profile_id': command.profileId,
          'p_target_person_id': command.recipient.personId,
          'p_recipient_email': _nullable(command.recipient.email),
          'p_channels': command.channels
              .map((value) => value.databaseValue)
              .toList(growable: false),
          'p_expires_in_hours': command.expiresInHours,
        },
      ),
    );
    return _commandResult(_map(data));
  });

  @override
  Future<InviteCommandResult> resend(InviteResendCommand command) => _guard(() async {
    final data = _unwrap(
      await _client.rpc<Object?>(
        'superadmin_invite_resend_v2',
        params: {
          'p_invite_id': command.inviteId,
          'p_request_id': command.requestId,
          'p_expected_version': command.expectedVersion,
        },
      ),
    );
    return _commandResult(_map(data));
  });

  @override
  Future<InviteCommandResult> revoke(InviteRevokeCommand command) => _guard(() async {
    final data = _unwrap(
      await _client.rpc<Object?>(
        'superadmin_invite_revoke_v2',
        params: {
          'p_invite_id': command.inviteId,
          'p_request_id': command.requestId,
          'p_expected_version': command.expectedVersion,
          'p_reason': command.reason.trim(),
        },
      ),
    );
    return _commandResult(_map(data));
  });
}

Future<T> _guard<T>(Future<T> Function() operation) async {
  try {
    return await operation();
  } on InviteUnauthorizedException {
    rethrow;
  } on InviteValidationException {
    rethrow;
  } on InviteConflictException {
    rethrow;
  } on InviteUnavailableException {
    rethrow;
  } on PostgrestException catch (error) {
    throw _transportError(error);
  } on TimeoutException {
    throw const InviteUnavailableException();
  } on ClientException {
    throw const InviteUnavailableException();
  } on FormatException {
    throw const InviteUnavailableException();
  } on Object {
    throw const InviteUnavailableException();
  }
}

Object? _unwrap(Object? raw) {
  final envelope = _map(raw);
  if (envelope.keys.toSet().difference(const {'ok', 'data', 'error'}).isNotEmpty ||
      !envelope.containsKey('ok') ||
      !envelope.containsKey('data') ||
      !envelope.containsKey('error')) {
    throw const InviteUnavailableException();
  }
  if (envelope['ok'] == true && envelope['error'] == null) return envelope['data'];
  if (envelope['ok'] == false && envelope['data'] == null) {
    final error = _map(envelope['error']);
    throw _domainError(_string(error, 'code'));
  }
  throw const InviteUnavailableException();
}

Exception _domainError(String code) => switch (code) {
  'SAI_AUTH_REQUIRED' ||
  'SAI_SESSION_INVALID' ||
  'SAI_INTERNAL_CONTEXT_DENIED' ||
  'SAI_MEMBERSHIP_SUSPENDED' ||
  'SAI_MEMBERSHIP_REVOKED' ||
  'SAI_PERMISSION_DENIED' ||
  'SAI_MFA_REQUIRED' => const InviteUnauthorizedException(),
  'SAI_CONCURRENT_CHANGE' => const InviteConflictException(),
  'SAI_INVALID_ARGUMENT' => const InviteValidationException(),
  _ => const InviteUnavailableException(),
};

Exception _transportError(PostgrestException error) => switch (error.code) {
  '42501' || 'PGRST301' || 'PGRST302' => const InviteUnauthorizedException(),
  '40001' || '23505' => const InviteConflictException(),
  '22023' || '23502' || '23503' || '23514' => const InviteValidationException(),
  _ => const InviteUnavailableException(),
};

PlatformInvite _invite(Map<String, dynamic> json) => PlatformInvite(
  id: _string(json, 'id'),
  scope: InviteScope(
    kind: InviteScopeKind.fromDatabase(_string(json, 'scope_kind')),
    institutionId: _string(json, 'institution_id'),
    unitId: _optionalString(json['unit_id']),
    groupId: _optionalString(json['group_id']),
    label: _string(json, 'scope_label'),
  ),
  profile: InviteProfileReference(
    id: _string(json, 'profile_id'),
    label: _string(json, 'profile_label'),
  ),
  recipient: InviteRecipient(
    label: _optionalString(json['recipient_label']),
    maskedEmail: _optionalString(json['recipient_masked']),
  ),
  channels: Set.unmodifiable(_strings(json['channels']).map(InviteChannel.fromDatabase)),
  status: InviteStatus.fromDatabase(_string(json, 'status')),
  issuer: _issuer(json['issuer']),
  createdAt: _date(json, 'created_at'),
  expiresAt: _date(json, 'expires_at'),
  acceptedAt: _optionalDate(json['accepted_at']),
  revokedAt: _optionalDate(json['revoked_at']),
  emailDeliveryStatus: InviteDeliveryStatus.fromDatabase(
    _optionalString(json['email_delivery_status']) ?? 'not_requested',
  ),
  managementVersion: _integer(json['management_version']),
  timeline: _rows(json['timeline'])
      .map((event) => InviteTimelineEntry(_string(event, 'label'), _date(event, 'occurred_at')))
      .toList(growable: false),
);

InviteScopeOption _scopeOption(Map<String, dynamic> json) => InviteScopeOption(
  scope: InviteScope(
    kind: InviteScopeKind.fromDatabase(_string(json, 'scope_kind')),
    institutionId: _string(json, 'institution_id'),
    unitId: _optionalString(json['unit_id']),
    groupId: _optionalString(json['group_id']),
    label: _string(json, 'label'),
  ),
);

InviteProfileOption _profileOption(Map<String, dynamic> json) => InviteProfileOption(
  id: _string(json, 'profile_id'),
  label: _string(json, 'label'),
  institutionId: _string(json, 'institution_id'),
  unitId: _optionalString(json['unit_id']),
  groupId: _optionalString(json['group_id']),
);

InviteRecipientOption _recipientOption(Map<String, dynamic> json) => InviteRecipientOption(
  personId: _string(json, 'person_id'),
  label: _string(json, 'label'),
  maskedEmail: _optionalString(json['masked_email']),
);

InviteCommandResult _commandResult(Map<String, dynamic> json) => InviteCommandResult(
  invite: _invite(_map(json['invite'])),
  replayed: json['replayed'] == true,
  link: _safeLink(json['link']),
);

InviteIssuer _issuer(Object? raw) {
  final issuer = _map(raw);
  if (issuer.keys.toSet().difference(const {'kind', 'display'}).isNotEmpty || issuer.length != 2) {
    throw const InviteUnavailableException();
  }
  return InviteIssuer(
    kind: InviteIssuerKind.fromDatabase(_string(issuer, 'kind')),
    label: _string(issuer, 'display'),
  );
}

Uri? _safeLink(Object? value) {
  if (value == null) return null;
  final uri = Uri.tryParse(value.toString());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host != 'app.coelo.me' ||
      uri.query.isNotEmpty ||
      uri.fragment.isNotEmpty ||
      !RegExp(r'^/convites/[0-9a-f]{64}$').hasMatch(uri.path)) {
    throw const InviteUnavailableException();
  }
  return uri;
}

Map<String, dynamic> _map(Object? raw) {
  if (raw is Map<Object?, Object?> && raw.keys.every((key) => key is String)) {
    return Map<String, dynamic>.from(raw);
  }
  if (raw is List && raw.length == 1) return _map(raw.single);
  throw const InviteUnavailableException();
}

List<Map<String, dynamic>> _rows(Object? raw) {
  if (raw is! List) throw const InviteUnavailableException();
  return raw.map(_map).toList(growable: false);
}

List<String> _strings(Object? raw) {
  if (raw is! List || raw.any((value) => value is! String || value.isEmpty)) {
    throw const InviteUnavailableException();
  }
  return List<String>.from(raw);
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw const InviteUnavailableException();
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  if (value is String && value.isNotEmpty) return value;
  throw const InviteUnavailableException();
}

String? _nullable(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

int _integer(Object? value) {
  if (value is int && value >= 0) return value;
  throw const InviteUnavailableException();
}

DateTime _date(Map<String, dynamic> json, String key) {
  final parsed = DateTime.tryParse(_string(json, key));
  if (parsed == null) throw const InviteUnavailableException();
  return parsed.toUtc();
}

DateTime? _optionalDate(Object? value) {
  if (value == null) return null;
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) throw const InviteUnavailableException();
  return parsed.toUtc();
}
