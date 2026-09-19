import 'platform_notice.dart';

final class NoticeDirectoryQuery {
  const NoticeDirectoryQuery({
    this.search,
    this.types = const {},
    this.statuses = const {},
    this.priorities = const {},
    this.cursorOccurredAt,
    this.cursorId,
    this.pageSize = 25,
  });

  final String? search;
  final Set<CommunicationType> types;
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

/// Leitor do hub Principal / Para você com audiência resolvida no servidor
/// (`list_my_principal_for_you`, B9). Diferente de [NoticeRepository], nunca
/// usa o gateway administrativo: o servidor aplica tipo, destino, vigência e
/// audiência ao vínculo ativo do próprio ator.
abstract interface class PrincipalForYouReader {
  Future<List<PlatformNotice>> readForYou({String? membershipId});
}

/// Opção de destino do CTA (spec 069 H13): id + rótulo, resolvidos no
/// servidor por tipo (circular, formulário, aviso).
final class NoticeCtaTargetOption {
  const NoticeCtaTargetOption({required this.id, required this.label});

  final String id;
  final String label;
}

/// Leitor das opções de destino do CTA. Separado do [NoticeRepository] para
/// que o formulário funcione sem ele (o seletor some) e os fakes de teste não
/// precisem implementá-lo.
abstract interface class NoticeCtaTargetOptionsReader {
  Future<List<NoticeCtaTargetOption>> fetchCtaTargetOptions({
    required NoticeCtaTargetKind kind,
    String? search,
    int pageSize = 30,
  });

  /// Perfis oficiais ativos (spec 068) para "Publicar como".
  Future<List<NoticeOfficialProfile>> fetchOfficialProfiles();
}

/// Post de texto de um perfil oficial no feed Acontece (spec 068 §4, lote 107).
final class OfficialPost {
  const OfficialPost({
    required this.id,
    required this.profileId,
    required this.handle,
    required this.profileName,
    required this.caption,
    required this.status,
    required this.publishedAt,
    required this.managementVersion,
    this.withdrawnAt,
    this.withdrawReason,
  });

  static OfficialPost? fromJson(Object? value) {
    if (value is! Map) return null;
    final id = value['id']?.toString();
    final publishedAt = DateTime.tryParse(value['published_at']?.toString() ?? '');
    if (id == null || id.isEmpty || publishedAt == null) return null;
    return OfficialPost(
      id: id,
      profileId: value['official_profile_id']?.toString() ?? '',
      handle: value['handle']?.toString() ?? '',
      profileName: value['display_name']?.toString() ?? 'Coelo',
      caption: value['caption']?.toString() ?? '',
      status: value['status']?.toString() ?? 'published',
      publishedAt: publishedAt.toUtc(),
      managementVersion: (value['management_version'] as num?)?.toInt() ?? 1,
      withdrawnAt: DateTime.tryParse(value['withdrawn_at']?.toString() ?? '')?.toUtc(),
      withdrawReason: value['withdraw_reason']?.toString(),
    );
  }

  final String id;
  final String profileId;
  final String handle;
  final String profileName;
  final String caption;
  final String status;
  final DateTime publishedAt;
  final int managementVersion;
  final DateTime? withdrawnAt;
  final String? withdrawReason;

  bool get isPublished => status == 'published';
}

/// Publicação do perfil oficial no Acontece (spec 068 §4). Interface pequena,
/// detectada com `is` no router; erros são os `NoticeRepositoryException`.
abstract interface class OfficialPostsCommands {
  Future<List<OfficialPost>> fetchOfficialPosts({String? profileId});

  Future<OfficialPost> publishOfficialPost({
    required String requestId,
    required String profileId,
    required String caption,
  });

  Future<OfficialPost> withdrawOfficialPost({
    required String requestId,
    required String postId,
    required int expectedVersion,
    required String reason,
  });
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

  /// Clona [noticeId] como rascunho "Cópia de …" (spec 069 H08), em qualquer
  /// status; datas e recibos não são copiados.
  Future<PlatformNotice> duplicate(String noticeId, {required String requestId});
}

sealed class NoticeRepositoryException implements Exception {
  const NoticeRepositoryException(this.safeMessage);
  final String safeMessage;
}

final class NoticeUnauthorizedException extends NoticeRepositoryException {
  const NoticeUnauthorizedException() : super('Você não tem acesso a este aviso.');
}

final class NoticeNotFoundException extends NoticeRepositoryException {
  const NoticeNotFoundException() : super('Comunicação não encontrada.');
}

final class NoticeConflictException extends NoticeRepositoryException {
  const NoticeConflictException() : super('O aviso foi alterado. Recarregue e tente novamente.');
}

final class NoticeValidationException extends NoticeRepositoryException {
  const NoticeValidationException([super.safeMessage = 'Revise os dados do aviso.']);
}

final class NoticeMediaDecisionRequiredException extends NoticeRepositoryException {
  const NoticeMediaDecisionRequiredException()
    : super(
        'A publicação com imagem ainda não está disponível. '
        'Converta o aviso para texto antes de publicar.',
      );
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

  @override
  Future<PlatformNotice> duplicate(String noticeId, {required String requestId}) => _unavailable();
}
