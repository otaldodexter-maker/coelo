import 'dart:async';
import 'dart:convert';

import 'package:coelo_superadmin/features/institutions/data/institution_location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('ViaCEP accepts exactly eight digits and maps the address', () async {
    final service = InstitutionLocationService(
      client: MockClient((request) async {
        expect(request.url.toString(), 'https://viacep.com.br/ws/01310100/json/');
        return http.Response(
          jsonEncode({
            'logradouro': 'Avenida Paulista',
            'bairro': 'Bela Vista',
            'localidade': 'São Paulo',
            'uf': 'SP',
          }),
          200,
        );
      }),
    );

    final address = await service.lookupPostalCode('01310100');

    expect(address.street, 'Avenida Paulista');
    expect(address.district, 'Bela Vista');
    expect(address.municipality, 'São Paulo');
    expect(address.state, 'SP');
    expect(
      () => service.lookupPostalCode('01310-100'),
      throwsA(
        isA<InstitutionLocationException>().having(
          (error) => error.type,
          'type',
          InstitutionLocationErrorType.invalidPostalCode,
        ),
      ),
    );
  });

  test('ViaCEP distinguishes an unknown postal code', () async {
    final service = InstitutionLocationService(
      client: MockClient((_) async => http.Response('{"erro": true}', 200)),
    );

    expect(
      () => service.lookupPostalCode('00000000'),
      throwsA(
        isA<InstitutionLocationException>().having(
          (error) => error.type,
          'type',
          InstitutionLocationErrorType.postalCodeNotFound,
        ),
      ),
    );
  });

  test('network and malformed responses use the network failure state', () async {
    final service = InstitutionLocationService(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );

    expect(
      () => service.lookupPostalCode('01310100'),
      throwsA(
        isA<InstitutionLocationException>().having(
          (error) => error.type,
          'type',
          InstitutionLocationErrorType.network,
        ),
      ),
    );
  });

  test('malformed JSON shapes never leak type errors', () async {
    final postalService = InstitutionLocationService(
      client: MockClient((_) async => http.Response('[]', 200)),
    );
    final municipalitiesService = InstitutionLocationService(
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    await expectLater(
      postalService.lookupPostalCode('01310100'),
      throwsA(
        isA<InstitutionLocationException>().having(
          (error) => error.type,
          'type',
          InstitutionLocationErrorType.network,
        ),
      ),
    );
    await expectLater(
      municipalitiesService.loadMunicipalities('SP'),
      throwsA(
        isA<InstitutionLocationException>().having(
          (error) => error.type,
          'type',
          InstitutionLocationErrorType.network,
        ),
      ),
    );
  });

  test('request timeout is injectable and maps to the network state', () async {
    final pendingResponse = Completer<http.Response>();
    final service = InstitutionLocationService(
      client: MockClient((_) => pendingResponse.future),
      requestTimeout: const Duration(milliseconds: 10),
    );

    await expectLater(
      service.lookupPostalCode('01310100'),
      throwsA(
        isA<InstitutionLocationException>().having(
          (error) => error.type,
          'type',
          InstitutionLocationErrorType.network,
        ),
      ),
    );
  });

  test('loads official IBGE municipalities for one state', () async {
    final service = InstitutionLocationService(
      client: MockClient((request) async {
        expect(
          request.url.toString(),
          'https://servicodados.ibge.gov.br/api/v1/localidades/estados/SP/municipios',
        );
        return http.Response(
          jsonEncode([
            {'nome': 'Santos'},
            {'nome': 'Campinas'},
          ]),
          200,
        );
      }),
    );

    expect(await service.loadMunicipalities('SP'), ['Campinas', 'Santos']);
  });
}
