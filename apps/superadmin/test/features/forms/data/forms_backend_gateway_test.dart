import 'package:coelo_superadmin/features/forms/data/forms_backend_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  // O gateway e o ponto unico de passagem de todas as chamadas de
  // Formularios, e o unico tipo de falha que ele declara e FormsBackendFailure.
  // Uma falha de TRANSPORTE — socket recusado, DNS, TLS, timeout — nao produz
  // PostgrestException nem FunctionException, entao escapava como excecao de
  // plataforma e cada consumidor precisava adivinhar o que fazer com ela.
  //
  // O endereco abaixo recusa conexao de imediato e nao usa rede externa.
  SupabaseFormsBackendGateway unreachable() =>
      SupabaseFormsBackendGateway(SupabaseClient('http://127.0.0.1:1', 'anon-key-for-test'));

  test('an rpc that never reaches the backend fails as a backend failure', () async {
    await expectLater(
      unreachable().rpc('form_get_editor', const {'p_form_id': 'form-1'}),
      throwsA(
        isA<FormsBackendFailure>().having((error) => error.code, 'code', 'transport'),
      ),
    );
  });

  test('a media call that never reaches the backend fails as a backend failure', () async {
    await expectLater(
      unreachable().media(const {'action': 'read', 'payload': <String, Object?>{}}),
      throwsA(
        isA<FormsBackendFailure>().having((error) => error.code, 'code', 'transport'),
      ),
    );
  });

  test('the failure never carries the address or the key it tried', () async {
    try {
      await unreachable().rpc('form_get_editor', const {'p_form_id': 'form-1'});
      fail('expected a FormsBackendFailure');
    } on FormsBackendFailure catch (error) {
      expect(error.message, isNot(contains('127.0.0.1')));
      expect(error.message, isNot(contains('anon-key')));
    }
  });
}
