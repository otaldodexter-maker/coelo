import 'package:coelo_domain/coelo_domain.dart';

import 'form_wire_contracts.dart';
import 'forms_api.dart';

enum FormsRpc {
  list,
  getOverview,
  getEditor,
  listAudienceCandidates,
  getOccurrenceForResponse,
  getMonitor,
  listMonitorHierarchy,
  listMonitorPeople,
  listResponses,
  getResponseDetail,
  listFileJobs,
  saveDraft,
  publish,
  duplicate,
  copyOrMove,
  archiveOrDelete,
  saveApplication,
  saveSchedule,
  removeSchedule,
  openResponseDraft,
  saveResponseDraft,
  submitResponse,
  editResponse,
  prepareAssetUpload,
  finalizeAssetUpload,
  discardAsset,
  requestExport,
  anonymousParticipationLookup,
  requestAnonymousParticipationExport,
}

extension FormsRpcWireName on FormsRpc {
  String get functionName => switch (this) {
    FormsRpc.list => 'form_list',
    FormsRpc.getOverview => 'form_get_overview',
    FormsRpc.getEditor => 'form_get_editor',
    FormsRpc.listAudienceCandidates => 'form_list_audience_candidates',
    FormsRpc.getOccurrenceForResponse => 'form_get_occurrence_for_response',
    FormsRpc.getMonitor => 'form_get_monitor',
    FormsRpc.listMonitorHierarchy => 'form_list_monitor_hierarchy',
    FormsRpc.listMonitorPeople => 'form_list_monitor_people',
    FormsRpc.listResponses => 'form_list_responses',
    FormsRpc.getResponseDetail => 'form_get_response_detail',
    FormsRpc.listFileJobs => 'form_list_file_jobs',
    FormsRpc.saveDraft => 'form_save_draft',
    FormsRpc.publish => 'form_publish',
    FormsRpc.duplicate => 'form_duplicate',
    FormsRpc.copyOrMove => 'form_copy_or_move',
    FormsRpc.archiveOrDelete => 'form_archive_or_delete',
    FormsRpc.saveApplication => 'form_save_application',
    FormsRpc.saveSchedule => 'form_save_schedule',
    FormsRpc.removeSchedule => 'form_remove_schedule',
    FormsRpc.openResponseDraft => 'form_open_response_draft',
    FormsRpc.saveResponseDraft => 'form_save_response_draft',
    FormsRpc.submitResponse => 'form_submit_response',
    FormsRpc.editResponse => 'form_edit_response',
    FormsRpc.prepareAssetUpload => 'form_prepare_asset_upload',
    FormsRpc.finalizeAssetUpload => 'form_finalize_asset_upload',
    FormsRpc.discardAsset => 'form_discard_asset',
    FormsRpc.requestExport => 'form_request_export',
    FormsRpc.anonymousParticipationLookup => 'form_anonymous_participation_lookup',
    FormsRpc.requestAnonymousParticipationExport => 'form_request_anonymous_participation_export',
  };
}

final class FormDirectoryQueryDto {
  const FormDirectoryQueryDto(this.value);

  factory FormDirectoryQueryDto.fromDomain(FormDirectoryQuery value) =>
      FormDirectoryQueryDto(value);

  factory FormDirectoryQueryDto.fromJson(Map<String, Object?> json) {
    const context = 'form_directory_query';
    requireOnlyKeys(json, const {
      'search',
      'institution_id',
      'statuses',
      'operational_statuses',
      'kinds',
      'starts_on_or_after',
      'ends_on_or_before',
      'cursor',
      'limit',
    }, context: context);
    return FormDirectoryQueryDto(
      FormDirectoryQuery(
        institutionId: _nullableString(json, 'institution_id', context),
        search: _nullableString(json, 'search', context),
        statuses: _strings(json, 'statuses', context).map(_status).toSet(),
        operationalStatuses: _strings(
          json,
          'operational_statuses',
          context,
        ).map(_operationalStatus).toSet(),
        kinds: _strings(json, 'kinds', context).map(_kind).toSet(),
        startsOnOrAfter: _nullableDate(json, 'starts_on_or_after', context),
        endsOnOrBefore: _nullableDate(json, 'ends_on_or_before', context),
        cursor: _nullableString(json, 'cursor', context),
        limit: requireInt(json, 'limit', context: context),
      ),
    );
  }

  final FormDirectoryQuery value;

  FormDirectoryQuery toDomain() => value;

  Map<String, Object?> toJson() => {
    'institution_id': value.institutionId,
    'search': value.search,
    'statuses': value.statuses.map((status) => status.name).toList(growable: false),
    'operational_statuses': value.operationalStatuses
        .map((status) => status.name)
        .toList(growable: false),
    'kinds': value.kinds
        .map((kind) => kind == FormKind.quickPoll ? 'quick_poll' : 'form')
        .toList(growable: false),
    'starts_on_or_after': _date(value.startsOnOrAfter),
    'ends_on_or_before': _date(value.endsOnOrBefore),
    'cursor': value.cursor,
    'limit': value.limit,
  };
}

String? _nullableString(Map<String, Object?> json, String key, String context) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw WireFormatException('$context.$key must be a string or null.');
  return value;
}

DateTime? _nullableDate(Map<String, Object?> json, String key, String context) {
  final value = _nullableString(json, key, context);
  if (value == null) return null;
  final decoded = DateTime.tryParse(value);
  if (decoded == null) throw WireFormatException('$context.$key must be an ISO-8601 date.');
  return DateTime(decoded.year, decoded.month, decoded.day);
}

List<String> _strings(Map<String, Object?> json, String key, String context) =>
    requireList(json, key, context: context)
        .map((value) {
          if (value is! String) throw WireFormatException('$context.$key must contain strings.');
          return value;
        })
        .toList(growable: false);

FormStatus _status(String value) => switch (value) {
  'draft' => FormStatus.draft,
  'published' => FormStatus.published,
  'archived' => FormStatus.archived,
  _ => throw WireFormatException('Unknown form status: $value.'),
};

FormOperationalStatus _operationalStatus(String value) => switch (value) {
  'draft' => FormOperationalStatus.draft,
  'scheduled' => FormOperationalStatus.scheduled,
  'active' => FormOperationalStatus.active,
  'closed' => FormOperationalStatus.closed,
  'archived' => FormOperationalStatus.archived,
  _ => throw WireFormatException('Unknown form operational status: $value.'),
};

FormKind _kind(String value) => switch (value) {
  'form' => FormKind.form,
  'quick_poll' => FormKind.quickPoll,
  _ => throw WireFormatException('Unknown form kind: $value.'),
};

String? _date(DateTime? value) => value == null
    ? null
    : '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
