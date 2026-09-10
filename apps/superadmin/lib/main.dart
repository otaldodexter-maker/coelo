import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/superadmin_app.dart';
import 'core/config/superadmin_auth_scope.dart';
import 'features/auth/domain/superadmin_auth_context.dart';
import 'features/locations/data/supabase_location_catalog_reader.dart';
import 'features/locations/data/supabase_location_catalog_writer.dart';
import 'features/locations/data/supabase_location_reservation_gateway.dart';
import 'features/locations/domain/location_capabilities.dart';
import 'features/locations/domain/location_catalog_reader.dart';
import 'features/locations/domain/location_catalog_writer.dart';
import 'features/locations/domain/location_reservation_gateway.dart';
import 'features/locations/domain/location_consumer_bindings_reader.dart';
import 'features/locations/data/supabase_location_consumer_bindings_reader.dart';
import 'features/activities/data/supabase_activity_read_detail_repository.dart';
import 'features/activities/domain/activity_read_detail.dart';

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
      groupDetailRepository: authScope.groupDetailRepository,
      unitDetailRepository: authScope.unitDetailRepository,
      locationCatalogReader: _locationCatalogReader(),
      locationCatalogWriter: _locationCatalogWriter(),
      locationReservationGateway: _locationReservationGateway(),
      locationConsumerBindingsReader: _locationConsumerBindingsReader(),
      locationCapabilities: _locationCapabilities,
      activityDirectoryRepository: authScope.activityDirectoryRepository,
      activityReadDetailRepository: _activityReadDetailRepository(),
      activityCommandRepository: authScope.activityCommandRepository,
      assessmentRepository: authScope.assessmentRepository,
      assessmentMutationsEnabled: authScope.assessmentMutationsEnabled,
      personDirectoryRepository: authScope.personDirectoryRepository,
      personDetailReader: authScope.personDetailReader,
      personIdentityRepository: authScope.personIdentityRepository,
      accessProfileRepository: authScope.accessProfileRepository,
      platformUserRepository: authScope.platformUserRepository,
      importRepository: authScope.importRepository,
      planCatalogRepository: authScope.planCatalogRepository,
      agendaRepository: authScope.agendaRepository,
      formsApi: authScope.formsApi,
      formsDirectoryReader: authScope.formsDirectoryReader,
      formsMediaReader: authScope.formsMediaReader,
      formsMediaScope: authScope.formsMediaScope,
      mealPlanRepository: authScope.mealPlanRepository,
      mealPlanImageRepository: authScope.mealPlanImageRepository,
      authorizedMealPlanTenantId: authScope.authorizedMealPlanTenantId,
      chatRepository: authScope.chatRepository,
      circularRepository: authScope.circularRepository,
      inviteRepository: authScope.inviteRepository,
      noticeRepository: authScope.noticeRepository,
      attendanceRepository: authScope.attendanceRepository,
      childDirectoryRead: authScope.childDirectoryRead,
      attendancePermissions: authScope.attendancePermissions,
      routineRepository: authScope.routineRepository,
      childSafetyRepository: authScope.childSafetyRepository,
      principalRuntimeContextRepository: authScope.principalRuntimeContextRepository,
      profileAboutRepository: authScope.profileAboutRepository,
      principalCircularRepository: authScope.principalCircularRepository,
      principalHappensFeedRepository: authScope.principalHappensFeedRepository,
      principalMixedFeedRepository: authScope.principalMixedFeedRepository,
      principalCircularResponseRepository: authScope.principalCircularResponseRepository,
      principalCircularMediaRepository: authScope.principalCircularMediaRepository,
      principalMomentsFeedRepository: authScope.principalMomentsFeedRepository,
      principalMomentsWithdrawalRepository: authScope.principalMomentsWithdrawalRepository,
      happensPublicationRepository: authScope.happensPublicationRepository,
      principalNowFeedRepository: authScope.principalNowFeedRepository,
      momentsPublicationRepository: authScope.momentsPublicationRepository,
      nowPublicationRepository: authScope.nowPublicationRepository,
    ),
  );
}

LocationCatalogReader _locationCatalogReader() {
  try {
    return SupabaseLocationCatalogReader(Supabase.instance.client);
  } on Object {
    return const UnavailableLocationCatalogReader();
  }
}

LocationCatalogWriter _locationCatalogWriter() {
  try {
    return SupabaseLocationCatalogWriter(Supabase.instance.client);
  } on Object {
    return const UnavailableLocationCatalogWriter();
  }
}

LocationCapabilities _locationCapabilities(SuperadminAuthContext? context) {
  final permissionCodes = context?.permissionCodes;
  if (permissionCodes == null) return LocationCapabilities.none;
  return LocationCapabilities(
    create: permissionCodes.contains('locations.create'),
    update: permissionCodes.contains('locations.update'),
    status: permissionCodes.contains('locations.status'),
    copy: permissionCodes.contains('locations.copy'),
    schedule: permissionCodes.contains('locations.schedule'),
  );
}

LocationReservationGateway _locationReservationGateway() {
  try {
    return SupabaseLocationReservationGateway(Supabase.instance.client);
  } on Object {
    return const UnavailableLocationReservationGateway();
  }
}

LocationConsumerBindingsReader _locationConsumerBindingsReader() {
  try {
    return SupabaseLocationConsumerBindingsReader(Supabase.instance.client);
  } on Object {
    return const UnavailableLocationConsumerBindingsReader();
  }
}

ActivityReadDetailRepository _activityReadDetailRepository() {
  try {
    return SupabaseActivityReadDetailRepository(Supabase.instance.client);
  } on Object {
    return const UnavailableActivityReadDetailRepository();
  }
}
