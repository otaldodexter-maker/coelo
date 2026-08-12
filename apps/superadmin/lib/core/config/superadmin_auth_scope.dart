import 'package:coelo_auth/coelo_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/domain/coelo_auth_login_action.dart';
import '../../features/activities/data/supabase_activity_directory_repository.dart';
import '../../features/activities/domain/activity_directory.dart';
import '../../features/auth/domain/login_request.dart';
import '../../features/auth/domain/logout_action.dart';
import '../../features/auth/domain/password_recovery.dart';
import '../../features/institutions/data/supabase_institution_directory_repository.dart';
import '../../features/institutions/domain/institution_directory_repository.dart';
import '../../features/people/data/supabase_person_directory_repository.dart';
import '../../features/people/domain/person_directory.dart';
import '../../features/access_profiles/data/supabase_access_profile_repository.dart';
import '../../features/access_profiles/domain/access_profile.dart';
import '../../features/notices/data/supabase_notice_repository.dart';
import '../../features/notices/domain/notice_repository.dart';
import '../guards/superadmin_session.dart';
import 'superadmin_app_config.dart';

typedef SupabaseInitializer =
    Future<SupabaseClient> Function({
      required String url,
      required String publishableKey,
      required LocalStorage localStorage,
    });

typedef CoeloAuthGatewayFactory =
    CoeloAuthGateway Function({
      required SupabaseClient client,
      required CoeloAuthSessionPersistence sessionPersistence,
    });

final class SuperadminAuthScope {
  const SuperadminAuthScope({
    required this.session,
    required this.login,
    required this.logout,
    required this.requestPasswordRecovery,
    required this.institutionDirectoryRepository,
    required this.activityDirectoryRepository,
    required this.personDirectoryRepository,
    required this.accessProfileRepository,
    required this.noticeRepository,
  });

  final SuperadminSession session;
  final LoginAction login;
  final LogoutAction logout;
  final PasswordRecoveryAction requestPasswordRecovery;
  final InstitutionDirectoryRepository institutionDirectoryRepository;
  final ActivityDirectoryRepository activityDirectoryRepository;
  final PersonDirectoryRepository personDirectoryRepository;
  final AccessProfileRepository accessProfileRepository;
  final NoticeRepository noticeRepository;
}

Future<SuperadminAuthScope> createSuperadminAuthScope({
  String supabaseUrl = SuperadminAppConfig.supabaseUrl,
  String supabasePublishableKey = SuperadminAppConfig.supabasePublishableKey,
  SupabaseInitializer initializeSupabase = _initializeSupabase,
  CoeloAuthGatewayFactory createAuthGateway = _createAuthGateway,
}) async {
  if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
    return _createUnavailableScope(const UnavailableCoeloAuthGateway());
  }

  try {
    final storage = ConditionalSupabaseLocalStorage(
      delegate: SharedPreferencesLocalStorage(persistSessionKey: 'coelo.superadmin.auth.session'),
    );
    final client = await initializeSupabase(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
      localStorage: storage,
    );
    final auth = createAuthGateway(client: client, sessionPersistence: storage);
    final session = SuperadminSession(
      isAuthenticated: auth.isAuthenticated,
      authStateChanges: auth.authStateChanges,
    );
    return SuperadminAuthScope(
      session: session,
      login: createCoeloAuthLoginAction(auth: auth, session: session),
      logout: createCoeloAuthLogoutAction(auth: auth, session: session),
      requestPasswordRecovery: createCoeloAuthPasswordRecoveryAction(auth: auth),
      institutionDirectoryRepository: SupabaseInstitutionDirectoryRepository(client),
      activityDirectoryRepository: SupabaseActivityDirectoryRepository(client),
      personDirectoryRepository: SupabasePersonDirectoryRepository(client),
      accessProfileRepository: SupabaseAccessProfileRepository(client),
      noticeRepository: SupabaseNoticeRepository(client),
    );
  } on Exception catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'superadmin_auth_scope',
        context: ErrorDescription('while initializing Supabase auth for Superadmin'),
      ),
    );
    return _createUnavailableScope(
      const UnavailableCoeloAuthGateway(
        message: 'Não foi possível inicializar a autenticação deste ambiente.',
      ),
    );
  }
}

SuperadminAuthScope _createUnavailableScope(CoeloAuthGateway auth) {
  final session = SuperadminSession();
  return SuperadminAuthScope(
    session: session,
    login: createCoeloAuthLoginAction(auth: auth, session: session),
    logout: createCoeloAuthLogoutAction(auth: auth, session: session),
    requestPasswordRecovery: createCoeloAuthPasswordRecoveryAction(auth: auth),
    institutionDirectoryRepository: const UnavailableInstitutionDirectoryRepository(),
    activityDirectoryRepository: const UnavailableActivityDirectoryRepository(),
    personDirectoryRepository: const UnavailablePersonDirectoryRepository(),
    accessProfileRepository: const UnavailableAccessProfileRepository(),
    noticeRepository: const UnavailableNoticeRepository(),
  );
}

CoeloAuthGateway _createAuthGateway({
  required SupabaseClient client,
  required CoeloAuthSessionPersistence sessionPersistence,
}) {
  return SupabaseCoeloAuthGateway(client, sessionPersistence: sessionPersistence);
}

Future<SupabaseClient> _initializeSupabase({
  required String url,
  required String publishableKey,
  required LocalStorage localStorage,
}) async {
  await Supabase.initialize(
    url: url,
    publishableKey: publishableKey,
    authOptions: FlutterAuthClientOptions(localStorage: localStorage),
  );
  return Supabase.instance.client;
}
