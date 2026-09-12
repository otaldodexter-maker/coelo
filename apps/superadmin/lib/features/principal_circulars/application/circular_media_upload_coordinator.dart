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

  /// Client side convenience check. It never authorizes anything: the server
  /// re-validates MIME, signature, byte count and quota on prepare/finalize.
  bool get acceptedLocally =>
      CircularMediaLimits.mimeForFileName(name) == mimeType &&
      bytes.isNotEmpty &&
      bytes.length <= CircularMediaLimits.maxBytesFor(mimeType);
}

/// Media constraints of spec037 mirrored for fast local feedback. The numbers
/// come from [CircularLimits]; nothing is redefined here.
abstract final class CircularMediaLimits {
  static const acceptedExtensions = <String, String>{
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'mp4': 'video/mp4',
    'pdf': 'application/pdf',
  };

  static int maxBytesFor(String mimeType) => switch (mimeType) {
    'image/jpeg' || 'image/png' || 'image/webp' => CircularLimits.imageBytes,
    'video/mp4' => CircularLimits.videoBytes,
    'application/pdf' => CircularLimits.pdfBytes,
    _ => 0,
  };

  static String? mimeForFileName(String name) {
    final parts = name.toLowerCase().split('.');
    if (parts.length < 2) return null;
    return acceptedExtensions[parts.last];
  }

  static String newRequestId() => _uuid();
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

  Future<String> upload(CircularSelectedFile file, {String? afterBlockId}) async {
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
      // The R2 branch signs a short window (300s). Transferring against an
      // expired signature is reported as an expired window, never as success.
      if (intent.expiredAt(DateTime.now())) {
        throw const CircularInvalid('media_upload_expired');
      }
      final response = await _httpClient.put(
        uploadUrl,
        headers: {...intent.requiredHeaders, 'content-type': file.mimeType},
        body: file.bytes,
      );
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const CircularInvalid('media_upload_expired');
      }
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
    final blockId = controller.addMediaAsset(intent.assetId, afterBlockId: afterBlockId);
    if (blockId == null) throw const CircularInvalid('media_limit');
    await controller.save();
    return blockId;
  }

  static void _validate(CircularSelectedFile file) {
    final maxBytes = CircularMediaLimits.maxBytesFor(file.mimeType);
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
