import 'package:flutter/foundation.dart';

import 'circular.dart';

@immutable
final class CircularScope {
  const CircularScope({required this.institutionId, this.unitId, this.groupId, this.activityId});

  final String institutionId;
  final String? unitId;
  final String? groupId;
  final String? activityId;
}

@immutable
final class CircularCursor {
  const CircularCursor({required this.publishedAt, required this.itemId});

  final DateTime publishedAt;
  final String itemId;
}

@immutable
final class PrincipalCursorPage<T> {
  const PrincipalCursorPage({required this.items, required this.nextCursor});

  final List<T> items;
  final CircularCursor? nextCursor;
}

@immutable
final class CircularSummary {
  const CircularSummary({
    required this.id,
    required this.title,
    required this.excerpt,
    required this.authorName,
    required this.contextLabel,
    required this.publishedAt,
    required this.attachmentCount,
    required this.questionCount,
    required this.responseState,
    this.revisedAt,
  });

  final String id;
  final String title;
  final String excerpt;
  final String authorName;
  final String contextLabel;
  final DateTime publishedAt;
  final DateTime? revisedAt;
  final int attachmentCount;
  final int questionCount;
  final CircularResponseState responseState;
}

@immutable
final class CircularSaveResult {
  const CircularSaveResult({
    required this.id,
    required this.revisionId,
    required this.version,
    required this.status,
  });

  final String id;
  final String revisionId;
  final int version;
  final CircularStatus status;
}

@immutable
final class CircularDetail {
  const CircularDetail({
    required this.id,
    required this.revisionId,
    required this.title,
    required this.authorName,
    required this.contextLabel,
    required this.publishedAt,
    required this.blocks,
    required this.status,
    required this.responseState,
    this.initialAnswers = const {},
    this.responseSessionId,
    this.responseVersion = 0,
    this.revisedAt,
    this.responsesCloseAt,
  });

  final String id;
  final String revisionId;
  final String title;
  final String authorName;
  final String contextLabel;
  final DateTime publishedAt;
  final DateTime? revisedAt;
  final DateTime? responsesCloseAt;
  final List<CircularBlock> blocks;
  final CircularStatus status;
  final CircularResponseState responseState;
  final Map<String, List<String>> initialAnswers;
  final String? responseSessionId;
  final int responseVersion;
}

abstract interface class CircularRepository {
  Future<CircularDraft?> loadDraft(CircularScope scope);

  Future<CircularSaveResult> saveDraft({
    required String requestId,
    required CircularScope scope,
    required CircularDraft draft,
  });

  Future<CircularSaveResult> publish({
    required String requestId,
    required String circularId,
    required int expectedVersion,
    DateTime? publishAt,
  });

  Future<PrincipalCursorPage<CircularSummary>> listProfile(
    CircularScope scope, {
    CircularCursor? cursor,
    int limit = 20,
  });

  Future<CircularDetail> getVisible(String circularId, {String? childContextId});

  Future<CircularSaveResult> closeResponses({
    required String requestId,
    required String circularId,
    required int expectedVersion,
  });
}

/// Honest composition fallback used when no Circular backend capability is
/// available. It never persists, publishes, or returns tenant data locally.
final class UnavailableCircularRepository implements CircularRepository {
  const UnavailableCircularRepository();

  Future<T> _unavailable<T>() => Future<T>.error(const CircularUnavailable());

  @override
  Future<CircularDetail> getVisible(String circularId, {String? childContextId}) => _unavailable();

  @override
  Future<CircularDraft?> loadDraft(CircularScope scope) => _unavailable();

  @override
  Future<PrincipalCursorPage<CircularSummary>> listProfile(
    CircularScope scope, {
    CircularCursor? cursor,
    int limit = 20,
  }) => _unavailable();

  @override
  Future<CircularSaveResult> publish({
    required String requestId,
    required String circularId,
    required int expectedVersion,
    DateTime? publishAt,
  }) => _unavailable();

  @override
  Future<CircularSaveResult> saveDraft({
    required String requestId,
    required CircularScope scope,
    required CircularDraft draft,
  }) => _unavailable();

  @override
  Future<CircularSaveResult> closeResponses({
    required String requestId,
    required String circularId,
    required int expectedVersion,
  }) => _unavailable();
}

abstract interface class CircularResponseRepository {
  Future<CircularResponseSaveResult> saveDraft({
    required String requestId,
    required String revisionId,
    required String? childContextId,
    required Map<String, List<String>> answers,
    required int expectedVersion,
  });

  Future<CircularResponseSaveResult> submit({
    required String requestId,
    required String sessionId,
    required int expectedVersion,
  });
}

/// Honest fallback used when the response capability is not available.
final class UnavailableCircularResponseRepository implements CircularResponseRepository {
  const UnavailableCircularResponseRepository();

  Future<T> _unavailable<T>() => Future<T>.error(const CircularUnavailable());

  @override
  Future<CircularResponseSaveResult> saveDraft({
    required String requestId,
    required String revisionId,
    required String? childContextId,
    required Map<String, List<String>> answers,
    required int expectedVersion,
  }) => _unavailable();

  @override
  Future<CircularResponseSaveResult> submit({
    required String requestId,
    required String sessionId,
    required int expectedVersion,
  }) => _unavailable();
}

@immutable
final class CircularResponseSaveResult {
  const CircularResponseSaveResult({
    required this.sessionId,
    required this.version,
    required this.state,
  });

  final String sessionId;
  final int version;
  final CircularResponseState state;
}

abstract interface class CircularMediaRepository {
  Future<CircularMediaUploadIntent> prepare({
    required String requestId,
    required String institutionId,
    required String circularId,
    required String name,
    required String mimeType,
    required int byteSize,
  });

  Future<void> finalize({
    required String requestId,
    required String finalizeRequestId,
    required String institutionId,
    required String circularId,
    required CircularMediaUploadIntent intent,
    required String name,
    required String mimeType,
    required int byteSize,
    required int displayOrder,
    String? checksumSha256,
  });

  Future<Uri> resolveRead(String assetId);

  Future<void> remove(String assetId);
}

@immutable
final class CircularMediaUploadIntent {
  const CircularMediaUploadIntent({
    required this.assetId,
    required this.uploadUrl,
    required this.requiredHeaders,
    required this.expiresAt,
  });

  final String assetId;
  final Uri? uploadUrl;
  final Map<String, String> requiredHeaders;
  final DateTime expiresAt;

  bool get alreadyUploaded => uploadUrl == null;
}

sealed class CircularFailure implements Exception {
  const CircularFailure();
}

final class CircularUnauthorized extends CircularFailure {
  const CircularUnauthorized();
}

final class CircularVersionConflict extends CircularFailure {
  const CircularVersionConflict();
}

final class CircularUnavailable extends CircularFailure {
  const CircularUnavailable();
}

final class CircularNotAvailable extends CircularFailure {
  const CircularNotAvailable();
}

final class CircularInvalid extends CircularFailure {
  const CircularInvalid(this.code);
  final String code;
}
