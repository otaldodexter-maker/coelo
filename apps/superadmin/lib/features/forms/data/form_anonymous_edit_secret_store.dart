import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

abstract interface class FormAnonymousEditSecretStore {
  String generate();
  Future<void> save({required String responseId, required String secret});
  Future<String?> read(String responseId);
  Future<void> bindOccurrence({required String occurrenceId, required String responseId});
  Future<String?> responseIdForOccurrence(String occurrenceId);
  Future<void> remove(String responseId);
}

final class SharedPreferencesFormAnonymousEditSecretStore implements FormAnonymousEditSecretStore {
  SharedPreferencesFormAnonymousEditSecretStore(this._preferences, {Random? secureRandom})
    : _secureRandom = secureRandom ?? Random.secure();

  static const _prefix = 'coelo.forms.anonymous-edit-secret.';
  static const _occurrencePrefix = 'coelo.forms.anonymous-response.';

  final SharedPreferences _preferences;
  final Random _secureRandom;

  @override
  String generate() {
    final bytes = List<int>.generate(32, (_) => _secureRandom.nextInt(256), growable: false);
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  @override
  Future<void> save({required String responseId, required String secret}) async {
    if (responseId.isEmpty || secret.length != 43) {
      throw const FormatException('Invalid anonymous response secret.');
    }
    final saved = await _preferences.setString('$_prefix$responseId', secret);
    if (!saved) throw StateError('Could not persist anonymous response secret.');
  }

  @override
  Future<String?> read(String responseId) =>
      Future.value(_preferences.getString('$_prefix$responseId'));

  @override
  Future<void> bindOccurrence({required String occurrenceId, required String responseId}) async {
    if (occurrenceId.isEmpty || responseId.isEmpty) {
      throw const FormatException('Invalid anonymous response binding.');
    }
    final saved = await _preferences.setString('$_occurrencePrefix$occurrenceId', responseId);
    if (!saved) throw StateError('Could not persist anonymous response binding.');
  }

  @override
  Future<String?> responseIdForOccurrence(String occurrenceId) =>
      Future.value(_preferences.getString('$_occurrencePrefix$occurrenceId'));

  @override
  Future<void> remove(String responseId) async {
    final removed = await _preferences.remove('$_prefix$responseId');
    if (!removed && _preferences.containsKey('$_prefix$responseId')) {
      throw StateError('Could not remove anonymous response secret.');
    }
  }
}
