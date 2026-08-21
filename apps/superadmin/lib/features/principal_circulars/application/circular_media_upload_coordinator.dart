import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../domain/circular.dart';
import '../domain/circular_repository.dart';
import 'circular_composer_controller.dart';

final class CircularSelectedFile {
  const CircularSelectedFile({
    required this.uploadRequestId,
    required this.name,
    required this.mimeType,
    required this.bytes,
  });

  final String uploadRequestId;
  final String name;
  final String mimeType;
  final Uint8List bytes;
}

final class CircularMediaUploadCoordinator {
  CircularMediaUploadCoordinator({
    required this.controller,
    required this.repository,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final CircularComposerController controller;
  final CircularMediaRepository repository;
  final http.Client _httpClient;

  Future<void> upload(CircularSelectedFile file) async {
    _validate(file);
    final saved = await controller.save();
    final requestId = file.uploadRequestId;
    final intent = await repository.prepare(
      requestId: requestId,
      institutionId: controller.scope.institutionId,
      circularId: saved.id,
      name: file.name,
      mimeType: file.mimeType,
      byteSize: file.bytes.length,
    );
    if (intent.uploadUrl case final uploadUrl?) {
      final response = await _httpClient.put(
        uploadUrl,
        headers: {...intent.requiredHeaders, 'content-type': file.mimeType},
        body: file.bytes,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const CircularUnavailable();
      }
    }
    await repository.finalize(
      requestId: requestId,
      finalizeRequestId: _uuid(),
      institutionId: controller.scope.institutionId,
      circularId: saved.id,
      intent: intent,
      name: file.name,
      mimeType: file.mimeType,
      byteSize: file.bytes.length,
      displayOrder: controller.draft.blocks
          .whereType<CircularMediaBlock>()
          .expand((block) => block.assetIds)
          .length,
    );
    controller.addMediaAsset(intent.assetId);
    await controller.save();
  }

  static void _validate(CircularSelectedFile file) {
    final maxBytes = switch (file.mimeType) {
      'image/jpeg' || 'image/png' || 'image/webp' => CircularLimits.imageBytes,
      'video/mp4' => CircularLimits.videoBytes,
      'application/pdf' => CircularLimits.pdfBytes,
      _ => 0,
    };
    if (file.bytes.isEmpty || file.bytes.length > maxBytes || maxBytes == 0) {
      throw const CircularInvalid('media_invalid');
    }
  }
}

String _uuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  String hex(int value) => value.toRadixString(16).padLeft(2, '0');
  final value = bytes.map(hex).join();
  return '${value.substring(0, 8)}-${value.substring(8, 12)}-${value.substring(12, 16)}-${value.substring(16, 20)}-${value.substring(20)}';
}
