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
}
