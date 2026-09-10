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
  static const careAndRoutineBackendEnabled = bool.fromEnvironment(
    'COELO_ENABLE_CARE_AND_ROUTINE_BACKEND',
  );
  static const allowDevelopmentPreview = !kReleaseMode && environment == 'local';

  static bool get hasSupabaseConfig => supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}

bool canEnableDevelopmentPreview({required bool isReleaseMode, required String environment}) =>
    !isReleaseMode && environment == 'local';
