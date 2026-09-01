import 'package:coelo_superadmin/features/chat/data/development_chat_repository.dart';
import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('provides coherent development conversations across more than one page', () async {
    final repository = DevelopmentChatRepository(now: () => DateTime.utc(2026, 9));

    final first = await repository.fetchInbox(const ChatInboxQuery(pageSize: 8));
    expect(first.items, hasLength(8));
    expect(first.totalCount, greaterThan(8));
    expect(first.hasMore, isTrue);
    expect(first.nextCursor, isNotNull);

    final second = await repository.fetchInbox(
      ChatInboxQuery(pageSize: 8, cursor: first.nextCursor),
    );
    expect(second.items, isNotEmpty);
    expect(second.totalCount, first.totalCount);
    expect(second.hasMore, isFalse);
    expect(second.items.map((item) => item.id), isNot(contains(first.items.first.id)));

    final thread = await repository.fetchThread(
      ChatThreadQuery(conversationId: second.items.first.id),
    );
    expect(thread.items, isNotEmpty);
    expect(thread.items.first.conversationId, second.items.first.id);
  });
}
