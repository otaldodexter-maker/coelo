import 'package:flutter/foundation.dart';

import '../../principal_circulars/domain/circular.dart';
import '../../principal_circulars/domain/circular_repository.dart';

@immutable
final class SuperadminCircularDirectoryQuery {
  const SuperadminCircularDirectoryQuery({
    this.institutionId,
    this.search,
    this.statuses = const {},
    this.cursorUpdatedAt,
    this.cursorId,
    this.limit = 25,
  });

  final String? institutionId;
  final String? search;
  final Set<CircularStatus> statuses;
  final DateTime? cursorUpdatedAt;
  final String? cursorId;
  final int limit;
}

@immutable
final class SuperadminCircularDirectoryItem {
  const SuperadminCircularDirectoryItem({
    required this.id,
    required this.institutionId,
    required this.title,
    required this.excerpt,
    required this.authorName,
    required this.contextLabel,
    required this.status,
    required this.effectiveAt,
    required this.updatedAt,
    required this.attachmentCount,
    required this.questionCount,
    required this.responseCount,
    required this.managementVersion,
  });

  final String id;
  final String institutionId;
  final String title;
  final String excerpt;
  final String authorName;
  final String contextLabel;
  final CircularStatus status;
  final DateTime effectiveAt;
  final DateTime updatedAt;
  final int attachmentCount;
  final int questionCount;
  final int responseCount;
  final int managementVersion;
}

@immutable
final class SuperadminCircularDirectoryPage {
  const SuperadminCircularDirectoryPage({
    required this.items,
    this.nextCursorUpdatedAt,
    this.nextCursorId,
  });

  final List<SuperadminCircularDirectoryItem> items;
  final DateTime? nextCursorUpdatedAt;
  final String? nextCursorId;
}

@immutable
final class SuperadminCircularResponseSummary {
  const SuperadminCircularResponseSummary({
    required this.responseCount,
    required this.submittedCount,
    required this.partialCount,
    required this.closed,
  });

  final int responseCount;
  final int submittedCount;
  final int partialCount;
  final bool closed;
}

@immutable
final class SuperadminCircularEditableDraft {
  const SuperadminCircularEditableDraft({required this.draft, required this.scope});

  final CircularDraft draft;
  final CircularScope scope;
}

/// Internal-admin contract. It intentionally extends the UI's current composer
/// contract without using any people-realm authentication or authorship.
abstract interface class SuperadminCircularRepository implements CircularRepository {
  Future<SuperadminCircularDirectoryPage> fetchDirectory(SuperadminCircularDirectoryQuery query);

  Future<SuperadminCircularResponseSummary> fetchResponseSummary(String circularId);

  Future<SuperadminCircularEditableDraft> loadDraftById(String circularId);
}

/// Honest production fallback while the internal gateway is unavailable.
final class UnavailableSuperadminCircularRepository implements SuperadminCircularRepository {
  const UnavailableSuperadminCircularRepository();

  Future<T> _unavailable<T>() => Future<T>.error(const CircularUnavailable());

  @override
  Future<CircularSaveResult> closeResponses({
    required String requestId,
    required String circularId,
    required int expectedVersion,
  }) => _unavailable();

  @override
  Future<SuperadminCircularDirectoryPage> fetchDirectory(SuperadminCircularDirectoryQuery query) =>
      _unavailable();

  @override
  Future<SuperadminCircularResponseSummary> fetchResponseSummary(String circularId) =>
      _unavailable();

  @override
  Future<CircularDetail> getVisible(String circularId, {String? childContextId}) => _unavailable();

  @override
  Future<CircularDraft?> loadDraft(CircularScope scope) => _unavailable();

  @override
  Future<SuperadminCircularEditableDraft> loadDraftById(String circularId) => _unavailable();

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
}
