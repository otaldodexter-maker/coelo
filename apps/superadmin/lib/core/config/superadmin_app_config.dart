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
  static const allowDevelopmentPreview = !kReleaseMode && environment == 'local';

  static bool get hasSupabaseConfig => supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}

bool canEnableDevelopmentPreview({required bool isReleaseMode, required String environment}) =>
    !isReleaseMode && environment == 'local';
