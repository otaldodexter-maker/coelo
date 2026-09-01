import 'package:coelo_domain/coelo_domain.dart';

import 'form_editor_projection_dto.dart';
import 'form_wire_contracts.dart';

enum FormApiFailureKind { unauthorized, validation, conflict, unavailable, unknown }

final class FormApiException implements Exception {
  const FormApiException(this.kind, this.message, {this.details = const {}});

  final FormApiFailureKind kind;
  final String message;
  final Map<String, Object?> details;
}

final class FormDirectoryQuery {
  const FormDirectoryQuery({
    this.institutionId,
    this.search,
    this.statuses = const {},
    this.operationalStatuses = const {},
    this.kinds = const {},
    this.startsOnOrAfter,
    this.endsOnOrBefore,
    this.cursor,
    this.limit = 25,
  });

  final String? institutionId;
  final String? search;
  final Set<FormStatus> statuses;
  final Set<FormOperationalStatus> operationalStatuses;
  final Set<FormKind> kinds;
  final DateTime? startsOnOrAfter;
  final DateTime? endsOnOrBefore;
  final String? cursor;
  final int limit;
}

final class FormMonitorQuery {
  const FormMonitorQuery({
    required this.formId,
    this.applicationId,
    this.occurrenceId,
    this.startsOnOrAfter,
    this.endsOnOrBefore,
    this.scopeId,
    this.cursor,
    this.limit = 25,
  });

  final String formId;
  final String? applicationId;
  final String? occurrenceId;
  final DateTime? startsOnOrAfter;
  final DateTime? endsOnOrBefore;
  final String? scopeId;
  final String? cursor;
  final int limit;
}

final class FormResponsesQuery {
  const FormResponsesQuery({required this.formId, this.occurrenceId, this.cursor, this.limit = 25});

  final String formId;
  final String? occurrenceId;
  final String? cursor;
  final int limit;
}

final class FormAudienceCandidatesQuery {
  const FormAudienceCandidatesQuery({
    required this.institutionId,
    required this.kind,
    this.search,
    this.cursor,
    this.limit = 25,
  });

  final String institutionId;
  final FormAudienceRuleKind kind;
  final String? search;
  final String? cursor;
  final int limit;
}

final class FormDirectoryItem {
  const FormDirectoryItem({
    required this.id,
    required this.title,
    required this.kind,
    required this.status,
    required this.operationalStatus,
    required this.identityMode,
    required this.updatedAt,
    required this.managementVersion,
  });

  final String id;
  final String title;
  final FormKind kind;
  final FormStatus status;
  final FormOperationalStatus operationalStatus;
  final FormIdentityMode identityMode;
  final DateTime updatedAt;
  final int managementVersion;
}

final class FormOverview {
  const FormOverview({
    required this.definition,
    required this.applicationCount,
    required this.occurrenceCount,
    required this.responseCount,
  });

  final FormDefinition definition;
  final int applicationCount;
  final int occurrenceCount;
  final int responseCount;
}

final class FormAudienceCandidate {
  const FormAudienceCandidate({required this.id, required this.label, required this.kind});
  final String id;
  final String label;
  final FormAudienceRuleKind kind;
}

final class FormOccurrenceForResponse {
  const FormOccurrenceForResponse({
    required this.occurrence,
    required this.version,
    required this.participationId,
    required this.identityMode,
    this.draft,
    required this.canEdit,
  });
  final FormOccurrence occurrence;
  final FormVersion version;
  final String participationId;
  final FormIdentityMode identityMode;
  final FormResponseDraft? draft;
  final bool canEdit;
}

final class FormMonitorProjection {
  const FormMonitorProjection({
    required this.eligibleCount,
    required this.respondedCount,
    required this.pendingCount,
    required this.isAnonymous,
  });
  final int eligibleCount;
  final int respondedCount;
  final int pendingCount;
  final bool isAnonymous;
}

enum FormMonitorScopeKind { institution, unit, group, activity, profile }

final class FormMonitorScope {
  const FormMonitorScope({
    required this.scopeId,
    required this.scopeKind,
    required this.label,
    required this.eligibleCount,
    required this.respondedCount,
    required this.pendingCount,
  });

  final String scopeId;
  final FormMonitorScopeKind scopeKind;
  final String label;
  final int eligibleCount;
  final int respondedCount;
  final int pendingCount;
}

final class FormMonitorPerson {
  const FormMonitorPerson({
    required this.personId,
    required this.displayName,
    required this.profileLabel,
    required this.contextLabel,
    required this.responded,
  });
  final String personId;
  final String displayName;
  final String profileLabel;
  final String contextLabel;
  final bool responded;
}

final class FormResponseSummary {
  const FormResponseSummary({
    required this.id,
    required this.occurrenceId,
    required this.formVersionId,
    this.submittedAt,
    this.respondentLabel,
  });
  final String id;
  final String occurrenceId;
  final String formVersionId;
  final DateTime? submittedAt;
  final String? respondentLabel;
}

final class FormResponseDetail {
  FormResponseDetail({required this.summary, required Map<String, FormAnswer> answers})
    : answers = Map.unmodifiable(answers);
  final FormResponseSummary summary;
  final Map<String, FormAnswer> answers;
}

enum FormFileJobStatus { pending, processing, succeeded, partial, failed, expired }

final class FormFileJob {
  const FormFileJob({
    required this.id,
    required this.status,
    required this.progress,
    this.downloadAvailable = false,
    this.downloadPath,
    this.errorCode,
  });
  final String id;
  final FormFileJobStatus status;
  final double progress;
  final bool downloadAvailable;
  final String? downloadPath;
  final String? errorCode;
}

final class FormAssetUploadTicket {
  const FormAssetUploadTicket({
    required this.assetId,
    required this.signedUploadUrl,
    required this.expiresAt,
  });
  final String assetId;
  final Uri signedUploadUrl;
  final DateTime expiresAt;
}

final class FormSaveApplicationPayload {
  const FormSaveApplicationPayload(this.application);
  final FormApplication application;
}

final class FormIdPayload {
  const FormIdPayload(this.formId);
  final String formId;
}

enum FormCopyOrMoveMode { copy, move }

final class FormCopyOrMovePayload {
  const FormCopyOrMovePayload({
    required this.formId,
    required this.targetInstitutionId,
    required this.mode,
  });
  final String formId;
  final String targetInstitutionId;
  final FormCopyOrMoveMode mode;
}

enum FormArchiveOrDeleteAction { archive, delete }

final class FormArchiveOrDeletePayload {
  const FormArchiveOrDeletePayload({required this.formId, required this.action});
  final String formId;
  final FormArchiveOrDeleteAction action;
}

final class FormApplicationIdPayload {
  const FormApplicationIdPayload(this.applicationId);
  final String applicationId;
}

final class FormAssetIdPayload {
  const FormAssetIdPayload(this.assetId, {this.editSecret});
  final String assetId;
  final String? editSecret;
}

final class FormOccurrenceIdPayload {
  const FormOccurrenceIdPayload(this.occurrenceId);
  final String occurrenceId;
}

final class FormOpenResponseDraftPayload {
  const FormOpenResponseDraftPayload({
    required this.occurrenceId,
    required this.participationId,
    required this.identityMode,
    this.editSecret,
  });

  final String occurrenceId;
  final String participationId;
  final FormIdentityMode identityMode;
  final String? editSecret;
}

final class FormSaveSchedulePayload {
  FormSaveSchedulePayload({
    required this.applicationId,
    this.scheduleId,
    required this.schedule,
    List<FormReminder> reminders = const [],
  }) : reminders = List.unmodifiable(reminders);
  final String applicationId;
  final String? scheduleId;
  final FormSchedule schedule;
  final List<FormReminder> reminders;
}

final class FormRemoveSchedulePayload {
  const FormRemoveSchedulePayload({required this.scheduleId});
  final String scheduleId;
}

final class FormResponseDraftPayload {
  FormResponseDraftPayload({
    required this.occurrenceId,
    required this.responseId,
    required this.participationId,
    required Map<String, FormAnswer> answers,
    this.editSecret,
  }) : answers = Map.unmodifiable(answers);
  final String occurrenceId;
  final String responseId;
  final String participationId;
  final Map<String, FormAnswer> answers;
  final String? editSecret;
}

final class FormAssetUploadPayload {
  const FormAssetUploadPayload({
    required this.occurrenceId,
    required this.itemId,
    required this.mimeType,
    required this.byteLength,
    required this.checksum,
    this.editSecret,
  });
  final String occurrenceId;
  final String itemId;
  final String mimeType;
  final int byteLength;
  final String checksum;
  final String? editSecret;
}

enum FormExportKind { csv, xlsx, zip, anonymousParticipation }

final class FormExportPayload {
  const FormExportPayload({
    required this.formId,
    required this.kind,
    this.occurrenceId,
    this.justification,
  });
  final String formId;
  final FormExportKind kind;
  final String? occurrenceId;
  final String? justification;
}

final class FormAnonymousParticipationQuery {
  const FormAnonymousParticipationQuery({
    required this.formId,
    required this.justification,
    this.occurrenceId,
    this.cursor,
    this.limit = 25,
  });
  final String formId;
  final String justification;
  final String? occurrenceId;
  final String? cursor;
  final int limit;
}

abstract interface class FormsApi {
  Future<FormCursorPage<FormDirectoryItem>> listDirectory(FormDirectoryQuery query);
  Future<FormOverview> getOverview(String formId);
  Future<FormEditorProjection> getEditor(String formId);
  Future<FormCursorPage<FormAudienceCandidate>> listAudienceCandidates(
    FormAudienceCandidatesQuery query,
  );
  Future<FormDefinition> saveDraft(FormCommand<FormDefinition> command);
  Future<FormDefinition> publish(FormCommand<FormIdPayload> command);
  Future<FormDefinition> duplicate(FormCommand<FormIdPayload> command);
  Future<FormDefinition> copyOrMove(FormCommand<FormCopyOrMovePayload> command);
  Future<void> archiveOrDelete(FormCommand<FormArchiveOrDeletePayload> command);
  Future<FormApplication> saveApplication(FormCommand<FormSaveApplicationPayload> command);
  Future<FormApplication> saveSchedule(FormCommand<FormSaveSchedulePayload> command);
  Future<FormApplication> removeSchedule(FormCommand<FormRemoveSchedulePayload> command);
  Future<FormOccurrenceForResponse> getOccurrenceForResponse(String occurrenceId);
  Future<FormResponseDraft> openResponseDraft(FormCommand<FormOpenResponseDraftPayload> command);
  Future<FormResponseDraft> saveResponseDraft(FormCommand<FormResponseDraftPayload> command);
  Future<FormResponseDraft> submitResponse(FormCommand<FormResponseDraftPayload> command);
  Future<FormResponseDraft> editResponse(FormCommand<FormResponseDraftPayload> command);
  Future<FormMonitorProjection> getMonitor(FormMonitorQuery query);
  Future<FormCursorPage<FormMonitorScope>> listMonitorHierarchy(FormMonitorQuery query);
  Future<FormCursorPage<FormMonitorPerson>> listMonitorPeople(FormMonitorQuery query);
  Future<FormCursorPage<FormResponseSummary>> listResponses(FormResponsesQuery query);
  Future<FormResponseDetail> getResponseDetail(String responseId);
  Future<FormAssetUploadTicket> prepareAssetUpload(FormCommand<FormAssetUploadPayload> command);
  Future<FormAsset> finalizeAssetUpload(FormCommand<FormAssetIdPayload> command);
  Future<void> discardAsset(FormCommand<FormAssetIdPayload> command);
  Future<FormFileJob> requestExport(FormCommand<FormExportPayload> command);
  Future<FormCursorPage<FormFileJob>> listFileJobs({
    required String formId,
    String? cursor,
    int limit = 25,
  });
  Future<FormCursorPage<FormMonitorPerson>> anonymousParticipationLookup(
    FormAnonymousParticipationQuery query,
  );
  Future<FormFileJob> requestAnonymousParticipationExport(FormCommand<FormExportPayload> command);
}
