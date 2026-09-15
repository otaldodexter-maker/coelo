import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/account_profile.dart';
import 'account_profile_repository.dart';

final class SupabaseAccountProfileRepository
    implements AccountProfileRepository, AccountEmailChangeCancellation {
  SupabaseAccountProfileRepository(this._client, {http.Client? mediaClient})
    : _mediaClient = mediaClient;

  final SupabaseClient _client;
  final http.Client? _mediaClient;
  int _avatarContractVersion = 1;
  String? _loadedAvatarAssetId;

  @override
  Future<AccountProfile> load() async {
    final profile = _profile(await _rpc('superadmin_account_profile_get'));
    return _loadAvatarBytes(profile);
  }

  @override
  Future<AccountProfile> save(AccountProfile profile) async {
    var nextProfile = profile;
    if (profile.avatar.mode == AccountAvatarMode.photo &&
        profile.avatar.photoBytes != null &&
        profile.avatar.photoAssetId == null) {
      final assetId = await _uploadAvatar(profile.avatar.photoBytes!);
      nextProfile = profile.copyWith(avatar: profile.avatar.copyWith(photoAssetId: assetId));
    } else if (profile.avatar.mode != AccountAvatarMode.photo && _loadedAvatarAssetId != null) {
      await _mediaAction({'action': 'remove', 'asset_id': _loadedAvatarAssetId});
      _loadedAvatarAssetId = null;
    }
    return _loadAvatarBytes(
      _profile(
        await _rpc(
          _avatarContractVersion >= 2
              ? 'superadmin_account_profile_save_v2'
              : 'superadmin_account_profile_save',
          {
            'p_request_id': _uuidV4(),
            'p_first_name': nextProfile.firstName.trim(),
            'p_last_name': nextProfile.lastName.trim(),
            'p_mobile_phone': nextProfile.mobilePhone.trim(),
            'p_requested_email': nextProfile.emailChange?.requestedEmail,
            'p_avatar_initials': nextProfile.avatar.initials.trim(),
            if (_avatarContractVersion >= 2)
              'p_avatar_background_color':
                  '#${(nextProfile.avatar.backgroundColor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
          },
        ),
      ),
    );
  }

  Future<AccountProfile> _loadAvatarBytes(AccountProfile profile) async {
    final assetId = profile.avatar.photoAssetId;
    if (profile.avatar.mode != AccountAvatarMode.photo || assetId == null) {
      _loadedAvatarAssetId = null;
      return profile;
    }
    final descriptor = await _mediaAction({'action': 'read', 'asset_id': assetId});
    final signedUrl = descriptor['signed_url'];
    final uri = signedUrl is String ? Uri.tryParse(signedUrl) : null;
    if (uri == null || !uri.hasScheme || uri.userInfo.isNotEmpty) {
      throw const AccountProfileRepositoryException('Leitura de foto não autorizada.');
    }
    final response = await _withMediaClient((client) => client.get(uri));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const AccountProfileRepositoryException('Leitura de foto não autorizada.');
    }
    _loadedAvatarAssetId = assetId;
    return profile.copyWith(
      avatar: profile.avatar.copyWith(photoBytes: Uint8List.fromList(response.bodyBytes)),
    );
  }

  Future<String> _uploadAvatar(Uint8List bytes) async {
    final digest = sha256.convert(bytes).toString();
    final prepared = await _mediaAction({
      'action': 'prepare',
      'request_id': _uuidV4(),
      'file_name': 'avatar.png',
      'content_type': 'image/png',
      'byte_size': bytes.length,
      'sha256': digest,
    });
    final assetId = _string(prepared, 'asset_id');
    final uploadUrl = _url(prepared, 'upload_url');
    final headers = <String, String>{};
    final requiredHeaders = prepared['required_headers'];
    if (requiredHeaders is! Map) {
      throw const AccountProfileRepositoryException('Upload de foto inválido.');
    }
    for (final entry in requiredHeaders.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const AccountProfileRepositoryException('Upload de foto inválido.');
      }
      final key = (entry.key as String).toLowerCase();
      if (key == 'authorization' || key == 'apikey' || key == 'cookie') {
        throw const AccountProfileRepositoryException('Upload de foto inválido.');
      }
      headers[key] = entry.value as String;
    }
    if (headers['content-type'] != 'image/png') {
      throw const AccountProfileRepositoryException('Upload de foto inválido.');
    }
    final uploaded = await _withMediaClient((client) async {
      final request = http.Request('PUT', uploadUrl)
        ..followRedirects = false
        ..headers.addAll(headers)
        ..bodyBytes = bytes;
      return http.Response.fromStream(await client.send(request));
    });
    if (uploaded.statusCode < 200 || uploaded.statusCode >= 300) {
      throw const AccountProfileRepositoryException('Não foi possível enviar a foto.');
    }
    final finalized = await _mediaAction({'action': 'finalize', 'asset_id': assetId});
    if (_string(finalized, 'asset_id') != assetId || finalized['status'] != 'active') {
      throw const AccountProfileRepositoryException('Não foi possível confirmar a foto.');
    }
    _loadedAvatarAssetId = assetId;
    return assetId;
  }

  Future<Map<String, dynamic>> _mediaAction(Map<String, dynamic> body) async {
    try {
      final response = await _client.functions.invoke('account-media', body: body);
      if (response.status != 200 || response.data is! Map) {
        throw const AccountProfileRepositoryException('Operação de foto não autorizada.');
      }
      return Map<String, dynamic>.from(response.data as Map);
    } on FunctionException catch (error) {
      throw AccountProfileRepositoryException(
        error.details is Map
            ? '${(error.details as Map)['error'] ?? 'Operação de foto não autorizada.'}'
            : 'Operação de foto não autorizada.',
      );
    }
  }

  Future<T> _withMediaClient<T>(Future<T> Function(http.Client client) action) async {
    final client = _mediaClient ?? http.Client();
    try {
      return await action(client);
    } finally {
      if (_mediaClient == null) client.close();
    }
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
    _avatarContractVersion = json['avatar_contract_version'] == 2 ? 2 : 1;
    final avatar = _map(json['avatar']);
    final access = _map(json['access']);
    final emailChange = json['email_change'];
    return AccountProfile(
      firstName: _string(json, 'first_name'),
      lastName: _string(json, 'last_name'),
      email: _string(json, 'email'),
      mobilePhone: _string(json, 'mobile_phone'),
      avatar: AccountAvatar(
        mode: avatar['mode'] == 'photo' && avatar['asset_id'] is String
            ? AccountAvatarMode.photo
            : AccountAvatarMode.initials,
        // A projecao deriva a sigla das iniciais e pode trazer digito quando o
        // sobrenome e numerico (pessoa de servico da ponte): o cliente so aceita
        // letras, entao deriva a sigla das letras do nome nesse caso (R04).
        initials: AccountAvatar.lettersOnlyInitials(
          _string(avatar, 'initials'),
          _string(json, 'first_name'),
          _string(json, 'last_name'),
        ),
        backgroundColor: _color(_string(avatar, 'background_color')),
        photoAssetId: avatar['asset_id'] is String ? avatar['asset_id'] as String : null,
      ),
      access: AccountAccessSummary(
        role: _string(access, 'role'),
        mfaEnabled: access['mfa_enabled'] == true,
        capabilities: _list(access['capabilities']),
        capabilityDetails: [
          for (final item in (access['capability_details'] as List? ?? const []))
            if (item is Map &&
                item['module_code'] is String &&
                item['module_label'] is String &&
                item['scope_kind'] is String &&
                item['scope_label'] is String)
              AccountCapabilityDetail(
                code: item['code'] as String,
                label: item['label'] as String,
                moduleCode: item['module_code'] as String,
                moduleLabel: item['module_label'] as String,
                scopeKind: item['scope_kind'] as String,
                scopeId: item['scope_id'] as String?,
                scopeLabel: item['scope_label'] as String,
              ),
        ],
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

Uri _url(Map<String, dynamic> json, String key) {
  final value = json[key];
  final uri = value is String ? Uri.tryParse(value) : null;
  if (uri == null || !uri.hasScheme || uri.userInfo.isNotEmpty) {
    throw const AccountProfileRepositoryException('URL de mídia inválida.');
  }
  return uri;
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
