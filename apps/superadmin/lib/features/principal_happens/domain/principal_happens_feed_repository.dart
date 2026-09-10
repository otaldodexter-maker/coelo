import 'principal_happens_preview_data.dart';

final class PrincipalHappensFeedScope {
  const PrincipalHappensFeedScope({
    required this.institutionId,
    this.unitId,
    this.groupId,
    this.limit = 20,
    this.cursorPublishedAt,
    this.cursorPostId,
  }) : assert(
         (cursorPublishedAt == null) == (cursorPostId == null),
         'as duas metades do cursor andam juntas',
       );

  final String institutionId;
  final String? unitId;
  final String? groupId;
  final int limit;

  /// Cursor keyset da proxima pagina, montado a partir do ultimo item recebido.
  /// Nulo pede a primeira pagina.
  final DateTime? cursorPublishedAt;
  final String? cursorPostId;

  /// Proxima pagina depois de [last], ou `null` quando o item nao tem posicao
  /// no servidor (fixture visual sem id ou sem instante).
  PrincipalHappensFeedScope? after(PrincipalPostPreviewItem last) {
    final publishedAt = last.publishedAt;
    final postId = last.postId;
    if (publishedAt == null || postId == null) return null;
    return PrincipalHappensFeedScope(
      institutionId: institutionId,
      unitId: unitId,
      groupId: groupId,
      limit: limit,
      cursorPublishedAt: publishedAt,
      cursorPostId: postId,
    );
  }
}

abstract interface class PrincipalHappensFeedRepository {
  Future<List<PrincipalPostPreviewItem>> listVisiblePosts(PrincipalHappensFeedScope scope);

  Future<PrincipalHappensMediaRead> resolveMedia(PrincipalHappensMediaDescriptor media);
}

final class PrincipalHappensMediaRead {
  const PrincipalHappensMediaRead({
    required this.signedUrl,
    required this.mimeType,
    required this.expiresIn,
  });

  final String signedUrl;
  final String mimeType;
  final Duration expiresIn;
}

/// Retirada de uma publicacao propria ja publicada ou agendada
/// (Etapa 2 -> apps/superadmin -> Coelo (Principal) -> Acontece -> acontece.remove).
///
/// Contrato separado do feed de leitura de proposito: quem so consome o feed
/// nao precisa implementar a retirada, e a ausencia deste contrato na
/// composicao mantem a acao fechada em vez de aparente.
abstract interface class PrincipalHappensPostWithdrawal {
  /// Retira do feed a publicacao [postId] na versao [expectedVersion].
  ///
  /// A autorizacao e sempre do servidor: o cliente apenas solicita. Lanca
  /// [PrincipalHappensFeedUnauthorized] quando o ator nao pode retirar,
  /// [PrincipalHappensWithdrawalConflict] quando a versao ficou obsoleta e
  /// [PrincipalHappensFeedUnavailable] para qualquer outra falha.
  Future<void> withdrawPost({
    required String postId,
    required int expectedVersion,
    String? reason,
  });
}

final class PrincipalHappensWithdrawalConflict implements Exception {
  const PrincipalHappensWithdrawalConflict();
}

final class PrincipalHappensFeedUnauthorized implements Exception {
  const PrincipalHappensFeedUnauthorized();
}

final class PrincipalHappensFeedUnavailable implements Exception {
  const PrincipalHappensFeedUnavailable();
}
