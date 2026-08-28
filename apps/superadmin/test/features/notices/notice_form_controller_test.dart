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

  test('a pending save cannot publish state after the controller is disposed', () async {
    final repository = _PendingSaveRepository();
    final controller = NoticeFormController(repository: repository);
    controller.titleController.text = 'Rascunho A';
    controller.messageController.text = 'Mensagem A';

    final save = controller.saveDraft();
    controller.dispose();
    repository.pending.single.complete(_notice('notice-a', 'Rascunho A'));

    await expectLater(save, completion(isNull));
  });

  test('editing during save ignores stale response and releases the save guard', () async {
    final repository = _PendingSaveRepository();
    final controller = NoticeFormController(repository: repository);
    addTearDown(controller.dispose);
    controller.titleController.text = 'Rascunho A';
    controller.messageController.text = 'Mensagem A';

    final first = controller.saveDraft();
    controller.titleController.text = 'Rascunho B';
    repository.pending.first.complete(_notice('notice-a', 'Rascunho A'));
    await expectLater(first, completion(isNull));
    expect(controller.isSaving, isFalse);
    expect(controller.titleController.text, 'Rascunho B');

    final second = controller.saveDraft();
    expect(repository.pending, hasLength(2));
    repository.pending[1].complete(
      _notice('notice-a', 'Rascunho B').copyWith(managementVersion: 1),
    );
    await expectLater(
      second,
      completion(
        isA<PlatformNotice>()
            .having((notice) => notice.id, 'id', 'notice-a')
            .having((notice) => notice.managementVersion, 'version', 1),
      ),
    );
  });

  test('load fails closed when repository returns another notice id', () async {
    final controller = NoticeFormController(
      repository: _MismatchedLoadRepository(),
      noticeId: 'notice-a',
    );
    addTearDown(controller.dispose);

    await controller.ready;

    expect(controller.savedNotice, isNull);
    expect(controller.loadFailure, isA<NoticeUnexpectedException>());
  });

  test('reconciles a persisted create before saving an edited retry', () async {
    final repository = _AmbiguousSaveRepository();
    final controller = NoticeFormController(repository: repository);
    addTearDown(controller.dispose);
    controller.titleController.text = 'Rascunho A';
    controller.messageController.text = 'Mensagem A';

    await expectLater(controller.saveDraft(), completion(isNull));
    expect(repository.creates, 1);
    expect(repository.item?.title, 'Rascunho A');

    controller.titleController.text = 'Rascunho B';
    final saved = await controller.saveDraft();

    expect(saved?.id, 'notice-1');
    expect(saved?.title, 'Rascunho B');
    expect(saved?.managementVersion, 1);
    expect(repository.creates, 1);
    expect(repository.item?.id, 'notice-1');
    expect(repository.item?.title, 'Rascunho B');
    expect(repository.requestIds, hasLength(3));
    expect(repository.requestIds[1], repository.requestIds[0]);
    expect(repository.requestIds[2], isNot(repository.requestIds[0]));
  });

  test('replays the same pending create intent after a lost response', () async {
    final repository = _AmbiguousSaveRepository();
    final controller = NoticeFormController(repository: repository);
    addTearDown(controller.dispose);
    controller.titleController.text = 'Rascunho A';
    controller.messageController.text = 'Mensagem A';

    await expectLater(controller.saveDraft(), completion(isNull));
    final saved = await controller.saveDraft();

    expect(saved?.id, 'notice-1');
    expect(saved?.title, 'Rascunho A');
    expect(saved?.managementVersion, 0);
    expect(repository.creates, 1);
    expect(repository.requestIds, hasLength(2));
    expect(repository.requestIds[1], repository.requestIds[0]);
  });

  test('editing during a replay requires a new explicit save', () async {
    final repository = _AmbiguousSaveRepository(deferReplay: true);
    final controller = NoticeFormController(repository: repository);
    addTearDown(controller.dispose);
    controller.titleController.text = 'Rascunho A';
    controller.messageController.text = 'Mensagem A';

    await expectLater(controller.saveDraft(), completion(isNull));
    controller.titleController.text = 'Rascunho B';
    final replay = controller.saveDraft();
    expect(repository.requestIds, hasLength(2));

    controller.titleController.text = 'Rascunho C';
    repository.completeReplay();
    await expectLater(replay, completion(isNull));

    expect(repository.requestIds, hasLength(2));
    expect(controller.savedNotice?.id, 'notice-1');
    expect(controller.savedNotice?.managementVersion, 0);
    expect(controller.titleController.text, 'Rascunho C');

    final saved = await controller.saveDraft();
    expect(saved?.id, 'notice-1');
    expect(saved?.title, 'Rascunho C');
    expect(saved?.managementVersion, 1);
    expect(repository.requestIds, hasLength(3));
    expect(repository.requestIds[2], isNot(repository.requestIds[0]));
  });

  test('rejects a save receipt with an impossible version', () async {
    final controller = NoticeFormController(repository: _WrongSaveReceiptRepository());
    addTearDown(controller.dispose);
    controller.titleController.text = 'Rascunho';
    controller.messageController.text = 'Mensagem';

    final saved = await controller.saveDraft();

    expect(saved, isNull);
    expect(controller.savedNotice, isNull);
    expect(controller.errorMessage, const NoticeUnexpectedException().safeMessage);
  });

  test('replays an ambiguous publish with the same request id', () async {
    final repository = _PublishRetryRepository(ambiguousFirstPublish: true);
    final controller = NoticeFormController(repository: repository);
    addTearDown(controller.dispose);
    controller.titleController.text = 'Aviso';
    controller.messageController.text = 'Mensagem';

    await expectLater(controller.saveAndPublish(), completion(isNull));
    final published = await controller.saveAndPublish();

    expect(published?.status, NoticeStatus.active);
    expect(published?.managementVersion, 1);
    expect(repository.saveCalls, 1);
    expect(repository.publishRequestIds, hasLength(2));
    expect(repository.publishRequestIds[1], repository.publishRequestIds[0]);
  });

  test('reconciles an ambiguous publish before saving an edit', () async {
    final repository = _PublishRetryRepository(ambiguousFirstPublish: true);
    final controller = NoticeFormController(repository: repository);
    addTearDown(controller.dispose);
    controller.titleController.text = 'Aviso A';
    controller.messageController.text = 'Mensagem';

    await expectLater(controller.saveAndPublish(), completion(isNull));
    controller.titleController.text = 'Aviso B';
    final published = await controller.saveAndPublish();

    expect(published?.id, 'notice-1');
    expect(published?.title, 'Aviso B');
    expect(published?.status, NoticeStatus.active);
    expect(published?.managementVersion, 3);
    expect(repository.saveCalls, 2);
    expect(repository.saveNoticeIds, [null, 'notice-1']);
    expect(repository.saveExpectedVersions, [null, 1]);
    expect(repository.publishRequestIds, hasLength(3));
    expect(repository.publishRequestIds[1], repository.publishRequestIds[0]);
    expect(repository.publishRequestIds[2], isNot(repository.publishRequestIds[0]));
  });

  test('clears a deterministic publish intent before retry', () async {
    final repository = _PublishRetryRepository(conflictFirstPublish: true);
    final controller = NoticeFormController(repository: repository);
    addTearDown(controller.dispose);
    controller.titleController.text = 'Aviso';
    controller.messageController.text = 'Mensagem';

    await expectLater(controller.saveAndPublish(), completion(isNull));
    final published = await controller.saveAndPublish();

    expect(published?.status, NoticeStatus.active);
    expect(published?.managementVersion, 2);
    expect(repository.saveCalls, 2);
    expect(repository.publishRequestIds, hasLength(2));
    expect(repository.publishRequestIds[1], isNot(repository.publishRequestIds[0]));
  });
}

PlatformNotice _notice(String id, String title) => PlatformNotice(
  id: id,
  title: title,
  message: 'Mensagem',
  priority: NoticePriority.important,
  status: NoticeStatus.draft,
  startsAt: DateTime(2026, 8, 27),
  endsAt: null,
  audience: NoticeAudience.everyone,
  audienceLabel: 'Todos',
  behavior: NoticeBehavior.confirmation,
  targetDevice: NoticeTargetDevice.all,
  reach: 0,
);

final class _PendingSaveRepository implements NoticeRepository {
  final pending = <Completer<PlatformNotice>>[];

  @override
  Future<PlatformNotice> saveDraft(
    NoticeDraft draft, {
    required String requestId,
    String? noticeId,
    int? expectedVersion,
  }) {
    final request = Completer<PlatformNotice>();
    pending.add(request);
    return request.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _MismatchedLoadRepository implements NoticeRepository {
  @override
  Future<PlatformNotice> getById(String noticeId) async => _notice('notice-b', 'Outro aviso');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _AmbiguousSaveRepository implements NoticeRepository {
  _AmbiguousSaveRepository({this.deferReplay = false});

  final bool deferReplay;
  final Map<String, PlatformNotice> _receipts = {};
  final List<String> requestIds = [];
  PlatformNotice? item;
  int creates = 0;
  bool _dropFirstResponse = true;
  Completer<PlatformNotice>? _pendingReplay;

  void completeReplay() {
    final pending = _pendingReplay;
    if (pending == null) throw StateError('No replay is pending.');
    pending.complete(_receipts[requestIds.last]!);
    _pendingReplay = null;
  }

  @override
  Future<PlatformNotice> saveDraft(
    NoticeDraft draft, {
    required String requestId,
    String? noticeId,
    int? expectedVersion,
  }) async {
    requestIds.add(requestId);
    if (_receipts[requestId] case final replay?) {
      if (!deferReplay) return replay;
      return (_pendingReplay = Completer<PlatformNotice>()).future;
    }
    final current = item;
    final saved = noticeId == null
        ? _notice('notice-${++creates}', draft.title)
        : _notice(
            noticeId,
            draft.title,
          ).copyWith(managementVersion: (current?.managementVersion ?? 0) + 1);
    item = saved;
    _receipts[requestId] = saved;
    if (_dropFirstResponse) {
      _dropFirstResponse = false;
      throw const NoticeUnavailableException();
    }
    return saved;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _WrongSaveReceiptRepository implements NoticeRepository {
  @override
  Future<PlatformNotice> saveDraft(
    NoticeDraft draft, {
    required String requestId,
    String? noticeId,
    int? expectedVersion,
  }) async => _notice('notice-wrong', draft.title).copyWith(managementVersion: 4);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _PublishRetryRepository implements NoticeRepository {
  _PublishRetryRepository({this.ambiguousFirstPublish = false, this.conflictFirstPublish = false});

  final bool ambiguousFirstPublish;
  final bool conflictFirstPublish;
  final Map<String, PlatformNotice> _publishReceipts = {};
  final List<String> publishRequestIds = [];
  final List<String?> saveNoticeIds = [];
  final List<int?> saveExpectedVersions = [];
  int saveCalls = 0;
  bool _firstPublish = true;

  @override
  Future<PlatformNotice> saveDraft(
    NoticeDraft draft, {
    required String requestId,
    String? noticeId,
    int? expectedVersion,
  }) async {
    saveCalls++;
    saveNoticeIds.add(noticeId);
    saveExpectedVersions.add(expectedVersion);
    final version = noticeId == null ? 0 : (expectedVersion ?? -1) + 1;
    return _notice(noticeId ?? 'notice-1', draft.title).copyWith(managementVersion: version);
  }

  @override
  Future<PlatformNotice> publish(
    PlatformNotice notice, {
    required String requestId,
    required int expectedVersion,
  }) async {
    publishRequestIds.add(requestId);
    if (_publishReceipts[requestId] case final replay?) return replay;
    if (_firstPublish && conflictFirstPublish) {
      _firstPublish = false;
      throw const NoticeConflictException();
    }
    final published = notice.copyWith(
      status: NoticeStatus.active,
      managementVersion: expectedVersion + 1,
    );
    _publishReceipts[requestId] = published;
    if (_firstPublish && ambiguousFirstPublish) {
      _firstPublish = false;
      throw const NoticeUnavailableException();
    }
    _firstPublish = false;
    return published;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
