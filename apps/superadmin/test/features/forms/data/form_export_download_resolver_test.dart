import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_superadmin/features/forms/data/form_export_download_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('malformed job ids never reach the gateway', () async {
    for (final id in ['', '../job', '11111111-1111-4111-8111-111111111111 ']) {
      final gateway = _Gateway(null);
      final resolver = FormExportDownloadResolver(gateway: gateway, session: MediaSession());
      await expectLater(resolver.resolve(id), throwsA(isA<FormExportDownloadUnavailable>()));
      expect(gateway.jobId, isNull);
    }
  });

  test('session invalidation prevents a new download authorization', () async {
    final session = MediaSession();
    final gateway = _Gateway(null);
    await session.invalidate();
    final resolver = FormExportDownloadResolver(gateway: gateway, session: session);
    await expectLater(
      resolver.resolve('11111111-1111-4111-8111-111111111111'),
      throwsA(isA<FormExportDownloadUnavailable>()),
    );
    expect(gateway.jobId, isNull);
  });

  test('late authorization after session invalidation cannot return a ticket', () async {
    final session = MediaSession();
    final gateway = _PendingGateway();
    final resolver = FormExportDownloadResolver(
      gateway: gateway,
      session: session,
      now: () => DateTime.utc(2026, 8, 20, 15),
    );
    final pending = resolver.resolve('11111111-1111-4111-8111-111111111111');
    await session.invalidate();
    gateway.completion.complete({
      'job_id': '11111111-1111-4111-8111-111111111111',
      'download_url': 'https://media.example.test/export?ticket=synthetic',
      'expires_at': '2026-08-20T15:05:00Z',
    });
    await expectLater(pending, throwsA(isA<FormExportDownloadUnavailable>()));
  });

  for (final invalidate in [true, false]) {
    test('ticket releases its capability on ${invalidate ? 'invalidation' : 'dispose'}', () async {
      final session = MediaSession();
      final resolver = FormExportDownloadResolver(
        session: session,
        now: () => DateTime.utc(2026, 8, 20, 15),
        gateway: _Gateway({
          'download_url': 'https://media.example.test/export?ticket=synthetic',
          'expires_at': '2026-08-20T15:05:00Z',
        }),
      );
      final ticket = await resolver.resolve('11111111-1111-4111-8111-111111111111');
      expect(ticket.downloadUrl.host, 'media.example.test');
      expect(ticket.toString(), isNot(contains('synthetic')));
      if (invalidate) {
        await session.invalidate();
      } else {
        ticket.dispose();
      }
      expect(() => ticket.downloadUrl, throwsA(isA<FormExportDownloadUnavailable>()));
      ticket.dispose();
      await session.invalidate();
    });
  }

  test('expired ticket cannot be used after it was resolved', () async {
    var now = DateTime.utc(2026, 8, 20, 15);
    final resolver = FormExportDownloadResolver(
      session: MediaSession(),
      gateway: _Gateway({
        'download_url': 'https://media.example.test/export?ticket=synthetic',
        'expires_at': '2026-08-20T15:05:00Z',
      }),
      now: () => now,
    );
    final ticket = await resolver.resolve('11111111-1111-4111-8111-111111111111');
    now = DateTime.utc(2026, 8, 20, 15, 5);
    expect(() => ticket.downloadUrl, throwsA(isA<FormExportDownloadUnavailable>()));
  });

  for (final job in [null, '22222222-2222-4222-8222-222222222222']) {
    test('rejects a download receipt with job correlation $job', () async {
      final resolver = FormExportDownloadResolver(
        session: MediaSession(),
        gateway: _Gateway({
          'job_id': job,
          'download_url': 'https://media.example.test/export?ticket=synthetic',
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

  for (final expiry in [
    '2026-08-20T15:05:00.001Z',
    '2027-08-20T15:00:00Z',
    '2026-08-20T15:04:00',
    '2026-08-20',
    '2026-08-20T15:04:00Z ',
    '2026-08-19T39:04:00Z',
  ]) {
    test('rejects an invalid or overlong download expiry $expiry', () async {
      final resolver = FormExportDownloadResolver(
        session: MediaSession(),
        gateway: _Gateway({
          'download_url': 'https://media.example.test/export?ticket=synthetic',
          'expires_at': expiry,
        }),
        now: () => DateTime.utc(2026, 8, 20, 15),
      );
      await expectLater(
        resolver.resolve('11111111-1111-4111-8111-111111111111'),
        throwsA(isA<FormExportDownloadUnavailable>()),
      );
    });
  }

  for (final value in <Object?>[
    'https:relative-path',
    'https:///missing-host',
    'https://user:password@media.example.test/export',
    'https://media.example.test/export#fragment',
    42,
    null,
    'https://media.example.test/export?ticket=two words',
    'https://media.example.test/export?ticket=synthetic\n',
  ]) {
    test('rejects a malformed download capability: $value', () async {
      final resolver = FormExportDownloadResolver(
        session: MediaSession(),
        gateway: _Gateway({'download_url': value, 'expires_at': '2026-08-20T15:05:00Z'}),
        now: () => DateTime.utc(2026, 8, 20, 15),
      );
      await expectLater(
        resolver.resolve('11111111-1111-4111-8111-111111111111'),
        throwsA(isA<FormExportDownloadUnavailable>()),
      );
    });
  }

  test('rejects a ticket at the exact expiration boundary', () async {
    final resolver = FormExportDownloadResolver(
      session: MediaSession(),
      gateway: _Gateway({
        'download_url': 'https://media.example.test/export?ticket=synthetic',
        'expires_at': '2026-08-20T15:00:00Z',
      }),
      now: () => DateTime.utc(2026, 8, 20, 15),
    );
    await expectLater(
      resolver.resolve('11111111-1111-4111-8111-111111111111'),
      throwsA(isA<FormExportDownloadUnavailable>()),
    );
  });

  test('reauthorizes a job and accepts only a future HTTPS ticket', () async {
    final gateway = _Gateway({
      'download_url': 'https://storage.example.test/object/sign/private?token=short',
      'expires_at': '2026-08-20T15:05:00Z',
    });
    final resolver = FormExportDownloadResolver(
      session: MediaSession(),
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
        session: MediaSession(),
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
      session: MediaSession(),
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
    return response is Map ? {'job_id': jobId, ...response as Map} : response;
  }
}

final class _PendingGateway implements FormExportDownloadGateway {
  final completion = Completer<Object?>();
  @override
  Future<Object?> resolve(String jobId) => completion.future;
}
