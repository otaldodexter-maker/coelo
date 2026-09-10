import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/account_profile.dart';
import 'account_profile_repository.dart';

final class SupabaseAccountProfileRepository
    implements AccountProfileRepository, AccountEmailChangeCancellation {
  const SupabaseAccountProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AccountProfile> load() async => _profile(await _rpc('superadmin_account_profile_get'));

  @override
  Future<void> save(AccountProfile profile) async {
    await _rpc('superadmin_account_profile_save', {
      'p_request_id': _uuidV4(),
      'p_first_name': profile.firstName.trim(),
      'p_last_name': profile.lastName.trim(),
      'p_mobile_phone': profile.mobilePhone.trim(),
      'p_requested_email': profile.emailChange?.requestedEmail,
      'p_avatar_initials': profile.avatar.initials.trim(),
    });
  }

  @override
  Future<void> cancelEmailChange() async {
    await _rpc('superadmin_account_email_change_cancel', {'p_request_id': _uuidV4()});
  }

  Future<Object?> _rpc(String function, [Map<String, Object?>? params]) async {
    try {
      return await _client.rpc<Object?>(function, params: params);
    } on PostgrestException catch (error) {
      throw AccountProfileRepositoryException(error.message);
    } on Exception {
      throw const AccountProfileRepositoryException('Não foi possível concluir a operação.');
    }
  }

  AccountProfile _profile(Object? raw) {
    if (raw is! Map) throw const AccountProfileRepositoryException('Resposta de perfil inválida.');
    final json = Map<String, Object?>.from(raw);
    final avatar = _map(json['avatar']);
    final access = _map(json['access']);
    final emailChange = json['email_change'];
    return AccountProfile(
      firstName: _string(json, 'first_name'),
      lastName: _string(json, 'last_name'),
      email: _string(json, 'email'),
      mobilePhone: _string(json, 'mobile_phone'),
      avatar: AccountAvatar(
        mode: AccountAvatarMode.initials,
        initials: _string(avatar, 'initials'),
        backgroundColor: _color(_string(avatar, 'background_color')),
      ),
      access: AccountAccessSummary(
        role: _string(access, 'role'),
        mfaEnabled: access['mfa_enabled'] == true,
        capabilities: _list(access['capabilities']),
      ),
      emailChange: emailChange == null ? null : _emailChange(_map(emailChange)),
    );
  }

  EmailChangeRequest _emailChange(Map<String, Object?> json) => EmailChangeRequest(
    requestedEmail: _string(json, 'requested_email'),
    status: switch (_string(json, 'status')) {
      'approved' => EmailChangeStatus.approved,
      'rejected' => EmailChangeStatus.rejected,
      _ => EmailChangeStatus.pending,
    },
  );
}

final class AccountProfileRepositoryException implements Exception {
  const AccountProfileRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

Map<String, Object?> _map(Object? value) {
  if (value is Map) return Map<String, Object?>.from(value);
  throw const AccountProfileRepositoryException('Resposta de perfil inválida.');
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw const AccountProfileRepositoryException('Resposta de perfil inválida.');
}

List<String> _list(Object? value) {
  if (value is List) return value.whereType<String>().toList(growable: false);
  return const <String>[];
}

Color _color(String value) {
  final normalized = value.replaceFirst('#', '');
  final hex = normalized.length == 6 ? 'FF$normalized' : normalized;
  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? AccountAvatar.defaultBackgroundColor : Color(parsed);
}

String _uuidV4() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
