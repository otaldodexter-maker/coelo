import 'dart:typed_data';

enum MealPlanImageResourceKind {
  mealPlan('meal_plan'),
  template('template');

  const MealPlanImageResourceKind(this.databaseValue);

  final String databaseValue;
}

final class MealPlanImageResource {
  const MealPlanImageResource._({required this.kind, required this.id});

  const MealPlanImageResource.mealPlan(String id)
    : this._(kind: MealPlanImageResourceKind.mealPlan, id: id);

  const MealPlanImageResource.template(String id)
    : this._(kind: MealPlanImageResourceKind.template, id: id);

  final MealPlanImageResourceKind kind;
  final String id;
}

final class MealPlanImageUploadRequest {
  const MealPlanImageUploadRequest({
    required this.resource,
    required this.fileName,
    required this.mimeType,
    required this.bytes,
    required this.requestId,
    this.mealEntryId,
    this.altText,
    this.replaceAssetId,
  });

  final MealPlanImageResource resource;
  final String fileName;
  final String mimeType;
  final Uint8List bytes;
  final String requestId;
  final String? mealEntryId;
  final String? altText;
  final String? replaceAssetId;
}

final class MealPlanImageUploadIntent {
  const MealPlanImageUploadIntent({
    required this.assetId,
    required this.bucket,
    required this.path,
    required this.mimeType,
    required this.maxBytes,
    required this.expiresAt,
  });

  final String assetId;
  final String bucket;
  final String path;
  final String mimeType;
  final int maxBytes;
  final DateTime expiresAt;
}

final class MealPlanImageAsset {
  const MealPlanImageAsset({
    required this.id,
    required this.bucket,
    required this.path,
    required this.mimeType,
    required this.sizeBytes,
    required this.checksumSha256,
    this.altText,
  });

  final String id;
  final String bucket;
  final String path;
  final String mimeType;
  final int sizeBytes;
  final String checksumSha256;
  final String? altText;
}

final class MealPlanImageDownloadDescriptor {
  const MealPlanImageDownloadDescriptor({
    required this.bucket,
    required this.path,
    required this.signedUrlTtlSeconds,
  });

  final String bucket;
  final String path;
  final int signedUrlTtlSeconds;
}

abstract interface class MealPlanImageRepository {
  Future<MealPlanImageAsset> upload(MealPlanImageUploadRequest request);

  Future<Uri> createSignedReadUrl(String assetId);

  Future<void> delete({required String assetId, required String requestId});
}

sealed class MealPlanImageException implements Exception {
  const MealPlanImageException();
}

final class MealPlanImageValidationException extends MealPlanImageException {
  const MealPlanImageValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class MealPlanImageUnauthorizedException extends MealPlanImageException {
  const MealPlanImageUnauthorizedException();
}

final class MealPlanImageConflictException extends MealPlanImageException {
  const MealPlanImageConflictException();
}

final class MealPlanImageUnavailableException extends MealPlanImageException {
  const MealPlanImageUnavailableException();
}
