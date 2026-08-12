import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_attachment_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const attachment = ChatAttachment(
    id: 'attachment-1',
    fileName: 'relatorio-pedagogico-completo.pdf',
    mediaType: 'application/pdf',
    byteSize: 1536000,
  );

  testWidgets('shows failed attachment metadata and retries only when requested', (tester) async {
    var retryCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuperadminChatAttachmentTile(
            attachment: attachment,
            state: SuperadminChatAttachmentState.failed,
            onRetry: () => retryCount += 1,
          ),
        ),
      ),
    );

    final filename = find.text(attachment.fileName);
    expect(filename, findsOneWidget);
    final filenameText = tester.widget<Text>(filename);
    expect(filenameText.maxLines, 1);
    expect(filenameText.overflow, TextOverflow.ellipsis);
    expect(find.text('application/pdf · 1,5 MB'), findsOneWidget);
    expect(find.byTooltip('Tentar novamente'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Falha no envio')), findsOneWidget);

    await tester.tap(find.byTooltip('Tentar novamente'));
    expect(retryCount, 1);
  });

  testWidgets('ready attachment does not expose a retry action', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SuperadminChatAttachmentTile(
            attachment: attachment,
            state: SuperadminChatAttachmentState.ready,
          ),
        ),
      ),
    );

    expect(find.text('Pronto para enviar'), findsOneWidget);
    expect(find.byTooltip('Tentar novamente'), findsNothing);
  });
}
