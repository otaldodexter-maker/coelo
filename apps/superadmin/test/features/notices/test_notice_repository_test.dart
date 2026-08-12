import 'package:coelo_superadmin/features/notices/domain/notice_repository.dart';
import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_notice_repository.dart';

void main() {
  late FakeNoticeRepository repository;

  setUp(() {
    repository = FakeNoticeRepository(now: () => DateTime.utc(2026, 8, 12, 12));
  });

  test('saves and publishes through the async production contract', () async {
    final draft = await repository.saveDraft(
      _draft('Aviso real'),
      requestId: '11111111-1111-4111-8111-111111111111',
    );

    expect(draft.status, NoticeStatus.draft);
    expect(draft.managementVersion, 0);

    final published = await repository.publish(
      draft,
      requestId: '22222222-2222-4222-8222-222222222222',
      expectedVersion: draft.managementVersion,
    );

    expect(published.status, NoticeStatus.active);
    expect(published.managementVersion, 1);
    expect((await repository.getById(draft.id)).status, NoticeStatus.active);
  });

  test('fails closed on stale versions and injected authorization errors', () async {
    final draft = repository.create(_draft('Concorrência'));

    await expectLater(
      repository.publish(
        draft,
        requestId: '33333333-3333-4333-8333-333333333333',
        expectedVersion: 99,
      ),
      throwsA(isA<NoticeConflictException>()),
    );

    repository.nextError = const NoticeUnauthorizedException();
    await expectLater(
      repository.fetchPage(const NoticeDirectoryQuery()),
      throwsA(isA<NoticeUnauthorizedException>()),
    );
  });

  test('applies server-style filters and cursor pagination', () async {
    for (var index = 0; index < 3; index++) {
      repository.create(
        _draft(
          'Aviso $index',
          priority: index == 2 ? NoticePriority.urgent : NoticePriority.routine,
          startsAt: DateTime.utc(2026, 8, 12, 10 + index),
        ),
      );
    }

    final first = await repository.fetchPage(
      const NoticeDirectoryQuery(priorities: {NoticePriority.routine}, pageSize: 1),
    );
    final second = await repository.fetchPage(
      NoticeDirectoryQuery(
        priorities: const {NoticePriority.routine},
        pageSize: 1,
        cursorOccurredAt: first.nextCursorOccurredAt,
        cursorId: first.nextCursorId,
      ),
    );

    expect(first.items.single.title, 'Aviso 1');
    expect(first.nextCursorId, isNotNull);
    expect(second.items.single.title, 'Aviso 0');
  });
}

NoticeDraft _draft(
  String title, {
  NoticePriority priority = NoticePriority.routine,
  DateTime? startsAt,
}) => NoticeDraft(
  title: title,
  message: 'Mensagem segura',
  priority: priority,
  audience: NoticeAudience.everyone,
  audienceLabel: 'Todos',
  behavior: NoticeBehavior.dismissible,
  startsAt: startsAt,
);
