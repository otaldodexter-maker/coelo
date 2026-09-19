/// Registro dos tours por tela do Superadmin: destino do menu → tour. A
/// ordem é a do menu (`coeloSuperadminNavigation`), usada pelo tour completo.
/// Texto de cada tela em `screens/<destino>_tour.dart`.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

import 'screens/home_tour.dart';
import 'screens/institutions_tour.dart';
import 'screens/units_tour.dart';
import 'screens/groups_tour.dart';
import 'screens/activities_tour.dart';
import 'screens/assessment_entry_tour.dart';
import 'screens/assessment_closing_tour.dart';
import 'screens/attendance_tour.dart';
import 'screens/attendance_create_tour.dart';
import 'screens/attendance_history_tour.dart';
import 'screens/daily_routine_tour.dart';
import 'screens/students_tour.dart';
import 'screens/people_tour.dart';
import 'screens/safety_tour.dart';
import 'screens/internal_users_tour.dart';
import 'screens/profiles_tour.dart';
import 'screens/staff_access_tour.dart';
import 'screens/staff_leaves_tour.dart';
import 'screens/health_care_profiles_tour.dart';
import 'screens/health_medication_plans_tour.dart';
import 'screens/meal_plans_tour.dart';
import 'screens/forms_tour.dart';
import 'screens/import_tour.dart';
import 'screens/agenda_tour.dart';
import 'screens/agenda_create_tour.dart';
import 'screens/agenda_requests_tour.dart';
import 'screens/agenda_approvals_tour.dart';
import 'screens/conversations_tour.dart';
import 'screens/invites_tour.dart';
import 'screens/notices_tour.dart';
import 'screens/support_tour.dart';
import 'screens/audit_tour.dart';
import 'screens/catalog_tour.dart';
import 'screens/principal_happens_tour.dart';
import 'screens/principal_happens_publish_tour.dart';
import 'screens/principal_for_you_tour.dart';
import 'screens/principal_moments_tour.dart';
import 'screens/principal_moments_publish_tour.dart';
import 'screens/principal_now_tour.dart';
import 'screens/principal_now_publish_tour.dart';
import 'screens/principal_chat_tour.dart';
import 'screens/principal_profile_tour.dart';
import 'screens/circulars_tour.dart';
import 'screens/circular_create_tour.dart';
import 'superadmin_screen_tour.dart';

export 'superadmin_screen_tour.dart';

/// Tours na ordem do menu.
const superadminScreenTourList = <SuperadminScreenTour>[
  homeScreenTour,
  institutionsScreenTour,
  unitsScreenTour,
  groupsScreenTour,
  activitiesScreenTour,
  assessmentEntryScreenTour,
  assessmentClosingScreenTour,
  attendanceScreenTour,
  attendanceCreateScreenTour,
  attendanceHistoryScreenTour,
  dailyRoutineScreenTour,
  studentsScreenTour,
  peopleScreenTour,
  safetyScreenTour,
  internalUsersScreenTour,
  profilesScreenTour,
  staffAccessScreenTour,
  staffLeavesScreenTour,
  healthCareProfilesScreenTour,
  healthMedicationPlansScreenTour,
  mealPlansScreenTour,
  formsScreenTour,
  importScreenTour,
  agendaScreenTour,
  agendaCreateScreenTour,
  agendaRequestsScreenTour,
  agendaApprovalsScreenTour,
  conversationsScreenTour,
  invitesScreenTour,
  noticesScreenTour,
  supportScreenTour,
  auditScreenTour,
  catalogScreenTour,
  principalHappensScreenTour,
  principalHappensPublishScreenTour,
  principalForYouScreenTour,
  principalMomentsScreenTour,
  principalMomentsPublishScreenTour,
  principalNowScreenTour,
  principalNowPublishScreenTour,
  principalChatScreenTour,
  principalProfileScreenTour,
  circularsScreenTour,
  circularCreateScreenTour,
];

/// Destino → tour.
final superadminScreenTours = <String, SuperadminScreenTour>{
  for (final tour in superadminScreenTourList) tour.destinationId: tour,
};

/// Destinos roteados sem tour, com o motivo (o teste de cobertura exige que
/// todo destino roteado esteja aqui ou no registro).
const superadminScreenTourExclusions = <String, String>{
  'plans': 'Planos só existe em desenvolvimento (sem passo também no tour do menu).',
};

/// Limite do rascunho: 220 caracteres por passo.
const superadminScreenTourStepMaxLength = 220;

/// Passos de todas as telas, para testes e contagem.
Iterable<CoeloTourStep> get superadminScreenTourSteps =>
    superadminScreenTourList.expand((tour) => tour.steps);
