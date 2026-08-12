import 'platform_notice.dart';

final class NoticeDirectoryQuery {
  const NoticeDirectoryQuery({
    this.search,
    this.statuses = const {},
    this.priorities = const {},
    this.cursorOccurredAt,
    this.cursorId,
    this.pageSize = 25,
  });

  final String? search;
  final Set<NoticeStatus> statuses;
  final Set<NoticePriority> priorities;
  final DateTime? cursorOccurredAt;
  final String? cursorId;
  final int pageSize;
}

final class NoticePage {
  const NoticePage({required this.items, this.nextCursorOccurredAt, this.nextCursorId});

  final List<PlatformNotice> items;
  final DateTime? nextCursorOccurredAt;
  final String? nextCursorId;
}

final class NoticeAudienceOption {
  const NoticeAudienceOption({required this.id, required this.label, this.parentId});

  final String id;
  final String label;
  final String? parentId;
}

final class NoticeAudienceOptionsPage {
  const NoticeAudienceOptionsPage({required this.items, this.nextCursorLabel, this.nextCursorId});

  final List<NoticeAudienceOption> items;
  final String? nextCursorLabel;
  final String? nextCursorId;
}

abstract interface class NoticeRepository {
  Future<NoticePage> fetchPage(NoticeDirectoryQuery query);

  Future<NoticeAudienceOptionsPage> fetchAudienceOptions({
    required NoticeAudienceDimension dimension,
    String? search,
    List<String> parentIds = const [],
    String? cursorLabel,
    String? cursorId,
    int pageSize = 30,
  });

  Future<PlatformNotice> getById(String noticeId);

  Future<PlatformNotice> saveDraft(
    NoticeDraft draft, {
    required String requestId,
    String? noticeId,
    int? expectedVersion,
  });

  Future<PlatformNotice> publish(
    PlatformNotice notice, {
    required String requestId,
    required int expectedVersion,
  });

  Future<PlatformNotice> changeStatus(
    String noticeId, {
    required String requestId,
    required NoticeStatus status,
    required int expectedVersion,
    String? reason,
  });
}

sealed class NoticeRepositoryException implements Exception {
  const NoticeRepositoryException(this.safeMessage);
  final String safeMessage;
}

final class NoticeUnauthorizedException extends NoticeRepositoryException {
  const NoticeUnauthorizedException() : super('Você não tem acesso a este aviso.');
}

final class NoticeNotFoundException extends NoticeRepositoryException {
  const NoticeNotFoundException() : super('Aviso não encontrado.');
}

final class NoticeConflictException extends NoticeRepositoryException {
  const NoticeConflictException() : super('O aviso foi alterado. Recarregue e tente novamente.');
}

final class NoticeValidationException extends NoticeRepositoryException {
  const NoticeValidationException([super.safeMessage = 'Revise os dados do aviso.']);
}

final class NoticeMediaDecisionRequiredException extends NoticeRepositoryException {
  const NoticeMediaDecisionRequiredException()
    : super('A publicação com imagem aguarda a decisão de armazenamento Supabase Storage × R2.');
}

final class NoticeUnavailableException extends NoticeRepositoryException {
  const NoticeUnavailableException() : super('Avisos indisponíveis no momento.');
}

final class NoticeUnexpectedException extends NoticeRepositoryException {
  const NoticeUnexpectedException() : super('Não foi possível concluir a operação.');
}

final class UnavailableNoticeRepository implements NoticeRepository {
  const UnavailableNoticeRepository();

  Future<T> _unavailable<T>() => Future<T>.error(const NoticeUnavailableException());

  @override
  Future<NoticePage> fetchPage(NoticeDirectoryQuery query) => _unavailable();

  @override
  Future<NoticeAudienceOptionsPage> fetchAudienceOptions({
    required NoticeAudienceDimension dimension,
    String? search,
    List<String> parentIds = const [],
    String? cursorLabel,
    String? cursorId,
    int pageSize = 30,
  }) => _unavailable();

  @override
  Future<PlatformNotice> getById(String noticeId) => _unavailable();

  @override
  Future<PlatformNotice> saveDraft(
    NoticeDraft draft, {
    required String requestId,
    String? noticeId,
    int? expectedVersion,
  }) => _unavailable();

  @override
  Future<PlatformNotice> publish(
    PlatformNotice notice, {
    required String requestId,
    required int expectedVersion,
  }) => _unavailable();

  @override
  Future<PlatformNotice> changeStatus(
    String noticeId, {
    required String requestId,
    required NoticeStatus status,
    required int expectedVersion,
    String? reason,
  }) => _unavailable();
}
