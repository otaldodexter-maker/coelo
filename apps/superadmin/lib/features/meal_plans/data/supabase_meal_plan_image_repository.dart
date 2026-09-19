import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/meal_plan_image_repository.dart';
import '../../../shared/data/edge_media_bytes.dart';

/// Imagens de Cardapios pelo Media Gateway `meal-plan-media` (owner.r12-38,
/// spec 063, ADR 0032): prepare -> bytes pela Edge (ela grava no R2 e finaliza
/// com verificacao) -> leitura inline pela Edge (URL local `blob:`). O cliente
/// nunca ve bucket, chave nem URL assinada; a exclusao continua pela RPC
/// revisionada. [mediaClient] fica so por compatibilidade.
final class SupabaseMealPlanImageRepository implements MealPlanImageRepository {
  // ignore: avoid_unused_constructor_parameters
  const SupabaseMealPlanImageRepository(this._client, {http.Client? mediaClient});

  static const maxImageBytes = 2 * 1024 * 1024;
  static const signedReadTtlSeconds = 300;
  static const allowedMimeTypes = <String>{'image/jpeg', 'image/png', 'image/webp'};
  static const functionName = 'meal-plan-media';

  final SupabaseClient _client;

  @override
  Future<MealPlanImageAsset> upload(MealPlanImageUploadRequest request) async {
    final mimeType = _validateUpload(request);
    final requestId = _required(request.requestId, 'requestId');
    final prepared = await _mediaAction({
      'action': 'prepare',
      'request_id': requestId,
      'resource_kind': request.resource.kind.databaseValue,
      'resource_id': _required(request.resource.id, 'resourceId'),
      'file_name': request.fileName.trim(),
      'mime_type': mimeType,
      'size_bytes': request.bytes.lengthInBytes,
      'alt_text': _nullIfEmpty(request.altText),
    });
    final assetId = _string(prepared, 'asset_id');
    final maxBytes = (prepared['max_bytes'] as num?)?.toInt() ?? maxImageBytes;
    if (request.bytes.lengthInBytes > maxBytes) {
      throw const MealPlanImageValidationException(
        'O arquivo nao atende aos limites autorizados para este upload.',
      );
    }
    final Map<String, dynamic> finalized;
    try {
      finalized = await uploadBytesThroughEdge(
        _client,
        functionName,
        envelope: {
          'request_id': requestId,
          'alt_text': _nullIfEmpty(request.altText),
          'replace_asset_id': _nullIfEmpty(request.replaceAssetId),
        },
        bytes: request.bytes,
      );
    } on EdgeMediaException catch (error) {
      throw _mapEdge(error);
    }
    final asset = _assetFromJson(finalized);
    if (asset.id != assetId) throw const MealPlanImageUnavailableException();
    return asset;
  }

  @override
  Future<Uri> createSignedReadUrl(String assetId) async {
    // Bytes pela Edge (autorizacao no servidor); a URL devolvida e local.
    try {
      final bytes = await readBytesThroughEdge(_client, functionName, {
        'action': 'read',
        'asset_id': _required(assetId, 'assetId'),
      });
      return Uri.parse(mediaObjectUrl(bytes, sniffMediaMimeType(bytes, fallback: 'image/jpeg')));
    } on EdgeMediaException catch (error) {
      throw _mapEdge(error);
    }
  }

  MealPlanImageException _mapEdge(EdgeMediaException error) => switch (error.status) {
    401 || 403 => const MealPlanImageUnauthorizedException(),
    409 => const MealPlanImageConflictException(),
    422 => MealPlanImageValidationException(_errorMessage({'error': error.code})),
    _ => const MealPlanImageUnavailableException(),
  };

  @override
  Future<void> delete({
    required String assetId,
    required String requestId,
    required int expectedRevision,
  }) async {
    if (expectedRevision < 1) {
      throw const MealPlanImageValidationException('expectedRevision e obrigatorio.');
    }
    try {
      await _client.rpc<Object?>(
        'meal_plan_request_image_delete',
        params: {
          'p_asset_id': _required(assetId, 'assetId'),
          'p_idempotency_key': _required(requestId, 'requestId'),
          'p_expected_revision': expectedRevision,
        },
      );
    } on MealPlanImageException {
      rethrow;
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    } on Exception {
      throw const MealPlanImageUnavailableException();
    }
  }

  Future<Map<String, dynamic>> _mediaAction(Map<String, dynamic> body) async {
    try {
      final response = await _client.functions.invoke(functionName, body: body);
      if (response.status != 200 || response.data is! Map) {
        throw const MealPlanImageUnavailableException();
      }
      return Map<String, dynamic>.from(response.data as Map);
    } on MealPlanImageException {
      rethrow;
    } on FunctionException catch (error) {
      throw switch (error.status) {
        401 || 403 => const MealPlanImageUnauthorizedException(),
        409 => const MealPlanImageConflictException(),
        422 => MealPlanImageValidationException(_errorMessage(error.details)),
        _ => const MealPlanImageUnavailableException(),
      };
    } on Exception {
      // Falha de transporte vira indisponibilidade em vez de excecao crua na UI.
      throw const MealPlanImageUnavailableException();
    }
  }
}

String _errorMessage(Object? details) {
  final code = details is Map ? details['error']?.toString() : null;
  return switch (code) {
    'invalid_image_signature' => 'O conteudo do arquivo nao corresponde ao formato informado.',
    'image_upload_incomplete' => 'O envio da imagem nao foi concluido. Tente novamente.',
    _ => 'Nao foi possivel confirmar a imagem.',
  };
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

MealPlanImageAsset _assetFromJson(Map<String, dynamic> json) => MealPlanImageAsset(
  id: _string(json, 'id', fallbackKey: 'asset_id'),
  bucket: _string(json, 'storage_bucket', fallbackKey: 'bucket'),
  path: _string(json, 'storage_path', fallbackKey: 'path'),
  mimeType: _string(json, 'mime_type'),
  sizeBytes: _integer(json, 'size_bytes'),
  checksumSha256: _optionalString(json['checksum_sha256']) ?? '',
  revision: _integer(json, 'revision'),
  altText: _optionalString(json['alt_text']),
);


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
  '23505' || '409' || 'P0003' || 'PT409' => const MealPlanImageConflictException(),
  '22023' || '23514' || 'P0001' => MealPlanImageValidationException(error.message),
  _ => const MealPlanImageUnavailableException(),
};
