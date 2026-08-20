import 'package:coelo_superadmin/features/forms/data/form_media_resolver.dart';
import 'package:coelo_superadmin/features/forms/data/forms_backend_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reauthorizes the asset and returns only a short-lived download URL', () async {
    final backend = _Backend({
      'signed_url': 'https://storage.example.test/object/sign/opaque?token=short-lived',
      'expires_in': 60,
    });
    final resolver = FormMediaResolver(
      backend: backend,
      requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
      now: () => DateTime.utc(2026, 8, 13, 14),
    );

    final ticket = await resolver.resolve(assetId: 'asset-1', editSecret: 'anonymous-secret');

    expect(backend.envelope?['action'], 'download');
    expect(backend.envelope?['expected_version'], 0);
    expect(backend.envelope?['payload'], {
      'asset_id': 'asset-1',
      'edit_secret': 'anonymous-secret',
    });
    expect(ticket.signedUrl.queryParameters['token'], 'short-lived');
    expect(ticket.expiresAt, DateTime.utc(2026, 8, 13, 14, 1));
  });

  test('maps backend denial without exposing its payload', () async {
    final resolver = FormMediaResolver(
      backend: _Backend.failure('42501'),
      requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
    );

    expect(
      resolver.resolve(assetId: 'another-tenant-asset'),
      throwsA(isA<FormMediaResolutionException>()),
    );
  });
}

final class _Backend implements FormsBackendGateway {
  _Backend(this.response) : failureCode = null;
  _Backend.failure(this.failureCode) : response = null;

  final Object? response;
  final String? failureCode;
  Map<String, Object?>? envelope;

  @override
  Future<Object?> media(Map<String, Object?> envelope) async {
    this.envelope = envelope;
    if (failureCode case final code?) {
      throw FormsBackendFailure(code: code, message: 'sensitive backend details');
    }
    return response;
  }

  @override
  Future<Object?> rpc(String functionName, Map<String, Object?> parameters) =>
      throw UnimplementedError();
}
