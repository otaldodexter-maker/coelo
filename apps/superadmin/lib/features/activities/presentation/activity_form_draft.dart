import 'dart:typed_data';

import 'package:coelo_domain/profile_about.dart';

import '../domain/activity_directory.dart';
import 'activity_pedagogical_configuration_draft.dart';

enum ActivityIdentityIcon { activity, sports, music, science, arts }

enum ActivityProfessionalAccess {
  none('Nenhuma'),
  view('Ver'),
  edit('Editar'),
  both('Ambas');

  const ActivityProfessionalAccess(this.label);

  final String label;
}

enum ActivityAssignmentRole {
  instructor('Professor/Instrutor'),
  activityAdmin('Administrador da atividade');

  const ActivityAssignmentRole(this.label);

  final String label;
}

final class ActivityStudentSelection {
  const ActivityStudentSelection({
    required this.groupId,
    required this.childGroupLinkId,
    required this.belongs,
  });

  final String groupId;
  final String childGroupLinkId;
  final bool belongs;
}

final class ActivityProfessionalPermissions {
  const ActivityProfessionalPermissions({
    this.happens = ActivityProfessionalAccess.both,
    this.now = ActivityProfessionalAccess.both,
    this.moments = ActivityProfessionalAccess.both,
    this.chat = ActivityProfessionalAccess.both,
    this.attendance = ActivityProfessionalAccess.both,
  });

  final ActivityProfessionalAccess happens;
  final ActivityProfessionalAccess now;
  final ActivityProfessionalAccess moments;
  final ActivityProfessionalAccess chat;
  final ActivityProfessionalAccess attendance;

  ActivityProfessionalPermissions copyWith({
    ActivityProfessionalAccess? happens,
    ActivityProfessionalAccess? now,
    ActivityProfessionalAccess? moments,
    ActivityProfessionalAccess? chat,
    ActivityProfessionalAccess? attendance,
  }) => ActivityProfessionalPermissions(
    happens: happens ?? this.happens,
    now: now ?? this.now,
    moments: moments ?? this.moments,
    chat: chat ?? this.chat,
    attendance: attendance ?? this.attendance,
  );
}

final class ActivityProfessionalAssignment {
  const ActivityProfessionalAssignment({
    required this.groupId,
    required this.professionalId,
    this.role = ActivityAssignmentRole.instructor,
    this.permissions = const ActivityProfessionalPermissions(),
  });

  final String? groupId;
  final String professionalId;
  final ActivityAssignmentRole role;
  final ActivityProfessionalPermissions permissions;

  ActivityProfessionalAssignment copyWith({ActivityProfessionalPermissions? permissions}) =>
      ActivityProfessionalAssignment(
        groupId: groupId,
        professionalId: professionalId,
        role: role,
        permissions: permissions ?? this.permissions,
      );
}

final class ActivityFormDraft {
  const ActivityFormDraft({
    required this.name,
    this.handleStem = '',
    required this.description,
    required this.taxonomy,
    required this.subtype,
    required this.template,
    required this.taxonomyOtherDescription,
    required this.governance,
    required this.institutionId,
    required this.unitIds,
    required this.groupIds,
    required this.assignments,
    this.locationId,
    this.imageName,
    this.imageBytes,
    this.identityInitials = '',
    this.identityColor = '#D63C00',
    this.identityIcon = ActivityIdentityIcon.activity,
    this.identityStorageRef,
    this.groupParticipation = const {},
    this.studentSelections = const [],
    this.aboutPage,
    this.pedagogicalConfiguration = const ActivityPedagogicalConfigurationDraft.disabled(),
    this.expectedManagementVersion = 0,
  });

  final String name;
  final String handleStem;
  final String description;
  final ActivityTaxonomyOption? taxonomy;
  final ActivityTaxonomySubtypeOption? subtype;
  final ActivityTemplateOption? template;
  final String taxonomyOtherDescription;
  final ActivityGovernance governance;
  final String institutionId;
  final Set<String> unitIds;
  final String? locationId;
  final Set<String> groupIds;
  final List<ActivityProfessionalAssignment> assignments;
  final String? imageName;
  final Uint8List? imageBytes;
  final String identityInitials;
  final String identityColor;
  final ActivityIdentityIcon identityIcon;
  final ActivityIdentityStorageRef? identityStorageRef;
  final Map<String, ActivityParticipation> groupParticipation;
  final List<ActivityStudentSelection> studentSelections;
  final ProfileAboutPage? aboutPage;
  final ActivityPedagogicalConfigurationDraft pedagogicalConfiguration;
  final int expectedManagementVersion;
}
