import 'dart:typed_data';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:coelo_superadmin/features/chat/presentation/screens/superadmin_chat_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression guard for the outline the inbox pagination footer used to erase.
///
/// The footer sits flush with the card edge and blurs its own backdrop, so a
/// border painted behind the content disappeared wherever the two overlapped.
/// Sampling the same border column above and inside the footer band is the only
/// thing that actually proves the line survives; a structural assertion about
/// which decoration holds the border would pass even with the blur on top.
void main() {
  for (final variant in <({String name, ThemeData theme})>[
    (name: 'light', theme: CoeloTheme.light),
    (name: 'dark', theme: CoeloTheme.dark),
  ]) {
    testWidgets('the chat card outline and corner survive the footer in ${variant.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      const boundaryKey = Key('chat-outline-boundary');
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            theme: variant.theme,
            home: SuperadminChatPage(logout: _logout, chatRepository: _ChatRepository()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final footer = find.byType(SuperadminListingPaginationFooter);
      expect(footer, findsOneWidget);
      final card = find
          .ancestor(
            of: footer,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is DecoratedBox &&
                  widget.decoration is BoxDecoration &&
                  (widget.decoration as BoxDecoration).border != null,
            ),
          )
          .first;

      final origin = tester.getRect(find.byKey(boundaryKey)).topLeft;
      final cardRect = tester.getRect(card).shift(-origin);
      final footerRect = tester.getRect(footer).shift(-origin);
      expect(footerRect.left, closeTo(cardRect.left, 0.01));

      // Both samples are on the straight run of the left edge, clear of the radius.
      final borderX = cardRect.left.floor();
      final aboveFooter = (footerRect.top - 24).floor();
      final insideFooter = footerRect.center.dy.floor();
      expect(aboveFooter, greaterThan(cardRect.top + CoeloRadius.lg));
      expect(insideFooter, lessThan(cardRect.bottom - CoeloRadius.lg));

      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
      final pixels = await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData();
        final snapshot = _Snapshot(data!, image.width);
        image.dispose();
        return snapshot;
      });

      final outline = variant.theme.colorScheme.outlineVariant;
      final above = pixels!.at(borderX, aboveFooter);
      final inside = pixels.at(borderX, insideFooter);

      expect(
        _sameColor(above, outline),
        isTrue,
        reason: 'the sample above the footer must be the outline: read ${_hex(above)}',
      );
      expect(
        _sameColor(inside, outline),
        isTrue,
        reason:
            'the outline must survive the footer band: above ${_hex(above)}, '
            'inside ${_hex(inside)}',
      );

      // The bottom-left corner: one pixel inside the card bounds but outside the
      // rounded arc. A child painting past the radius squares off the card, so
      // this pixel has to stay the page behind it, not the card surface.
      // The corner is asserted through the arc, not through what lies outside it:
      // measured, the shell paints the same surface as the card, so a child
      // spilling past the radius produces no colour difference here. The clip is
      // still applied — it is correctness that costs nothing — but the only thing
      // a pixel can prove in this composition is that the arc itself is drawn.
      var arcPixels = 0;
      final radius = CoeloRadius.lg.round();
      for (var dx = 0; dx <= radius; dx++) {
        for (var dy = 1; dy <= radius; dy++) {
          final pixel = pixels.at(cardRect.left.floor() + dx, cardRect.bottom.floor() - dy);
          if (_closerTo(pixel, outline, than: variant.theme.colorScheme.surface)) arcPixels++;
        }
      }
      expect(
        arcPixels,
        greaterThan(radius ~/ 2),
        reason:
            'the rounded corner must still show its outline arc; found only '
            '$arcPixels outline-ish pixels in the ${radius}x$radius corner box',
      );
    });
  }
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

/// Whether [pixel] reads as [target] rather than as [than]. Antialiasing blends
/// the arc into the surface, so an exact match would be brittle.
bool _closerTo(Color pixel, Color target, {required Color than}) {
  double distance(Color a, Color b) {
    double channel(double x, double y) => (x - y) * (x - y);
    return channel(a.r, b.r) + channel(a.g, b.g) + channel(a.b, b.b);
  }

  return distance(pixel, target) < distance(pixel, than);
}

bool _sameColor(Color a, Color b, {int tolerance = 2}) {
  int channel(double value) => (value * 255).round();
  return (channel(a.r) - channel(b.r)).abs() <= tolerance &&
      (channel(a.g) - channel(b.g)).abs() <= tolerance &&
      (channel(a.b) - channel(b.b)).abs() <= tolerance;
}

String _hex(Color color) => '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

final class _ChatRepository implements ChatRepository {
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

  @override
  Future<ChatAttachment> uploadAttachment(ChatAttachmentUploadCommand command) =>
      Future<ChatAttachment>.error(const ChatAttachmentUnavailableException());
}
