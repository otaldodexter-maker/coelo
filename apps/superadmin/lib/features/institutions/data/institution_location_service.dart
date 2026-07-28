import 'dart:convert';

import 'package:http/http.dart' as http;

enum InstitutionLocationErrorType { invalidPostalCode, postalCodeNotFound, network }

final class InstitutionLocationException implements Exception {
  const InstitutionLocationException(this.type);

  final InstitutionLocationErrorType type;
}

final class InstitutionAddress {
  const InstitutionAddress({
    required this.street,
    required this.district,
    required this.municipality,
    required this.state,
  });

  final String street;
  final String district;
  final String municipality;
  final String state;
}

final class InstitutionLocationService {
  InstitutionLocationService({http.Client? client})
    : _client = client,
      _ownsClient = client == null;

  http.Client? _client;
  final bool _ownsClient;
  http.Client get _httpClient => _client ??= http.Client();

  Future<InstitutionAddress> lookupPostalCode(String postalCode) async {
    if (!RegExp(r'^\d{8}$').hasMatch(postalCode)) {
      throw const InstitutionLocationException(InstitutionLocationErrorType.invalidPostalCode);
    }
    try {
      final response = await _httpClient.get(Uri.https('viacep.com.br', '/ws/$postalCode/json/'));
      if (response.statusCode != 200) {
        throw const InstitutionLocationException(InstitutionLocationErrorType.network);
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['erro'] == true) {
        throw const InstitutionLocationException(InstitutionLocationErrorType.postalCodeNotFound);
      }
      return InstitutionAddress(
        street: data['logradouro'] as String? ?? '',
        district: data['bairro'] as String? ?? '',
        municipality: data['localidade'] as String? ?? '',
        state: data['uf'] as String? ?? '',
      );
    } on InstitutionLocationException {
      rethrow;
    } on Exception {
      throw const InstitutionLocationException(InstitutionLocationErrorType.network);
    }
  }

  Future<List<String>> loadMunicipalities(String state) async {
    try {
      final response = await _httpClient.get(
        Uri.https('servicodados.ibge.gov.br', '/api/v1/localidades/estados/$state/municipios'),
      );
      if (response.statusCode != 200) {
        throw const InstitutionLocationException(InstitutionLocationErrorType.network);
      }
      final data = jsonDecode(response.body) as List<dynamic>;
      final municipalities =
          data.map((item) => (item as Map<String, dynamic>)['nome'] as String).toSet().toList()
            ..sort();
      return municipalities;
    } on InstitutionLocationException {
      rethrow;
    } on Exception {
      throw const InstitutionLocationException(InstitutionLocationErrorType.network);
    }
  }

  void close() {
    if (_ownsClient) {
      _client?.close();
    }
  }
}
