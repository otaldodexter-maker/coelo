import 'package:coelo_superadmin/features/forms/data/form_export_download_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reauthorizes a job and accepts only a future HTTPS ticket', () async {
    final gateway = _Gateway({
      'download_url': 'https://storage.example.test/object/sign/private?token=short',
      'expires_at': '2026-08-20T15:05:00Z',
    });
    final resolver = FormExportDownloadResolver(
      gateway: gateway,
      now: () => DateTime.utc(2026, 8, 20, 15),
    );

    final ticket = await resolver.resolve('11111111-1111-4111-8111-111111111111');

    expect(gateway.jobId, '11111111-1111-4111-8111-111111111111');
    expect(ticket.downloadUrl.scheme, 'https');
    expect(ticket.expiresAt, DateTime.utc(2026, 8, 20, 15, 5));
  });

  test('fails closed for IDOR, insecure URL and expired tickets', () async {
    for (final gateway in <FormExportDownloadGateway>[
      _Gateway.failure(),
      _Gateway({
        'download_url': 'http://storage.example.test/private',
        'expires_at': '2026-08-20T15:05:00Z',
      }),
      _Gateway({
        'download_url': 'https://storage.example.test/private',
        'expires_at': '2026-08-20T14:59:59Z',
      }),
    ]) {
      final resolver = FormExportDownloadResolver(
        gateway: gateway,
        now: () => DateTime.utc(2026, 8, 20, 15),
      );
      expect(
        resolver.resolve('22222222-2222-4222-8222-222222222222'),
        throwsA(isA<FormExportDownloadUnavailable>()),
      );
    }
  });

  test('rejects a service-only storage path without a public download URL', () async {
    final resolver = FormExportDownloadResolver(
      gateway: _Gateway({
        'storage_path': 'aa/11111111-1111-4111-8111-111111111111',
        'expires_at': '2026-08-20T15:05:00Z',
      }),
      now: () => DateTime.utc(2026, 8, 20, 15),
    );

    await expectLater(
      resolver.resolve('11111111-1111-4111-8111-111111111111'),
      throwsA(isA<FormExportDownloadUnavailable>()),
    );
  });
}

final class _Gateway implements FormExportDownloadGateway {
  _Gateway(this.response) : fails = false;
  _Gateway.failure() : response = null, fails = true;

  final Object? response;
  final bool fails;
  String? jobId;

  @override
  Future<Object?> resolve(String jobId) async {
    this.jobId = jobId;
    if (fails) throw StateError('sensitive backend details');
    return response;
  }
}
