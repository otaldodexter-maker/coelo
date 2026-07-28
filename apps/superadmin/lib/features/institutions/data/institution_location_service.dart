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
  InstitutionLocationService({
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 8),
  }) : _client = client,
       _ownsClient = client == null;

  http.Client? _client;
  final bool _ownsClient;
  final Duration requestTimeout;
  http.Client get _httpClient => _client ??= http.Client();

  Future<InstitutionAddress> lookupPostalCode(String postalCode) async {
    if (!RegExp(r'^\d{8}$').hasMatch(postalCode)) {
      throw const InstitutionLocationException(InstitutionLocationErrorType.invalidPostalCode);
    }
    try {
      final response = await _httpClient
          .get(Uri.https('viacep.com.br', '/ws/$postalCode/json/'))
          .timeout(requestTimeout);
      if (response.statusCode != 200) {
        throw const InstitutionLocationException(InstitutionLocationErrorType.network);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const InstitutionLocationException(InstitutionLocationErrorType.network);
      }
      final data = decoded;
      if (data['erro'] == true) {
        throw const InstitutionLocationException(InstitutionLocationErrorType.postalCodeNotFound);
      }
      final municipality = data['localidade'];
      final state = data['uf'];
      if (municipality is! String || state is! String) {
        throw const InstitutionLocationException(InstitutionLocationErrorType.network);
      }
      return InstitutionAddress(
        street: data['logradouro'] is String ? data['logradouro'] as String : '',
        district: data['bairro'] is String ? data['bairro'] as String : '',
        municipality: municipality,
        state: state,
      );
    } on InstitutionLocationException {
      rethrow;
    } catch (_) {
      throw const InstitutionLocationException(InstitutionLocationErrorType.network);
    }
  }

  Future<List<String>> loadMunicipalities(String state) async {
    try {
      final response = await _httpClient
          .get(
            Uri.https('servicodados.ibge.gov.br', '/api/v1/localidades/estados/$state/municipios'),
          )
          .timeout(requestTimeout);
      if (response.statusCode != 200) {
        throw const InstitutionLocationException(InstitutionLocationErrorType.network);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List<dynamic>) {
        throw const InstitutionLocationException(InstitutionLocationErrorType.network);
      }
      final municipalities =
          decoded
              .whereType<Map<String, dynamic>>()
              .map((item) => item['nome'])
              .whereType<String>()
              .where((name) => name.trim().isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      if (decoded.isNotEmpty && municipalities.isEmpty) {
        throw const InstitutionLocationException(
          InstitutionLocationErrorType.network,
        );
      }
      return municipalities;
    } on InstitutionLocationException {
      rethrow;
    } catch (_) {
      throw const InstitutionLocationException(InstitutionLocationErrorType.network);
    }
  }

  void close() {
    if (_ownsClient) {
      _client?.close();
    }
  }
}
