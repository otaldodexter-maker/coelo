import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../../support/activities/a01_local_runtime_config.dart';

void main() {
  test('requires explicit local runtime opt-in', () {
    expect(() => A01LocalRuntimeConfig.fromEnvironment({}), throwsFormatException);
  });
  for (final value in [
    '',
    'https://example.supabase.co',
    'http://localhost:54321',
    'http://127.0.0.1',
    'http://127.0.0.1:80',
    'https://127.0.0.1:54321',
    'http://127.0.0.1:54321/rest/v1',
    'http://user:pass@127.0.0.1:54321',
    'http://127.0.0.1:54321?remote=x',
    'http://127.0.0.1:54321#fragment',
  ]) {
    test('rejects unsafe origin $value', () {
      expect(() => A01LocalRuntimeConfig.validateOrigin(value), throwsFormatException);
    });
  }
  test('accepts exact loopback with explicit unprivileged port', () {
    expect(
      A01LocalRuntimeConfig.validateOrigin('http://127.0.0.1:54321/').toString(),
      'http://127.0.0.1:54321',
    );
  });
  test('validates synthetic actor and session without authenticating locally', () {
    final claims = <String, Object?>{
      'sub': A01LocalRuntimeConfig.id(102),
      'session_id': A01LocalRuntimeConfig.id(202),
      'role': 'authenticated',
      'aal': 'aal2',
      'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 300,
    };
    String token(Map<String, Object?> value) =>
        'test.${base64Url.encode(utf8.encode(jsonEncode(value)))}.test';
    expect(() => A01LocalRuntimeConfig.validateActorToken(token(claims), 102), returnsNormally);
    for (final mutation in [
      {'sub': A01LocalRuntimeConfig.id(101)},
      {'session_id': A01LocalRuntimeConfig.id(201)},
      {'role': 'service_role'},
      {'aal': 'aal1'},
      {'exp': 1},
    ]) {
      expect(
        () => A01LocalRuntimeConfig.validateActorToken(token({...claims, ...mutation}), 102),
        throwsFormatException,
      );
    }
  });
}
