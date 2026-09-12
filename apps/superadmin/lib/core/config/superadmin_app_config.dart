import 'package:flutter/foundation.dart';

abstract final class SuperadminAppConfig {
  static const appName = 'Superadmin Coelo';
  static const appSubtitle = 'Operacao interna';

  // Client-safe build-time configuration only. Do not add secrets here.
  static const environment = String.fromEnvironment('COELO_APP_ENV', defaultValue: 'staging');
  static const supabaseUrl = String.fromEnvironment('COELO_SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment('COELO_SUPABASE_PUBLISHABLE_KEY');
  static const isDevMfaEnabled = bool.fromEnvironment('COELO_DEV_MFA');
  static const assessmentMutationsEnabled = bool.fromEnvironment(
    'COELO_ENABLE_ASSESSMENT_MUTATIONS',
    defaultValue: true,
  );

  /// Liga Perfis de cuidado, Planos de medicação e Rotina diária contra o
  /// Supabase real.
  ///
  /// Nasce desligada de propósito: as tabelas, capacidades e RPCs dessas três
  /// famílias vêm das migrations 20260910010000 a 20260910010500, e enquanto
  /// elas não estiverem aplicadas o cliente produtivo falharia contra um banco
  /// que não tem esses objetos. Ligar antes trocaria uma indisponibilidade
  /// honesta por um erro obscuro. Esta é a chave de composição do pacote:
  /// aplicado o SQL, ligar aqui é o passo seguinte.
  /// Ligada por padrão em 10/09/2026 depois de o lote 2 (20260910010000 a
  /// 010500) entrar em produção (ADR 0034, Decisão 8); desligar só com
  /// --dart-define=COELO_ENABLE_CARE_AND_ROUTINE_BACKEND=false.
  static const careAndRoutineBackendEnabled = bool.fromEnvironment(
    'COELO_ENABLE_CARE_AND_ROUTINE_BACKEND',
    defaultValue: true,
  );

  /// Liga os comandos de vínculo de aluno (vincular, transferir, editar e
  /// revogar) contra o Supabase real.
  ///
  /// Chave própria, e não a de Cuidado e Rotina, por dois motivos: o SQL é
  /// outro pacote (20260910140000) e pode ser aplicado em outro momento; e a
  /// autorização destes comandos passa pelo realm people-based, que é
  /// justamente o ponto que a OQ-043 deixou em aberto para os CRUDs anteriores
  /// à ADR 0019. Ligar é uma decisão separada.
  /// Ligada por padrão em 10/09/2026 depois de 20260910220200 entrar em
  /// produção (lote 3); desligar só por --dart-define.
  static const studentLinkCommandsEnabled = bool.fromEnvironment(
    'COELO_ENABLE_STUDENT_LINK_COMMANDS',
    defaultValue: true,
  );
  static const allowDevelopmentPreview = !kReleaseMode && environment == 'local';

  static bool get hasSupabaseConfig => supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}

bool canEnableDevelopmentPreview({required bool isReleaseMode, required String environment}) =>
    !isReleaseMode && environment == 'local';

/// Stable, client-safe identity for the configured Supabase project.
/// Hosted projects use their project ref; local stacks use their normalized origin.
String? canonicalSupabaseProjectId(String rawUrl) {
  final uri = Uri.tryParse(rawUrl);
  if (uri == null ||
      (uri.scheme != 'https' && uri.scheme != 'http') ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  final host = uri.host.toLowerCase();
  const suffix = '.supabase.co';
  if (host.endsWith(suffix)) {
    final projectRef = host.substring(0, host.length - suffix.length);
    if (projectRef.isNotEmpty && !projectRef.contains('.')) return projectRef;
  }
  return Uri(scheme: uri.scheme, host: host, port: uri.hasPort ? uri.port : null).origin;
}
