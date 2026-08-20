import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/meal_plan_image_repository.dart';

final class SupabaseMealPlanImageRepository implements MealPlanImageRepository {
  const SupabaseMealPlanImageRepository(this._client);

  static const maxImageBytes = 2 * 1024 * 1024;
  static const signedReadTtlSeconds = 300;
  static const allowedMimeTypes = <String>{'image/jpeg', 'image/png', 'image/webp'};

  final SupabaseClient _client;

  @override
  Future<MealPlanImageAsset> upload(MealPlanImageUploadRequest request) async {
    final mimeType = _validateUpload(request);

    try {
      final prepared = _asMap(
        await _client.rpc<Object?>(
          'meal_plan_prepare_image_upload',
          params: {
            'p_resource_kind': request.resource.kind.databaseValue,
            'p_resource_id': request.resource.id,
            'p_file_name': request.fileName.trim(),
            'p_mime_type': mimeType,
            'p_size_bytes': request.bytes.lengthInBytes,
            'p_alt_text': _nullIfEmpty(request.altText),
            'p_idempotency_key': _required(request.requestId, 'requestId'),
          },
        ),
      );

      final intent = _intentFromJson(prepared);
      if (intent.mimeType != mimeType || request.bytes.lengthInBytes > intent.maxBytes) {
        throw const MealPlanImageValidationException(
          'O arquivo nao atende aos limites autorizados para este upload.',
        );
      }
      if (!intent.expiresAt.isAfter(DateTime.now().toUtc())) {
        throw const MealPlanImageConflictException();
      }

      final storage = _client.storage.from(intent.bucket);
      final signedUpload = await storage.createSignedUploadUrl(intent.path);
      await storage.uploadBinaryToSignedUrl(
        intent.path,
        signedUpload.token,
        request.bytes,
        FileOptions(contentType: mimeType, upsert: false),
      );

      final checksum = sha256.convert(request.bytes).toString();
      final finalized = _asMap(
        await _client.rpc<Object?>(
          'meal_plan_finalize_image_upload',
          params: {
            'p_request_id': _required(request.requestId, 'requestId'),
            'p_checksum_sha256': checksum,
            'p_alt_text': _nullIfEmpty(request.altText),
            'p_replace_asset_id': _nullIfEmpty(request.replaceAssetId),
          },
        ),
      );

      return _assetFromJson(finalized, fallbackChecksum: checksum);
    } on MealPlanImageException {
      rethrow;
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    } on StorageException catch (error) {
      throw _mapStorageError(error);
    } on FormatException {
      throw const MealPlanImageUnavailableException();
    }
  }

  @override
  Future<Uri> createSignedReadUrl(String assetId) async {
    try {
      final descriptor = _descriptorFromJson(
        _asMap(
          await _client.rpc<Object?>(
            'meal_plan_image_download_descriptor',
            params: {'p_asset_id': _required(assetId, 'assetId')},
          ),
        ),
      );
      final ttl = descriptor.signedUrlTtlSeconds.clamp(1, signedReadTtlSeconds);
      final signedUrl = await _client.storage
          .from(descriptor.bucket)
          .createSignedUrl(descriptor.path, ttl);
      return Uri.parse(signedUrl);
    } on MealPlanImageException {
      rethrow;
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    } on StorageException catch (error) {
      throw _mapStorageError(error);
    } on FormatException {
      throw const MealPlanImageUnavailableException();
    }
  }

  @override
  Future<void> delete({required String assetId, required String requestId}) async {
    try {
      await _client.rpc<Object?>(
        'meal_plan_request_image_delete',
        params: {
          'p_asset_id': _required(assetId, 'assetId'),
          'p_idempotency_key': _required(requestId, 'requestId'),
        },
      );
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    }
  }
}

String _validateUpload(MealPlanImageUploadRequest request) {
  _required(request.resource.id, 'resourceId');
  final fileName = _required(request.fileName, 'fileName').toLowerCase();
  final declaredMime = _required(request.mimeType, 'mimeType').toLowerCase();
  final inferredMime = _mimeTypeForFileName(fileName);

  if (!SupabaseMealPlanImageRepository.allowedMimeTypes.contains(declaredMime) ||
      declaredMime != inferredMime) {
    throw const MealPlanImageValidationException(
      'Use uma imagem JPEG, PNG ou WebP com extensao e formato correspondentes.',
    );
  }
  if (request.bytes.isEmpty) {
    throw const MealPlanImageValidationException('A imagem esta vazia.');
  }
  if (request.bytes.lengthInBytes > SupabaseMealPlanImageRepository.maxImageBytes) {
    throw const MealPlanImageValidationException('A imagem deve ter no maximo 2 MiB.');
  }
  _validateMagicBytes(request.bytes, declaredMime);
  return declaredMime;
}

String _mimeTypeForFileName(String fileName) {
  if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg')) return 'image/jpeg';
  if (fileName.endsWith('.png')) return 'image/png';
  if (fileName.endsWith('.webp')) return 'image/webp';
  throw const MealPlanImageValidationException(
    'Use um arquivo com extensao .jpg, .jpeg, .png ou .webp.',
  );
}

void _validateMagicBytes(Uint8List bytes, String mimeType) {
  final valid = switch (mimeType) {
    'image/jpeg' => bytes.length >= 3 && bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff,
    'image/png' =>
      bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4e &&
          bytes[3] == 0x47 &&
          bytes[4] == 0x0d &&
          bytes[5] == 0x0a &&
          bytes[6] == 0x1a &&
          bytes[7] == 0x0a,
    'image/webp' =>
      bytes.length >= 12 &&
          bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46 &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50,
    _ => false,
  };
  if (!valid) {
    throw const MealPlanImageValidationException(
      'O conteudo do arquivo nao corresponde ao formato informado.',
    );
  }
}

MealPlanImageUploadIntent _intentFromJson(Map<String, dynamic> json) => MealPlanImageUploadIntent(
  assetId: _string(json, 'asset_id'),
  bucket: _string(json, 'bucket'),
  path: _string(json, 'path'),
  mimeType: _string(json, 'mime_type').toLowerCase(),
  maxBytes: _integer(json, 'max_bytes'),
  expiresAt: DateTime.parse(_string(json, 'expires_at')).toUtc(),
);

MealPlanImageAsset _assetFromJson(Map<String, dynamic> json, {required String fallbackChecksum}) =>
    MealPlanImageAsset(
      id: _string(json, 'id', fallbackKey: 'asset_id'),
      bucket: _string(json, 'storage_bucket', fallbackKey: 'bucket'),
      path: _string(json, 'storage_path', fallbackKey: 'path'),
      mimeType: _string(json, 'mime_type'),
      sizeBytes: _integer(json, 'size_bytes'),
      checksumSha256: _optionalString(json['checksum_sha256']) ?? fallbackChecksum,
      altText: _optionalString(json['alt_text']),
    );

MealPlanImageDownloadDescriptor _descriptorFromJson(Map<String, dynamic> json) =>
    MealPlanImageDownloadDescriptor(
      bucket: _string(json, 'bucket'),
      path: _string(json, 'path'),
      signedUrlTtlSeconds:
          (json['signed_url_ttl_seconds'] as num?)?.toInt() ??
          SupabaseMealPlanImageRepository.signedReadTtlSeconds,
    );

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const MealPlanImageUnavailableException();
}

String _string(Map<String, dynamic> json, String key, {String? fallbackKey}) {
  final value =
      _optionalString(json[key]) ??
      (fallbackKey == null ? null : _optionalString(json[fallbackKey]));
  if (value == null) throw const MealPlanImageUnavailableException();
  return value;
}

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toInt();
  throw const MealPlanImageUnavailableException();
}

String _required(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw MealPlanImageValidationException('$field e obrigatorio.');
  }
  return normalized;
}

String? _nullIfEmpty(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String? _optionalString(Object? value) {
  final normalized = value?.toString().trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

MealPlanImageException _mapPostgrestError(PostgrestException error) => switch (error.code) {
  '42501' || 'PGRST301' => const MealPlanImageUnauthorizedException(),
  '23505' || '409' => const MealPlanImageConflictException(),
  '22023' || '23514' || 'P0001' => MealPlanImageValidationException(error.message),
  _ => const MealPlanImageUnavailableException(),
};

MealPlanImageException _mapStorageError(StorageException error) {
  final statusCode = int.tryParse(error.statusCode ?? '');
  return switch (statusCode) {
    401 || 403 => const MealPlanImageUnauthorizedException(),
    409 => const MealPlanImageConflictException(),
    _ => const MealPlanImageUnavailableException(),
  };
}
