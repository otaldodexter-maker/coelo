import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class FormsAnonymousEditSecretStore {
  Future<String> loadOrCreate(String occurrenceId);
}

typedef FormsAnonymousEditSecretStoreProvider = FormsAnonymousEditSecretStore? Function();
typedef FormsAnonymousEditSecretStoreFactory =
    FormsAnonymousEditSecretStore Function(String projectId, String accountId);

/// Keeps one store identity for the active account and drops it on sign-out.
final class FormsAnonymousEditSecretStoreResolver {
  FormsAnonymousEditSecretStoreResolver({
    required this.projectId,
    FormsAnonymousEditSecretStoreFactory? create,
  }) : _create = create ?? _createSharedPreferencesStore {
    if (projectId.isEmpty) throw ArgumentError.value(projectId, 'projectId');
  }

  final String projectId;
  final FormsAnonymousEditSecretStoreFactory _create;
  String? _accountId;
  FormsAnonymousEditSecretStore? _store;

  FormsAnonymousEditSecretStore? resolve(String? accountId) {
    if (accountId == null || accountId.isEmpty) {
      _accountId = null;
      _store = null;
      return null;
    }
    if (_accountId != accountId || _store == null) {
      _accountId = accountId;
      _store = _create(projectId, accountId);
    }
    return _store;
  }

  static FormsAnonymousEditSecretStore _createSharedPreferencesStore(
    String projectId,
    String accountId,
  ) => SharedPreferencesFormsAnonymousEditSecretStore(projectId: projectId, accountId: accountId);
}

final class FormsAnonymousEditSecretException implements Exception {
  const FormsAnonymousEditSecretException();

  String get message =>
      'Não foi possível guardar ou recuperar a edição anônima neste dispositivo. Tente novamente.';

  @override
  String toString() => message;
}

/// Device-only capability. The host partitions storage by project and account;
/// neither identifier contributes to the random secret or goes to the backend.
/// Store this object with the account's API composition, not as a global user store.
final class SharedPreferencesFormsAnonymousEditSecretStore
    implements FormsAnonymousEditSecretStore {
  SharedPreferencesFormsAnonymousEditSecretStore({
    required String projectId,
    required String accountId,
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences,
       _partition = sha256.convert(utf8.encode(jsonEncode([projectId, accountId]))).toString() {
    if (projectId.isEmpty || accountId.isEmpty) {
      throw ArgumentError('Anonymous response storage requires an account context.');
    }
  }

  final String _partition;
  SharedPreferencesAsync? _preferences;
  // Coalesce simultaneous opens in this runtime, including rebuilt host stores.
  static final _pending = <String, Future<String>>{};

  @override
  Future<String> loadOrCreate(String occurrenceId) {
    if (occurrenceId.isEmpty) throw const FormsAnonymousEditSecretException();
    final occurrence = sha256.convert(utf8.encode(occurrenceId));
    final key = 'coelo.forms.anonymous-edit.v1.$_partition.$occurrence';
    return _pending.putIfAbsent(
      key,
      () => _loadOrCreate(key).whenComplete(() {
        _pending.remove(key);
      }),
    );
  }

  Future<String> _loadOrCreate(String key) async {
    try {
      final store = _preferences ??= SharedPreferencesAsync();
      final saved = await store.getString(key);
      if (saved != null) {
        if (!_valid(saved)) throw const FormsAnonymousEditSecretException();
        return saved;
      }
      final random = Random.secure();
      final bytes = List<int>.generate(32, (_) => random.nextInt(256));
      final secret = base64Url.encode(bytes).replaceAll('=', '');
      bytes.fillRange(0, bytes.length, 0);
      await store.setString(key, secret);
      // Never open a response using an ephemeral fallback after a failed write.
      if (await store.getString(key) != secret) {
        throw const FormsAnonymousEditSecretException();
      }
      return secret;
    } on Object {
      // Storage/platform errors may contain keys and values. Do not propagate.
      throw const FormsAnonymousEditSecretException();
    }
  }

  bool _valid(String value) {
    if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(value)) return false;
    final bytes = base64Url.decode(base64Url.normalize(value));
    return bytes.length == 32 && base64Url.encode(bytes).replaceAll('=', '') == value;
  }
}
