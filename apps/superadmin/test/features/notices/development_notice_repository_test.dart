import 'package:coelo_superadmin/features/notices/data/development_notice_repository.dart';
import 'package:coelo_superadmin/features/notices/domain/notice_repository.dart';
import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('seeds realistic content exclusively through the development repository', () async {
    final repository = DevelopmentNoticeRepository(now: () => DateTime.utc(2026, 8, 27, 12));

    final page = await repository.fetchPage(
      const NoticeDirectoryQuery(types: {CommunicationType.content}),
    );

    expect(page.items, hasLength(greaterThanOrEqualTo(3)));
    expect(page.items.every((notice) => notice.type == CommunicationType.content), isTrue);
    expect(page.items.map((notice) => notice.title), contains('Volta às aulas com acolhimento'));
    expect(page.items.every((notice) => notice.message.length > 30), isTrue);
  });

  test('seeds coherent notices across multiple directory pages', () async {
    final repository = DevelopmentNoticeRepository(now: () => DateTime.utc(2026, 8, 27, 12));

    final first = await repository.fetchPage(const NoticeDirectoryQuery(pageSize: 8));
    final second = await repository.fetchPage(
      NoticeDirectoryQuery(
        pageSize: 8,
        cursorOccurredAt: first.nextCursorOccurredAt,
        cursorId: first.nextCursorId,
      ),
    );

    expect(first.items, hasLength(8));
    expect(second.items, hasLength(8));
    expect(first.nextCursorId, isNotNull);
    expect(second.nextCursorId, isNotNull);
    expect(
      first.items.map((notice) => notice.id).toSet(),
      isNot(containsAll(second.items.map((notice) => notice.id))),
    );
    expect(
      [...first.items, ...second.items].map((notice) => notice.type).toSet(),
      containsAll(CommunicationType.values),
    );
    expect(
      [...first.items, ...second.items].map((notice) => notice.title),
      containsAll(<String>[
        'Recesso escolar de primavera',
        'Boletim do segundo bimestre disponível',
        'Semana do Meio Ambiente',
        'Dicas para uma rotina de estudos',
      ]),
    );

    final ended = await repository.fetchPage(
      const NoticeDirectoryQuery(statuses: {NoticeStatus.ended}),
    );
    expect(ended.items, isNotEmpty);
    expect(
      ended.items.every(
        (notice) => notice.endsAt != null && !notice.endsAt!.isAfter(DateTime.utc(2026, 8, 27, 12)),
      ),
      isTrue,
    );
  });
}
