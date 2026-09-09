import 'principal_happens_preview_data.dart';

final class PrincipalHappensFeedScope {
  const PrincipalHappensFeedScope({required this.institutionId, this.unitId, this.groupId});

  final String institutionId;
  final String? unitId;
  final String? groupId;
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
