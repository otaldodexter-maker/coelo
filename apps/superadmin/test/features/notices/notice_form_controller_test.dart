import 'dart:async';

import 'package:coelo_superadmin/features/notices/domain/notice_repository.dart';
import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_form_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_notice_repository.dart';

void main() {
  test('changing away from Aviso removes popup-only configuration', () {
    final controller = NoticeFormController(repository: FakeNoticeRepository());
    addTearDown(controller.dispose);
    controller
      ..setBehavior(NoticeBehavior.checkboxConfirmation)
      ..setPopupSize(NoticePopupSize.fullscreen)
      ..setType(CommunicationType.forYou);

    expect(controller.type, CommunicationType.forYou);
    expect(controller.behavior, NoticeBehavior.dismissible);
    expect(controller.popupSize, NoticePopupSize.standard);
    expect(controller.hasOuterInset, isTrue);
    expect(controller.draft.isPopup, isFalse);
  });

  test('select-all freezes the normalized audience search', () async {
    final controller = NoticeFormController(repository: FakeNoticeRepository());
    addTearDown(controller.dispose);
    controller.setAudience(NoticeAudience.institution);
    await controller.loadAudienceOptions(search: '  Centro  ');
    controller.setAudienceTargets(selectAll: true, selectedIds: const {}, excludedIds: const {});

    expect(controller.audienceSelection.rules.single.filters, const {
      'search': ['Centro'],
    });
  });

  test('changing or clearing a select-all search resets it instead of widening it', () async {
    final controller = NoticeFormController(repository: FakeNoticeRepository());
    addTearDown(controller.dispose);
    controller.setAudience(NoticeAudience.institution);
    await controller.loadAudienceOptions(search: 'Centro');
    controller.setAudienceTargets(selectAll: true, selectedIds: const {}, excludedIds: const {});

    await controller.loadAudienceOptions(search: 'Norte');

    expect(controller.audienceSelection.rules.single.selectAll, isFalse);
    expect(controller.audienceSelection.rules.single.targetIds, isEmpty);
    expect(controller.audienceLabelController.text, isEmpty);

    controller.setAudienceTargets(selectAll: true, selectedIds: const {}, excludedIds: const {});
    await controller.loadAudienceOptions(search: '');

    expect(controller.audienceSelection.rules.single.selectAll, isFalse);
    expect(controller.audienceSelection.rules.single.filters, isEmpty);
  });

  test('loads every explicit audience page with repository cursors', () async {
    final repository = _PagedAudienceRepository();
    final controller = NoticeFormController(repository: repository);
    addTearDown(controller.dispose);

    controller.setAudience(NoticeAudience.institution);
    await Future<void>.delayed(Duration.zero);

    expect(controller.audienceOptions.map((option) => option.id), ['institution-1']);
    expect(controller.hasMoreAudienceOptions, isTrue);

    await controller.loadMoreAudienceOptions();

    expect(controller.audienceOptions.map((option) => option.id), [
      'institution-1',
      'institution-2',
    ]);
    expect(controller.hasMoreAudienceOptions, isFalse);
    expect(repository.requestedCursors, [(null, null), ('Aurora', 'institution-1')]);
  });

  test('does not offer direct person targeting without a trusted scope', () {
    expect(NoticeFormController.allowedAudiences, isNot(contains(NoticeAudience.person)));
  });

  test('an older audience response cannot overwrite the latest search', () async {
    final repository = _OrderedAudienceRepository();
    final controller = NoticeFormController(repository: repository);
    addTearDown(controller.dispose);
    controller.setAudience(NoticeAudience.institution);
    final first = controller.loadAudienceOptions(search: 'antigo');
    final second = controller.loadAudienceOptions(search: 'novo');
    repository.second.complete(
      const NoticeAudienceOptionsPage(
        items: [NoticeAudienceOption(id: 'new', label: 'Novo')],
      ),
    );
    await second;
    repository.first.complete(
      const NoticeAudienceOptionsPage(
        items: [NoticeAudienceOption(id: 'old', label: 'Antigo')],
      ),
    );
    await first;

    expect(controller.audienceOptions.single.id, 'new');
  });
}

final class _PagedAudienceRepository extends _OrderedAudienceRepository {
  final List<(String?, String?)> requestedCursors = [];

  @override
  Future<NoticeAudienceOptionsPage> fetchAudienceOptions({
    required NoticeAudienceDimension dimension,
    String? search,
    List<String> parentIds = const [],
    String? cursorLabel,
    String? cursorId,
    int pageSize = 30,
  }) async {
    requestedCursors.add((cursorLabel, cursorId));
    if (cursorId == null) {
      return const NoticeAudienceOptionsPage(
        items: [NoticeAudienceOption(id: 'institution-1', label: 'Aurora')],
        nextCursorLabel: 'Aurora',
        nextCursorId: 'institution-1',
      );
    }
    return const NoticeAudienceOptionsPage(
      items: [NoticeAudienceOption(id: 'institution-2', label: 'Centro')],
    );
  }
}

class _OrderedAudienceRepository implements NoticeRepository {
  final first = Completer<NoticeAudienceOptionsPage>();
  final second = Completer<NoticeAudienceOptionsPage>();
  int calls = 0;

  @override
  Future<NoticeAudienceOptionsPage> fetchAudienceOptions({
    required NoticeAudienceDimension dimension,
    String? search,
    List<String> parentIds = const [],
    String? cursorLabel,
    String? cursorId,
    int pageSize = 30,
  }) {
    calls += 1;
    return calls == 1 ? first.future : second.future;
  }

  @override
  Future<NoticePage> fetchPage(NoticeDirectoryQuery query) => throw UnimplementedError();

  @override
  Future<PlatformNotice> getById(String noticeId) => throw UnimplementedError();

  @override
  Future<PlatformNotice> saveDraft(
    NoticeDraft draft, {
    required String requestId,
    String? noticeId,
    int? expectedVersion,
  }) => throw UnimplementedError();

  @override
  Future<PlatformNotice> publish(
    PlatformNotice notice, {
    required String requestId,
    required int expectedVersion,
  }) => throw UnimplementedError();

  @override
  Future<PlatformNotice> changeStatus(
    String noticeId, {
    required String requestId,
    required NoticeStatus status,
    required int expectedVersion,
    String? reason,
  }) => throw UnimplementedError();
}
