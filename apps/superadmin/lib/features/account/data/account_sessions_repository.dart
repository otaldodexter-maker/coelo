import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_profile_repository.dart';

/// Uma sessao viva do proprio usuario (account.sessions, P43 = B).
final class AccountSession {
  const AccountSession({
    required this.id,
    required this.isCurrent,
    required this.createdAt,
    required this.refreshedAt,
    required this.userAgent,
    required this.ip,
  });

  final String id;
  final bool isCurrent;
  final DateTime? createdAt;
  final DateTime? refreshedAt;
  final String userAgent;
  final String ip;
}

abstract interface class AccountSessionsRepository {
  Future<List<AccountSession>> list();

  /// Encerra todas as sessoes do usuario exceto a atual (GoTrue `scope=others`).
  Future<void> revokeOthers();
}

final class UnavailableAccountSessionsRepository implements AccountSessionsRepository {
  const UnavailableAccountSessionsRepository();

  @override
  Future<List<AccountSession>> list() => Future<List<AccountSession>>.error(
    const AccountProfileRepositoryException('Sessões indisponíveis nesta versão.'),
  );

  @override
  Future<void> revokeOthers() => Future<void>.error(
    const AccountProfileRepositoryException('Sessões indisponíveis nesta versão.'),
  );
}

final class SupabaseAccountSessionsRepository implements AccountSessionsRepository {
  const SupabaseAccountSessionsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<AccountSession>> list() async {
    final Object? raw;
    try {
      raw = await _client.rpc<Object?>('superadmin_account_sessions_list_v1');
    } on PostgrestException catch (error) {
      throw AccountProfileRepositoryException(error.message);
    } on Exception {
      throw const AccountProfileRepositoryException('Não foi possível carregar as sessões.');
    }
    if (raw is! Map) throw const AccountProfileRepositoryException('Resposta de sessões inválida.');
    final sessions = raw['sessions'];
    if (sessions is! List) throw const AccountProfileRepositoryException('Resposta de sessões inválida.');
    return [
      for (final item in sessions.whereType<Map<String, Object?>>())
        AccountSession(
          id: '${item['id'] ?? ''}',
          isCurrent: item['is_current'] == true,
          createdAt: DateTime.tryParse('${item['created_at'] ?? ''}'),
          refreshedAt: DateTime.tryParse('${item['refreshed_at'] ?? ''}'),
          userAgent: '${item['user_agent'] ?? ''}',
          ip: '${item['ip'] ?? ''}',
        ),
    ];
  }

  @override
  Future<void> revokeOthers() async {
    try {
      // Endpoint nativo do GoTrue: revoga no servidor as demais sessoes e
      // mantem a atual; auditado em auth.audit_log_entries.
      await _client.auth.signOut(scope: SignOutScope.others);
    } on AuthException catch (error) {
      throw AccountProfileRepositoryException(error.message);
    } on Exception {
      throw const AccountProfileRepositoryException('Não foi possível encerrar as outras sessões.');
    }
  }
}
