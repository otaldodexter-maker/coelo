import 'dart:typed_data';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_superadmin/features/forms/data/form_asset_uploader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('uploads bytes only to the backend-issued signed URL', () async {
    late http.BaseRequest captured;
    late Uint8List body;
    final client = _Client((request) async {
      captured = request;
      body = await request.finalize().toBytes();
      return http.StreamedResponse(const Stream.empty(), 200);
    });
    final uploader = FormAssetUploader(client: client);
    final progress = <double>[];

    await uploader.upload(
      ticket: FormAssetUploadTicket(
        assetId: 'asset-1',
        signedUploadUrl: Uri.parse(
          'https://storage.example.test/object/upload/sign/coelo-forms-private/opaque/image.webp?token=short-lived',
        ),
        expiresAt: DateTime.utc(2026, 8, 13, 15),
      ),
      bytes: Uint8List.fromList([1, 2, 3, 4]),
      mimeType: 'image/webp',
      now: DateTime.utc(2026, 8, 13, 14),
      onProgress: progress.add,
    );

    expect(captured.method, 'PUT');
    expect(captured.url.queryParameters['token'], 'short-lived');
    expect(captured.headers['content-type'], 'image/webp');
    expect(captured.headers, isNot(contains('authorization')));
    expect(body, [1, 2, 3, 4]);
    expect(progress, isNotEmpty);
    expect(progress.last, 1);
  });

  test('rejects unsupported, oversized, and expired uploads before network', () async {
    var calls = 0;
    final uploader = FormAssetUploader(
      client: _Client((_) async {
        calls++;
        return http.StreamedResponse(const Stream.empty(), 200);
      }),
    );
    final ticket = FormAssetUploadTicket(
      assetId: 'asset-1',
      signedUploadUrl: Uri.parse('https://storage.example.test/upload?token=x'),
      expiresAt: DateTime.utc(2026, 8, 13, 15),
    );

    expect(
      () => uploader.upload(
        ticket: ticket,
        bytes: Uint8List(1),
        mimeType: 'image/gif',
        now: DateTime.utc(2026, 8, 13, 14),
      ),
      throwsA(isA<FormAssetUploadException>()),
    );
    expect(
      () => uploader.upload(
        ticket: ticket,
        bytes: Uint8List(10 * 1024 * 1024 + 1),
        mimeType: 'image/jpeg',
        now: DateTime.utc(2026, 8, 13, 14),
      ),
      throwsA(isA<FormAssetUploadException>()),
    );
    expect(
      () => uploader.upload(
        ticket: ticket,
        bytes: Uint8List(1),
        mimeType: 'image/png',
        now: DateTime.utc(2026, 8, 13, 16),
      ),
      throwsA(isA<FormAssetUploadException>()),
    );
    expect(calls, 0);
  });

  test('surfaces storage rejection without exposing the signed URL', () async {
    final uploader = FormAssetUploader(
      client: _Client((_) async => http.StreamedResponse(const Stream.empty(), 403)),
    );

    expect(
      () => uploader.upload(
        ticket: FormAssetUploadTicket(
          assetId: 'asset-1',
          signedUploadUrl: Uri.parse('https://storage.example.test/upload?token=secret'),
          expiresAt: DateTime.utc(2026, 8, 13, 15),
        ),
        bytes: Uint8List(1),
        mimeType: 'image/png',
        now: DateTime.utc(2026, 8, 13, 14),
      ),
      throwsA(
        isA<FormAssetUploadException>().having(
          (error) => error.toString(),
          'safe error',
          isNot(contains('secret')),
        ),
      ),
    );
  });
}

final class _Client extends http.BaseClient {
  _Client(this.handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => handler(request);
}
