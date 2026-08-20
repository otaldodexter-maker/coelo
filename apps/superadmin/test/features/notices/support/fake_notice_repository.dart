import 'package:coelo_superadmin/features/notices/domain/notice_repository.dart';
import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';

final class FakeNoticeRepository implements NoticeRepository {
  FakeNoticeRepository({Object? store, DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final List<PlatformNotice> _items = [];
  final Map<NoticeAudienceDimension, List<NoticeAudienceOption>> audienceOptions = {};
  NoticeRepositoryException? nextError;
  int _nextId = 1;

  List<PlatformNotice> get items => List.unmodifiable(_items);

  PlatformNotice create(NoticeDraft draft) {
    final notice = _fromDraft(draft, id: 'notice-${_nextId++}');
    _items.add(notice);
    return notice;
  }

  void seed(PlatformNotice notice) => _items.add(notice);

  @override
  Future<NoticePage> fetchPage(NoticeDirectoryQuery query) async {
    _throwNext();
    final search = query.search?.trim().toLowerCase();
    final filtered =
        _items.where((notice) {
          if (search != null &&
              search.isNotEmpty &&
              !notice.title.toLowerCase().contains(search) &&
              !notice.message.toLowerCase().contains(search)) {
            return false;
          }
          if (query.statuses.isNotEmpty && !query.statuses.contains(notice.status)) {
            return false;
          }
          if (query.priorities.isNotEmpty && !query.priorities.contains(notice.priority)) {
            return false;
          }
          if (query.types.isNotEmpty && !query.types.contains(notice.type)) return false;
          if (query.cursorOccurredAt case final cursor?) {
            final byDate = notice.startsAt.compareTo(cursor);
            if (byDate > 0 || (byDate == 0 && notice.id.compareTo(query.cursorId ?? '') >= 0)) {
              return false;
            }
          }
          return true;
        }).toList()..sort((a, b) {
          final byDate = b.startsAt.compareTo(a.startsAt);
          return byDate != 0 ? byDate : b.id.compareTo(a.id);
        });
    final page = filtered.take(query.pageSize).toList(growable: false);
    final more = filtered.length > page.length;
    return NoticePage(
      items: page,
      nextCursorOccurredAt: more ? page.last.startsAt : null,
      nextCursorId: more ? page.last.id : null,
    );
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
    _throwNext();
    final query = search?.trim().toLowerCase();
    final filtered =
        (audienceOptions[dimension] ?? const <NoticeAudienceOption>[])
            .where(
              (option) =>
                  (query == null || query.isEmpty || option.label.toLowerCase().contains(query)) &&
                  (parentIds.isEmpty || parentIds.contains(option.parentId)),
            )
            .toList()
          ..sort((a, b) => a.label.compareTo(b.label));
    final page = filtered.take(pageSize).toList(growable: false);
    final more = filtered.length > page.length;
    return NoticeAudienceOptionsPage(
      items: page,
      nextCursorLabel: more ? page.last.label : null,
      nextCursorId: more ? page.last.id : null,
    );
  }

  @override
  Future<PlatformNotice> getById(String noticeId) async {
    _throwNext();
    return _find(noticeId);
  }

  @override
  Future<PlatformNotice> saveDraft(
    NoticeDraft draft, {
    required String requestId,
    String? noticeId,
    int? expectedVersion,
  }) async {
    _throwNext();
    if (draft.title.trim().isEmpty || draft.message.trim().isEmpty) {
      throw const NoticeValidationException();
    }
    if (noticeId == null) return create(draft);
    final current = _find(noticeId);
    _checkVersion(current, expectedVersion);
    final updated = _fromDraft(
      draft,
      id: noticeId,
      status: current.status,
      version: current.managementVersion + 1,
    );
    _replace(updated);
    return updated;
  }

  @override
  Future<PlatformNotice> publish(
    PlatformNotice notice, {
    required String requestId,
    required int expectedVersion,
  }) async {
    _throwNext();
    final current = _find(notice.id);
    _checkVersion(current, expectedVersion);
    final updated = current.copyWith(
      status: current.startsAt.isAfter(_now()) ? NoticeStatus.scheduled : NoticeStatus.active,
      managementVersion: current.managementVersion + 1,
    );
    _replace(updated);
    return updated;
  }

  @override
  Future<PlatformNotice> changeStatus(
    String noticeId, {
    required String requestId,
    required NoticeStatus status,
    required int expectedVersion,
    String? reason,
  }) async {
    _throwNext();
    final current = _find(noticeId);
    _checkVersion(current, expectedVersion);
    final updated = current.copyWith(
      status: status,
      managementVersion: current.managementVersion + 1,
    );
    _replace(updated);
    return updated;
  }

  PlatformNotice _fromDraft(
    NoticeDraft draft, {
    required String id,
    NoticeStatus status = NoticeStatus.draft,
    int version = 0,
  }) => PlatformNotice(
    type: draft.type,
    id: id,
    title: draft.title,
    message: draft.message,
    priority: draft.priority,
    status: status,
    startsAt: draft.startsAt ?? _now(),
    endsAt: draft.endsAt,
    audience: draft.audience,
    audienceLabel: draft.audienceLabel,
    behavior: draft.behavior,
    targetDevice: draft.targetDevice,
    reach: 0,
    contentFormat: draft.contentFormat,
    backgroundColorValue: draft.backgroundColorValue,
    textColorValue: draft.textColorValue,
    buttonColorValue: draft.buttonColorValue,
    popupSize: draft.popupSize,
    hasOuterInset: draft.hasOuterInset,
    audienceSelection: draft.audienceSelection,
    recurrence: draft.recurrence,
    intervalDays: draft.intervalDays,
    weeklyDays: draft.weeklyDays,
    dayOfMonth: draft.dayOfMonth,
    recurrenceUntil: draft.recurrenceUntil,
    imageOrientation: draft.imageOrientation,
    backgroundTone: draft.backgroundTone,
    textTone: draft.textTone,
    buttonLabel: draft.buttonLabel,
    managementVersion: version,
  );

  PlatformNotice _find(String id) {
    for (final notice in _items) {
      if (notice.id == id) return notice;
    }
    throw const NoticeNotFoundException();
  }

  void _replace(PlatformNotice notice) {
    final index = _items.indexWhere((item) => item.id == notice.id);
    if (index < 0) throw const NoticeNotFoundException();
    _items[index] = notice;
  }

  void _checkVersion(PlatformNotice notice, int? expected) {
    if (expected != null && notice.managementVersion != expected) {
      throw const NoticeConflictException();
    }
  }

  void _throwNext() {
    final error = nextError;
    nextError = null;
    if (error != null) throw error;
  }
}
