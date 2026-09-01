import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app/superadmin_app.dart';
import 'core/config/superadmin_auth_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  final authScope = await createSuperadminAuthScope();
  runApp(
    SuperadminApp(
      session: authScope.session,
      login: authScope.login,
      logout: authScope.logout,
      requestPasswordRecovery: authScope.requestPasswordRecovery,
      resetPassword: authScope.resetPassword,
      auditRepository: authScope.auditRepository,
      medicationPlanRepository: authScope.medicationPlanRepository,
      institutionDirectoryRepository: authScope.institutionDirectoryRepository,
      unitDirectoryRepository: authScope.unitDirectoryRepository,
      unitBackendCommands: authScope.unitBackendCommands,
      structureMutationsEnabled: authScope.structureMutationsEnabled,
      groupDirectoryRepository: authScope.groupDirectoryRepository,
      activityDirectoryRepository: authScope.activityDirectoryRepository,
      activityCommandRepository: authScope.activityCommandRepository,
      assessmentRepository: authScope.assessmentRepository,
      assessmentMutationsEnabled: authScope.assessmentMutationsEnabled,
      personDirectoryRepository: authScope.personDirectoryRepository,
      personIdentityRepository: authScope.personIdentityRepository,
      accessProfileRepository: authScope.accessProfileRepository,
      importRepository: authScope.importRepository,
      planCatalogRepository: authScope.planCatalogRepository,
      agendaRepository: authScope.agendaRepository,
      formsApi: authScope.formsApi,
      mealPlanRepository: authScope.mealPlanRepository,
      mealPlanImageRepository: authScope.mealPlanImageRepository,
      authorizedMealPlanTenantId: authScope.authorizedMealPlanTenantId,
      chatRepository: authScope.chatRepository,
      circularRepository: authScope.circularRepository,
      inviteRepository: authScope.inviteRepository,
      noticeRepository: authScope.noticeRepository,
      attendanceRepository: authScope.attendanceRepository,
      attendancePermissions: authScope.attendancePermissions,
      routineRepository: authScope.routineRepository,
      childSafetyRepository: authScope.childSafetyRepository,
      principalRuntimeContextRepository: authScope.principalRuntimeContextRepository,
      principalHappensFeedRepository: authScope.principalHappensFeedRepository,
      principalMixedFeedRepository: authScope.principalMixedFeedRepository,
      happensPublicationRepository: authScope.happensPublicationRepository,
      principalNowFeedRepository: authScope.principalNowFeedRepository,
      momentsPublicationRepository: authScope.momentsPublicationRepository,
      nowPublicationRepository: authScope.nowPublicationRepository,
    ),
  );
}
