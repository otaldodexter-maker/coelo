import 'package:http/http.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/notice_repository.dart';
import '../domain/platform_notice.dart';

final class SupabaseNoticeRepository implements NoticeRepository {
  SupabaseNoticeRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<NoticePage> fetchPage(NoticeDirectoryQuery query) async {
    try {
      final response = _map(
        await _client.rpc(
          'list_notices_for_superadmin',
          params: {
            'p_search': _nullable(query.search),
            'p_types': query.types.isEmpty
                ? null
                : query.types.map((value) => value.storageValue).toList(growable: false),
            'p_statuses': query.statuses.isEmpty
                ? null
                : query.statuses.map(_statusValue).toList(growable: false),
            'p_priorities': query.priorities.isEmpty
                ? null
                : query.priorities.map((value) => value.name).toList(growable: false),
            'p_cursor_occurred_at': query.cursorOccurredAt?.toUtc().toIso8601String(),
            'p_cursor_id': query.cursorId,
            'p_limit': query.pageSize.clamp(1, 100),
          },
        ),
      );
      return NoticePage(
        items: _list(response['items']).map((item) => _notice(_map(item))).toList(growable: false),
        nextCursorOccurredAt: _date(response['next_cursor_occurred_at']),
        nextCursorId: _nullable(response['next_cursor_id']),
      );
    } on PostgrestException catch (error) {
      throw _error(error);
    } on ClientException {
      throw const NoticeUnavailableException();
    }
  }

  @override
  Future<NoticeAudienceOptionsPage> fetchAudienceOptions({
    required NoticeAudienceDimension dimension,
    String? search,
    List<String> parentIds = const [],
    String? cursorLabel,
    String? cursorId,
    int pageSize = 30,
  }) async {
    try {
      final response = _map(
        await _client.rpc(
          'list_notice_audience_options_for_superadmin',
          params: {
            'p_dimension': dimension.name,
            'p_search': _nullable(search),
            'p_parent_ids': parentIds.isEmpty ? null : parentIds,
            'p_cursor_label': _nullable(cursorLabel),
            'p_cursor_id': _nullable(cursorId),
            'p_limit': pageSize.clamp(1, 100),
          },
        ),
      );
      return NoticeAudienceOptionsPage(
        items: _list(response['items'])
            .map(_map)
            .map(
              (item) => NoticeAudienceOption(
                id: _string(item['id']),
                label: _string(item['label']),
                parentId: _nullable(item['parent_id']),
              ),
            )
            .toList(growable: false),
        nextCursorLabel: _nullable(response['next_cursor_label']),
        nextCursorId: _nullable(response['next_cursor_id']),
      );
    } on PostgrestException catch (error) {
      throw _error(error);
    } on ClientException {
      throw const NoticeUnavailableException();
    }
  }

  @override
  Future<PlatformNotice> getById(String noticeId) async {
    try {
      return _notice(
        _map(await _client.rpc('get_notice_for_superadmin', params: {'p_notice_id': noticeId})),
      );
    } on PostgrestException catch (error) {
      throw _error(error);
    } on ClientException {
      throw const NoticeUnavailableException();
    }
  }

  @override
  Future<PlatformNotice> saveDraft(
    NoticeDraft draft, {
    required String requestId,
    String? noticeId,
    int? expectedVersion,
  }) async {
    try {
      return _notice(
        _map(
          await _client.rpc(
            'save_notice_draft_for_superadmin',
            params: {
              'p_request_id': requestId,
              'p_notice_id': noticeId,
              'p_expected_version': expectedVersion,
              'p_payload': _draftPayload(draft),
            },
          ),
        ),
      );
    } on PostgrestException catch (error) {
      throw _error(error);
    } on ClientException {
      throw const NoticeUnavailableException();
    }
  }

  @override
  Future<PlatformNotice> publish(
    PlatformNotice notice, {
    required String requestId,
    required int expectedVersion,
  }) async {
    if (notice.contentFormat == NoticeContentFormat.image) {
      throw const NoticeMediaDecisionRequiredException();
    }
    try {
      return _notice(
        _map(
          await _client.rpc(
            'publish_notice_for_superadmin',
            params: {
              'p_request_id': requestId,
              'p_notice_id': notice.id,
              'p_expected_version': expectedVersion,
            },
          ),
        ),
      );
    } on PostgrestException catch (error) {
      throw _error(error);
    } on ClientException {
      throw const NoticeUnavailableException();
    }
  }

  @override
  Future<PlatformNotice> changeStatus(
    String noticeId, {
    required String requestId,
    required NoticeStatus status,
    required int expectedVersion,
    String? reason,
  }) async {
    try {
      return _notice(
        _map(
          await _client.rpc(
            'change_notice_status_for_superadmin',
            params: {
              'p_request_id': requestId,
              'p_notice_id': noticeId,
              'p_expected_version': expectedVersion,
              'p_status': _statusValue(status),
              'p_reason': _nullable(reason),
            },
          ),
        ),
      );
    } on PostgrestException catch (error) {
      throw _error(error);
    } on ClientException {
      throw const NoticeUnavailableException();
    }
  }
}

Map<String, Object?> _draftPayload(NoticeDraft draft) => {
  'type': draft.type.storageValue,
  'title': draft.title.trim(),
  'body': draft.message.trim(),
  'priority': draft.priority.name,
  'audience': draft.audienceSelection.toJson(),
  'audience_label': draft.audienceLabel.trim(),
  'behavior': _behaviorValue(draft.behavior),
  'target_device': draft.targetDevice.name,
  'content_format': _contentFormatValue(draft.contentFormat),
  'background_color': _color(draft.backgroundColorValue),
  'text_color': _color(draft.textColorValue),
  'button_color': _color(draft.buttonColorValue),
  'popup_size': draft.popupSize.name,
  'has_outer_inset': draft.hasOuterInset,
  'button_label': draft.buttonLabel.trim(),
  'link_label': _nullable(draft.linkLabel),
  'recurrence': _recurrenceValue(draft.recurrence),
  'interval_days': draft.intervalDays,
  'weekly_days': draft.weeklyDays,
  'day_of_month': draft.dayOfMonth,
  'recurrence_until': draft.recurrenceUntil?.toUtc().toIso8601String(),
  'image_orientation': draft.imageOrientation.name,
  'starts_at': draft.startsAt?.toUtc().toIso8601String(),
  'ends_at': draft.endsAt?.toUtc().toIso8601String(),
};

PlatformNotice _notice(Map<String, dynamic> value) {
  final selection = NoticeAudienceSelection.fromJson(_map(value['audience']));
  final status = _noticeStatus(value['status']);
  return PlatformNotice(
    type: communicationTypeFromStorage(value['type'] ?? value['notice_type']),
    id: _string(value['id']),
    title: _string(value['title']),
    message: _string(value['body'] ?? value['message']),
    priority: _enum(
      NoticePriority.values,
      _string(value['priority']),
      fallback: NoticePriority.routine,
    ),
    status: status,
    startsAt: _date(value['starts_at']) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    endsAt: _date(value['ends_at']),
    audience: _legacyAudience(selection),
    audienceLabel: _string(value['audience_label'], fallback: 'Público selecionado'),
    audienceSelection: selection,
    behavior: _behavior(value['behavior']),
    targetDevice: _enum(
      NoticeTargetDevice.values,
      _string(value['target_device']),
      fallback: NoticeTargetDevice.all,
    ),
    reach: _integer(value['reach']),
    contentFormat: _string(value['content_format']) == 'image'
        ? NoticeContentFormat.image
        : NoticeContentFormat.textBackground,
    backgroundColorValue: _parseColor(value['background_color']),
    textColorValue: _parseColor(value['text_color']),
    buttonColorValue: _parseColor(value['button_color']),
    popupSize: _enum(
      NoticePopupSize.values,
      _string(value['popup_size']),
      fallback: NoticePopupSize.standard,
    ),
    hasOuterInset: value['has_outer_inset'] as bool? ?? true,
    recurrence: _recurrence(value['recurrence']),
    intervalDays: _nullableInteger(value['interval_days']),
    weeklyDays: _list(value['weekly_days']).map(_integer).toList(growable: false),
    dayOfMonth: _nullableInteger(value['day_of_month']),
    recurrenceUntil: _date(value['recurrence_until']),
    imageOrientation: _enum(
      NoticeImageOrientation.values,
      _string(value['image_orientation']),
      fallback: NoticeImageOrientation.vertical,
    ),
    buttonLabel: _string(value['button_label'], fallback: 'Confirmar'),
    linkLabel: _nullable(value['link_label']),
    deliveredCount: _integer(value['delivered_count']),
    viewedCount: _integer(value['viewed_count']),
    acceptedCount: _integer(value['accepted_count']),
    managementVersion: _integer(value['management_version']),
  );
}

NoticeAudience _legacyAudience(NoticeAudienceSelection selection) {
  if (selection.rules.length != 1) return NoticeAudience.everyone;
  return switch (selection.rules.single.dimension) {
    NoticeAudienceDimension.platform => NoticeAudience.everyone,
    NoticeAudienceDimension.institution => NoticeAudience.institution,
    NoticeAudienceDimension.unit => NoticeAudience.unit,
    NoticeAudienceDimension.group => NoticeAudience.group,
    NoticeAudienceDimension.person => NoticeAudience.person,
    NoticeAudienceDimension.role => NoticeAudience.role,
    NoticeAudienceDimension.plan => NoticeAudience.everyone,
  };
}

String _statusValue(NoticeStatus value) => switch (value) {
  NoticeStatus.ended => 'expired',
  NoticeStatus.cancelled => 'inactive',
  _ => value.name,
};

String _behaviorValue(NoticeBehavior value) => switch (value) {
  NoticeBehavior.dismissible => 'dismissible',
  NoticeBehavior.confirmation => 'confirmation',
  NoticeBehavior.checkboxConfirmation => 'checkbox_confirmation',
};

NoticeBehavior _behavior(Object? value) => switch (_string(value)) {
  'confirmation' => NoticeBehavior.confirmation,
  'checkbox_confirmation' => NoticeBehavior.checkboxConfirmation,
  _ => NoticeBehavior.dismissible,
};

String _contentFormatValue(NoticeContentFormat value) =>
    value == NoticeContentFormat.image ? 'image' : 'text_background';

String _recurrenceValue(NoticeRecurrence value) => switch (value) {
  NoticeRecurrence.oneTime => 'one_time',
  _ => value.name,
};

NoticeRecurrence _recurrence(Object? value) => switch (_string(value)) {
  'daily' => NoticeRecurrence.daily,
  'weekly' => NoticeRecurrence.weekly,
  'monthly' => NoticeRecurrence.monthly,
  'interval' => NoticeRecurrence.interval,
  _ => NoticeRecurrence.oneTime,
};

NoticeStatus _noticeStatus(Object? value) => switch (_string(value)) {
  'draft' => NoticeStatus.draft,
  'scheduled' => NoticeStatus.scheduled,
  'active' => NoticeStatus.active,
  'paused' => NoticeStatus.paused,
  'expired' => NoticeStatus.ended,
  'inactive' => NoticeStatus.cancelled,
  _ => throw const NoticeUnexpectedException(),
};

T _enum<T extends Enum>(
  List<T> values,
  String raw, {
  required T fallback,
  Map<String, T> aliases = const {},
}) {
  if (aliases[raw] case final result?) return result;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}

Map<String, dynamic> _map(Object? raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is List && raw.length == 1 && raw.first is Map) {
    return Map<String, dynamic>.from(raw.first as Map);
  }
  return const {};
}

List<dynamic> _list(Object? raw) => raw is List ? raw : const [];
String _string(Object? value, {String fallback = ''}) => _nullable(value) ?? fallback;
String? _nullable(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

DateTime? _date(Object? value) => DateTime.tryParse(_string(value))?.toUtc();
int _integer(Object? value) => _nullableInteger(value) ?? 0;
int? _nullableInteger(Object? value) => value is num ? value.toInt() : int.tryParse(_string(value));

String? _color(int? value) =>
    value == null ? null : '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

int? _parseColor(Object? value) {
  final text = _string(value).replaceFirst('#', '');
  if (text.length != 6) return null;
  final rgb = int.tryParse(text, radix: 16);
  return rgb == null ? null : 0xFF000000 | rgb;
}

Exception _error(PostgrestException error) => switch (error.code) {
  '42501' || 'PGRST301' || 'PGRST302' => const NoticeUnauthorizedException(),
  'PGRST116' || 'P0002' => const NoticeNotFoundException(),
  '23505' || '40001' || 'P0003' => const NoticeConflictException(),
  '22023' || '23502' || '23503' || '23514' || 'P0001' => const NoticeValidationException(),
  'PGRST000' || 'PGRST001' || 'PGRST002' || 'PGRST003' => const NoticeUnavailableException(),
  _ => const NoticeUnexpectedException(),
};
