import 'dart:typed_data';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:coelo_superadmin/features/chat/presentation/screens/superadmin_chat_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// C07 - Chat: the inbox pagination footer paints over the 1 px border and the
/// rounded bottom-left corner of the chat card (DecoratedBox without ClipRRect).
///
/// Contract under test: the card's left border is one continuous line of
/// `outlineVariant`, whether the sampled row is above or inside the footer band.
void main() {
  testWidgets('chat card left border stays continuous under the inbox pagination footer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const boundaryKey = Key('acceptance-chat-repaint-boundary');
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          theme: CoeloTheme.light,
          home: SuperadminChatPage(logout: _logout, chatRepository: _FakeChatRepository()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final footer = find.byType(SuperadminListingPaginationFooter);
    expect(footer, findsOneWidget);
    final card = find
        .ancestor(
          of: footer,
          matching: find.byWidgetPredicate((widget) {
            if (widget is! DecoratedBox) return false;
            final decoration = widget.decoration;
            return decoration is BoxDecoration &&
                decoration.border != null &&
                decoration.borderRadius == BorderRadius.circular(CoeloRadius.lg);
          }),
        )
        .first;

    final origin = tester.getRect(find.byKey(boundaryKey)).topLeft;
    final cardRect = tester.getRect(card).shift(-origin);
    final footerRect = tester.getRect(footer).shift(-origin);

    // Preconditions: the footer is flush with the card's bottom-left edge and the
    // sampled rows are on the straight segment of the border (outside the corner).
    expect(footerRect.left, closeTo(cardRect.left, 0.01));
    expect(footerRect.bottom, closeTo(cardRect.bottom, 0.01));
    final borderX = cardRect.left.floor();
    final rowAboveFooter = (footerRect.top - 24).floor();
    final rowInsideFooter = footerRect.center.dy.floor();
    expect(rowAboveFooter, greaterThan(cardRect.top + CoeloRadius.lg));
    expect(rowInsideFooter, lessThan(cardRect.bottom - CoeloRadius.lg));

    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
    final snapshot = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData();
      final result = _Snapshot(data!, image.width);
      image.dispose();
      return result;
    });
    final pixels = snapshot!;

    final colors = CoeloTheme.light.colorScheme;
    final borderAbove = pixels.at(borderX, rowAboveFooter);
    final borderInside = pixels.at(borderX, rowInsideFooter);
    final cornerOutsideRadius = pixels.at(cardRect.left.floor() + 1, cardRect.bottom.floor() - 1);

    // Sanity: the row above the footer really shows the card border.
    expect(
      _sameColor(borderAbove, colors.outlineVariant),
      isTrue,
      reason:
          'Expected outlineVariant ${_hex(colors.outlineVariant)} at '
          '($borderX, $rowAboveFooter) but read ${_hex(borderAbove)}.',
    );

    expect(
      _sameColor(borderInside, borderAbove),
      isTrue,
      reason:
          'Card border must be continuous. Above footer at ($borderX, $rowAboveFooter): '
          '${_hex(borderAbove)}; inside footer band at ($borderX, $rowInsideFooter): '
          '${_hex(borderInside)}. Footer rect: $footerRect; card rect: $cardRect. '
          'Bottom-left corner pixel outside the radius '
          '(${cardRect.left.floor() + 1}, ${cardRect.bottom.floor() - 1}): '
          '${_hex(cornerOutsideRadius)} (page background is '
          '${_hex(CoeloTheme.light.scaffoldBackgroundColor)}).',
    );
  });
}

Future<LogoutResult> _logout() async => const LogoutResult.success();

final class _Snapshot {
  const _Snapshot(this.data, this.width);

  final ByteData data;
  final int width;

  Color at(int x, int y) {
    final offset = (y * width + x) * 4;
    return Color.fromARGB(
      data.getUint8(offset + 3),
      data.getUint8(offset),
      data.getUint8(offset + 1),
      data.getUint8(offset + 2),
    );
  }
}

bool _sameColor(Color a, Color b, {int tolerance = 2}) {
  int channel(double value) => (value * 255).round();
  return (channel(a.r) - channel(b.r)).abs() <= tolerance &&
      (channel(a.g) - channel(b.g)).abs() <= tolerance &&
      (channel(a.b) - channel(b.b)).abs() <= tolerance;
}

String _hex(Color color) => '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

final class _FakeChatRepository implements ChatRepository {
  @override
  Future<ChatAttachment> uploadAttachment(ChatAttachmentUploadCommand command) =>
      Future<ChatAttachment>.error(const ChatAttachmentUnavailableException());

  @override
  Future<int> fetchUnreadTotal() async => 0;

  @override
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query) async => ChatInboxPage(
    totalUnread: 1,
    items: [
      ChatConversationSummary(
        id: 'conversation-1',
        title: 'Turma Girassol',
        preview: 'Mensagem autorizada',
        contextLabel: 'Unidade Cambui',
        kind: 'group',
        unreadCount: 1,
        updatedAt: DateTime.utc(2026, 8, 12, 12),
        isReadOnly: false,
      ),
    ],
  );

  @override
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query) async => ChatThreadPage(
    items: [
      ChatMessage(
        id: 'message-1',
        conversationId: 'conversation-1',
        body: 'Mensagem autorizada',
        authorName: 'Marina',
        sentAt: DateTime.utc(2026, 8, 12, 12),
        isMine: false,
        kind: 'text',
      ),
    ],
  );

  @override
  Future<void> markRead({required String conversationId, required String upToMessageId}) async {}

  @override
  Future<ChatRealtimeRefresh> refreshAfterRealtime({required String conversationId}) =>
      throw UnimplementedError();

  @override
  Future<ChatMessage> sendMessage(ChatSendMessageCommand command) => throw UnimplementedError();
}
