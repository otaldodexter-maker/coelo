import 'dart:async';

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/platform_invite.dart';

/// Productive adapter for the server-authorised invitation RPC surface.
///
/// No table is queried directly. The Supabase client is expected to contain
/// only the publishable client key; authorization remains in the RPC/database.
final class SupabaseInviteRepository implements InviteRepository {
  const SupabaseInviteRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<InviteDirectoryResult> fetchPage(InviteDirectoryQuery query) async {
    try {
      final payload = _map(
        await _client.rpc<Object?>(
          'superadmin_invite_directory',
          params: {
            'p_search': query.search.trim(),
            'p_statuses': query.statuses
                .map((status) => status.databaseValue)
                .toList(growable: false),
            'p_channels': query.channels
                .map((channel) => channel.databaseValue)
                .toList(growable: false),
            'p_institution_ids': query.institutionIds.toList(growable: false),
            'p_unit_ids': query.unitIds.toList(growable: false),
            'p_group_ids': query.groupIds.toList(growable: false),
            'p_profile_ids': query.profileIds.toList(growable: false),
            'p_created_from': _timestamp(query.createdFrom),
            'p_created_to': _timestamp(query.createdTo),
            'p_limit': query.pageSize,
            'p_offset': query.offset,
            'p_sort': 'created_at',
            'p_sort_ascending': query.sortAscending,
          },
        ),
      );
      return InviteDirectoryResult(
        items: List.unmodifiable(_rows(payload['items']).map(_invite)),
        totalCount: _integer(payload['total_count']),
        page: query.page,
        pageSize: query.pageSize,
      );
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<InviteFormOptions> fetchOptions(InviteOptionsQuery query) async {
    try {
      final payload = _map(
        await _client.rpc<Object?>(
          'superadmin_invite_options',
          params: {
            'p_search': query.search.trim(),
            'p_institution_id': query.institutionId,
            'p_unit_id': query.unitId,
            'p_group_id': query.groupId,
            'p_limit': query.pageSize,
          },
        ),
      );
      return InviteFormOptions(
        scopes: List.unmodifiable(_rows(payload['scopes']).map(_scopeOption)),
        profiles: List.unmodifiable(_rows(payload['profiles']).map(_profileOption)),
        recipients: List.unmodifiable(_rows(payload['recipients']).map(_recipientOption)),
      );
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<PlatformInvite?> fetchById(String inviteId) async {
    try {
      final payload = _map(
        await _client.rpc<Object?>('superadmin_invite_get', params: {'p_invite_id': inviteId}),
      );
      return _invite(payload);
    } on PostgrestException catch (error) {
      if (error.code == 'P0002') return null;
      throw _mapError(error);
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<InviteCommandResult> issue(InviteIssueCommand command) async {
    try {
      return _commandResult(
        _map(
          await _client.rpc<Object?>(
            'superadmin_invite_issue',
            params: {
              'p_request_id': command.requestId,
              'p_institution_id': command.scope.institutionId,
              'p_unit_id': command.scope.unitId,
              'p_group_id': command.scope.groupId,
              'p_profile_id': command.profileId,
              'p_target_person_id': command.recipient.personId,
              'p_recipient_email': command.recipient.email?.trim(),
              'p_channels': command.channels
                  .map((channel) => channel.databaseValue)
                  .toList(growable: false),
              'p_expires_in_hours': command.expiresInHours,
            },
          ),
        ),
      );
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<InviteCommandResult> resend(InviteResendCommand command) async {
    try {
      return _commandResult(
        _map(
          await _client.rpc<Object?>(
            'superadmin_invite_resend',
            params: {
              'p_invite_id': command.inviteId,
              'p_request_id': command.requestId,
              'p_expected_version': command.expectedVersion,
            },
          ),
        ),
      );
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<InviteCommandResult> revoke(InviteRevokeCommand command) async {
    try {
      return _commandResult(
        _map(
          await _client.rpc<Object?>(
            'superadmin_invite_revoke',
            params: {
              'p_invite_id': command.inviteId,
              'p_request_id': command.requestId,
              'p_expected_version': command.expectedVersion,
              'p_reason': command.reason.trim(),
            },
          ),
        ),
      );
    } catch (error) {
      throw _mapError(error);
    }
  }
}

PlatformInvite _invite(Map<String, dynamic> json) => PlatformInvite(
  id: _string(json, 'invite_id'),
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
    personId: _optionalString(json['target_person_id']),
    label: _optionalString(json['recipient_label']),
    maskedEmail: _optionalString(json['recipient_masked']),
  ),
  channels: Set.unmodifiable(_strings(json['channels']).map(InviteChannel.fromDatabase)),
  status: InviteStatus.fromDatabase(_string(json, 'status')),
  issuer: InviteIssuer(
    personId: _string(json, 'issuer_person_id'),
    label: _string(json, 'issuer_label'),
  ),
  createdAt: _date(json, 'created_at'),
  expiresAt: _date(json, 'expires_at'),
  acceptedAt: _optionalDate(json['accepted_at']),
  revokedAt: _optionalDate(json['revoked_at']),
  emailDeliveryStatus: InviteDeliveryStatus.fromDatabase(
    _optionalString(json['email_delivery_status']) ?? 'not_requested',
  ),
  managementVersion: _integer(json['management_version'], positive: true),
  timeline: List.unmodifiable(
    _rows(
      json['timeline'],
    ).map((event) => InviteTimelineEntry(_string(event, 'label'), _date(event, 'occurred_at'))),
  ),
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
  replayed: json['replayed'] as bool? ?? false,
  link: _safeLink(json['link']),
);

Exception _mapError(Object error) {
  if (error is InviteUnauthorizedException ||
      error is InviteNotFoundException ||
      error is InviteValidationException ||
      error is InviteConflictException ||
      error is InviteUnavailableException) {
    return error as Exception;
  }
  if (error is PostgrestException) {
    return switch (error.code) {
      '42501' || 'PGRST301' => const InviteUnauthorizedException(),
      'P0002' => const InviteNotFoundException(),
      '22023' || '23514' || 'P0001' => const InviteValidationException(),
      '40001' || '23505' || '23P01' => const InviteConflictException(),
      _ => const InviteUnavailableException(),
    };
  }
  if (error is TimeoutException || error is ClientException) {
    return const InviteUnavailableException();
  }
  return const InviteUnavailableException();
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<Object?, Object?>) return Map<String, dynamic>.from(value);
  throw const InviteUnavailableException();
}

List<Map<String, dynamic>> _rows(Object? value) {
  if (value is! List) throw const InviteUnavailableException();
  final rows = <Map<String, dynamic>>[];
  for (final row in value) {
    if (row is! Map<Object?, Object?> || row.keys.any((key) => key is! String)) {
      throw const InviteUnavailableException();
    }
    rows.add(Map<String, dynamic>.from(row));
  }
  return rows;
}

List<String> _strings(Object? value) {
  if (value is! List || value.isEmpty || value.any((item) => item is! String || item.isEmpty)) {
    throw const InviteUnavailableException();
  }
  return List<String>.from(value);
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

int _integer(Object? value, {bool positive = false}) {
  if (value is int && value >= (positive ? 1 : 0)) return value;
  throw const InviteUnavailableException();
}

DateTime _date(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return DateTime.parse(value);
  throw const InviteUnavailableException();
}

DateTime? _optionalDate(Object? value) => value is String ? DateTime.parse(value) : null;

String? _timestamp(DateTime? value) => value?.toUtc().toIso8601String();

final RegExp _inviteLinkPath = RegExp(r'^/convites/[0-9a-f]{64}$');

Uri? _safeLink(Object? value) {
  if (value == null) return null;
  if (value is! String || value.isEmpty) throw const InviteUnavailableException();
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.authority != 'app.coelo.me' ||
      !_inviteLinkPath.hasMatch(uri.path) ||
      value != 'https://app.coelo.me${uri.path}') {
    throw const InviteUnavailableException();
  }
  return uri;
}
