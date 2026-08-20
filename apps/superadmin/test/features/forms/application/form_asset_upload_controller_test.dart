import 'dart:typed_data';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/features/forms/application/form_asset_upload_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prepares, uploads, and finalizes a private image', () async {
    final api = _Api();
    final uploader = _Uploader();
    final controller = FormAssetUploadController(
      api: api,
      uploadBytes: uploader.call,
      requestIdFactory: () => 'request-${api.commands.length + 1}',
    );

    final asset = await controller.upload(
      occurrenceId: 'occurrence-1',
      itemId: 'photo-1',
      bytes: Uint8List.fromList([1, 2, 3]),
      mimeType: 'image/png',
      editSecret: 'anonymous-secret',
    );

    expect(asset.id, 'asset-1');
    expect(uploader.ticket?.assetId, 'asset-1');
    expect(uploader.mimeType, 'image/png');
    expect(api.commands, ['prepare', 'finalize']);
    expect(api.preparePayload?.checksum, hasLength(64));
    expect(api.preparePayload?.editSecret, 'anonymous-secret');
    expect(api.finalizePayload?.editSecret, 'anonymous-secret');
    expect(api.expectedVersions, everyElement(0));
  });

  test('discards the prepared asset after an upload failure', () async {
    final api = _Api();
    final controller = FormAssetUploadController(
      api: api,
      uploadBytes: ({
        required ticket,
        required bytes,
        required mimeType,
        onProgress,
      }) async => throw StateError('network down'),
      requestIdFactory: () => 'request-${api.commands.length + 1}',
    );

    await expectLater(
      controller.upload(
        occurrenceId: 'occurrence-1',
        itemId: 'photo-1',
        bytes: Uint8List(1),
        mimeType: 'image/jpeg',
      ),
      throwsA(isA<FormAssetUploadFlowException>()),
    );
    expect(api.commands, ['prepare', 'discard']);
  });
}

final class _Uploader {
  FormAssetUploadTicket? ticket;
  String? mimeType;

  Future<void> call({
    required FormAssetUploadTicket ticket,
    required Uint8List bytes,
    required String mimeType,
    void Function(double progress)? onProgress,
  }) async {
    this.ticket = ticket;
    this.mimeType = mimeType;
    onProgress?.call(1);
  }
}

final class _Api implements FormsApi {
  final commands = <String>[];
  final expectedVersions = <int>[];
  FormAssetUploadPayload? preparePayload;
  FormAssetIdPayload? finalizePayload;

  @override
  Future<FormAssetUploadTicket> prepareAssetUpload(
    FormCommand<FormAssetUploadPayload> command,
  ) async {
    commands.add('prepare');
    expectedVersions.add(command.expectedVersion);
    preparePayload = command.payload;
    return FormAssetUploadTicket(
      assetId: 'asset-1',
      signedUploadUrl: Uri.parse('https://storage.example.test/upload?token=x'),
      expiresAt: DateTime.now().add(const Duration(minutes: 1)),
    );
  }

  @override
  Future<FormAsset> finalizeAssetUpload(FormCommand<FormAssetIdPayload> command) async {
    commands.add('finalize');
    expectedVersions.add(command.expectedVersion);
    finalizePayload = command.payload;
    return const FormAsset(
      id: 'asset-1',
      itemId: 'photo-1',
      mimeType: 'image/png',
      byteLength: 3,
    );
  }

  @override
  Future<void> discardAsset(FormCommand<FormAssetIdPayload> command) async {
    commands.add('discard');
    expectedVersions.add(command.expectedVersion);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
