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
      personDirectoryRepository: authScope.personDirectoryRepository,
      personIdentityRepository: authScope.personIdentityRepository,
      accessProfileRepository: authScope.accessProfileRepository,
      importRepository: authScope.importRepository,
      inviteRepository: authScope.inviteRepository,
      noticeRepository: authScope.noticeRepository,
      attendanceRepository: authScope.attendanceRepository,
      attendancePermissions: authScope.attendancePermissions,
      routineRepository: authScope.routineRepository,
      childSafetyRepository: authScope.childSafetyRepository,
    ),
  );
}
