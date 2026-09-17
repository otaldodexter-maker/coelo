import 'package:coelo_superadmin/features/safety/data/child_safety_response_decoder.dart';
import 'package:coelo_superadmin/features/safety/domain/child_safety_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('childSafetyPersonSearchReadiness (spec 055, ADR 0041 B5)', () {
    test('nome exige 3 caracteres', () {
      expect(childSafetyPersonSearchReadiness('An').ready, isFalse);
      expect(childSafetyPersonSearchReadiness('An').remaining, 1);
      final ready = childSafetyPersonSearchReadiness(' Ana ');
      expect(ready.ready, isTrue);
      expect(ready.kind, ChildSafetyPersonSearchKind.name);
    });

    test('@handle exige 3 caracteres depois do @', () {
      expect(childSafetyPersonSearchReadiness('@an').ready, isFalse);
      final ready = childSafetyPersonSearchReadiness('@ana');
      expect(ready.ready, isTrue);
      expect(ready.kind, ChildSafetyPersonSearchKind.handle);
    });

    test('e-mail e detectado pelo @ no meio', () {
      final ready = childSafetyPersonSearchReadiness('ana@x.test');
      expect(ready.ready, isTrue);
      expect(ready.kind, ChildSafetyPersonSearchKind.email);
    });

    test('digitos com ou sem mascara exigem 4 digitos', () {
      expect(childSafetyPersonSearchReadiness('(11) 9').ready, isFalse);
      expect(childSafetyPersonSearchReadiness('123').remaining, 1);
      final phone = childSafetyPersonSearchReadiness('99-1234');
      expect(phone.ready, isTrue);
      expect(phone.kind, ChildSafetyPersonSearchKind.digits);
      final cpf = childSafetyPersonSearchReadiness('111.444.777-35');
      expect(cpf.ready, isTrue);
      expect(cpf.kind, ChildSafetyPersonSearchKind.digits);
      expect(cpf.length, 11);
    });

    test('texto vazio nao esta pronto', () {
      expect(childSafetyPersonSearchReadiness('   ').ready, isFalse);
    });
  });

  group('decodeChildSafetyPersonMatches', () {
    test('le o resultado minimizado e as criancas vinculadas', () {
      final matches = decodeChildSafetyPersonMatches({
        'ok': true,
        'kind': 'name',
        'results': [
          {
            'person_id': 'p1',
            'display_name': 'Ana Maria',
            'initials': 'AM',
            'handle': '@ana',
            'phone_last4': '1234',
            'matched_by': 'name',
            'has_account': true,
            'children': [
              {
                'child_id': 'c1',
                'child_name': 'Ana Criança',
                'child_context_id': 'ctx1',
                'institution_id': 'i1',
                'institution_name': 'Aurora',
                'unit_id': 'u1',
                'unit_name': 'Centro',
              },
            ],
          },
        ],
      });
      expect(matches, hasLength(1));
      expect(matches.single.personId, 'p1');
      expect(matches.single.handle, '@ana');
      expect(matches.single.phoneLast4, '1234');
      expect(matches.single.hasAccount, isTrue);
      expect(matches.single.children.single.childContextId, 'ctx1');
      expect(matches.single.children.single.unitId, 'u1');
    });

    test('resultado sem identidade falha fechado', () {
      expect(
        () => decodeChildSafetyPersonMatches({
          'results': [
            {'display_name': 'Sem id'},
          ],
        }),
        throwsA(isA<ChildSafetyUnavailableException>()),
      );
    });

    test('envelope vazio devolve lista vazia', () {
      expect(decodeChildSafetyPersonMatches({'ok': true, 'results': <Object?>[]}), isEmpty);
    });
  });
}
