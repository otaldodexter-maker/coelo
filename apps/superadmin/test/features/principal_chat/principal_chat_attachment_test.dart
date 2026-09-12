import 'dart:async';

import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:coelo_superadmin/features/principal_chat/presentation/principal_chat_attachment_tile.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _attachment = ChatAttachment(
  id: 'binding-principal',
  fileName: 'imagem.png',
  mediaType: 'image/png',
  byteSize: 100,
);

void main() {
  for (final width in [375.0, 1440.0]) {
    testWidgets('private read is explicit and expired ticket retries at width $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.reset);
      final repository = _ExpiredReader();
      await tester.pumpWidget(_app(repository, textScale: 2));
      expect(repository.ids, isEmpty);
      await tester.tap(find.text('Abrir imagem'));
      await tester.pumpAndSettle();
      expect(repository.ids, ['binding-principal']);
      expect(find.byKey(const Key('chat-image-preview')), findsNothing);
      expect(find.byKey(const Key('chat-image-expired')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(repository.ids, ['binding-principal', 'binding-principal']);
      expect(find.byKey(const Key('chat-image-preview')), findsNothing);
      await tester.tap(find.widgetWithText(TextButton, 'Fechar'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });
  }

  testWidgets('repository replacement closes owned preview and discards late private URL', (
    tester,
  ) async {
    final pending = _PendingReader();
    await tester.pumpWidget(_app(pending));
    await tester.tap(find.text('Abrir imagem'));
    await tester.pumpAndSettle();
    expect(pending.ids, ['binding-principal']);
    await tester.pumpWidget(_app(_ExpiredReader()));
    await tester.pumpAndSettle();
    pending.result.complete(
      ChatAttachmentRead(
        url: Uri.parse('https://private.invalid/never-load'),
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.byKey(const Key('chat-image-preview')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(ChatAttachmentRepository repository, {double textScale = 1}) => MaterialApp(
  theme: CoeloTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(
    body: PrincipalChatAttachmentTile(attachment: _attachment, repository: repository),
  ),
);

final class _ExpiredReader implements ChatAttachmentRepository {
  final ids = <String>[];
  @override
  Future<ChatAttachmentRead> readAttachment(String attachmentId) async {
    ids.add(attachmentId);
    return ChatAttachmentRead(
      url: Uri.parse('https://private.invalid/expired'),
      expiresAt: DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
    );
  }

  @override
  Future<String> uploadAttachment(ChatAttachmentUpload command) => throw UnimplementedError();
}

final class _PendingReader implements ChatAttachmentRepository {
  final ids = <String>[];
  final result = Completer<ChatAttachmentRead>();
  @override
  Future<ChatAttachmentRead> readAttachment(String attachmentId) {
    ids.add(attachmentId);
    return result.future;
  }

  @override
  Future<String> uploadAttachment(ChatAttachmentUpload command) => throw UnimplementedError();
}
