import 'dart:typed_data';

import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_batch_upload_dialog.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Spec 058: o diálogo envia o lote como uma mensagem, mostra o progresso por
// item e, em falha parcial, deixa remover os que falharam (publica) ou cancelar.
void main() {
  ChatAttachmentUpload item(String name) => ChatAttachmentUpload(
    conversationId: 'conversation-1',
    requestId: 'request-$name',
    fileName: name,
    contentType: 'image/png',
    bytes: Uint8List(8),
  );
  final command = ChatAttachmentBatchUpload(
    conversationId: 'conversation-1',
    requestId: 'batch-1',
    items: [item('a.png'), item('b.png'), item('c.png')],
  );

  Future<String?> pump(WidgetTester tester, _Batch repository) async {
    String? popped;
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  opened = true;
                  popped = await showDialog<String>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => SuperadminChatBatchUploadDialog(
                      repository: repository,
                      command: command,
                      isContextCurrent: () => true,
                    ),
                  );
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(opened, isTrue);
    return popped;
  }

  testWidgets('sends the whole batch as one message and closes with its id', (tester) async {
    final repository = _Batch();
    await pump(tester, repository);
    expect(
      find.text('Os 3 arquivos serão enviados juntos, como uma única mensagem.'),
      findsOneWidget,
    );
    expect(find.text('a.png · 1 KB'), findsOneWidget);
    await tester.tap(find.text('Enviar 3 arquivos'));
    await tester.pumpAndSettle();
    expect(repository.batches, hasLength(1));
    expect(repository.batches.single, same(command));
    expect(repository.discarded, isEmpty);
    expect(find.byType(SuperadminChatBatchUploadDialog), findsNothing);
  });

  testWidgets('partial failure offers to discard failed items and publish', (tester) async {
    final repository = _Batch(failing: {1});
    await pump(tester, repository);
    await tester.tap(find.text('Enviar 3 arquivos'));
    await tester.pumpAndSettle();
    expect(find.text('1 de 3 arquivos não foram enviados.'), findsOneWidget);
    expect(find.text('Falhou'), findsOneWidget);
    expect(find.text('Pronto'), findsNWidgets(2));
    expect(find.byType(SuperadminChatBatchUploadDialog), findsOneWidget);
    await tester.tap(find.byKey(const Key('superadmin-chat-batch-discard-failed')));
    await tester.pumpAndSettle();
    expect(repository.discarded, ['attachment-1']);
    expect(find.byType(SuperadminChatBatchUploadDialog), findsNothing);
  });

  testWidgets('cancelling a partial send discards every uploaded item and closes without message', (
    tester,
  ) async {
    final repository = _Batch(failing: {0});
    await pump(tester, repository);
    await tester.tap(find.text('Enviar 3 arquivos'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-chat-batch-cancel')));
    await tester.pumpAndSettle();
    expect(repository.discarded, ['attachment-0', 'attachment-1', 'attachment-2']);
    expect(find.byType(SuperadminChatBatchUploadDialog), findsNothing);
  });

  testWidgets('when nothing was uploaded only cancel remains', (tester) async {
    final repository = _Batch(failing: {0, 1, 2});
    await pump(tester, repository);
    await tester.tap(find.text('Enviar 3 arquivos'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('superadmin-chat-batch-discard-failed')), findsNothing);
    expect(find.text('Cancelar envio'), findsOneWidget);
  });

  testWidgets('a refused batch keeps the files and allows retry', (tester) async {
    final repository = _Batch(refuse: const ChatAttachmentLimitException());
    await pump(tester, repository);
    await tester.tap(find.text('Enviar 3 arquivos'));
    await tester.pumpAndSettle();
    expect(
      find.text('Limite de 10 anexos por mensagem. Selecione até 10 arquivos.'),
      findsOneWidget,
    );
    expect(find.text('c.png · 1 KB'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(repository.batches, hasLength(2));
  });
}

class _Batch implements ChatAttachmentBatchRepository {
  _Batch({this.failing = const {}, this.refuse});
  final Set<int> failing;
  final Object? refuse;
  final batches = <ChatAttachmentBatchUpload>[];
  final discarded = <String>[];

  @override
  Future<ChatAttachmentBatchResult> uploadAttachmentBatch(
    ChatAttachmentBatchUpload command, {
    ChatAttachmentBatchProgress? onProgress,
  }) async {
    batches.add(command);
    if (refuse != null) throw refuse!;
    final items = [
      for (var index = 0; index < command.items.length; index++)
        ChatAttachmentBatchItem(
          index: index,
          fileName: command.items[index].fileName,
          attachmentId: 'attachment-$index',
          state: failing.contains(index)
              ? ChatAttachmentBatchItemState.failed
              : ChatAttachmentBatchItemState.ready,
        ),
    ];
    final result = ChatAttachmentBatchResult(
      messageId: 'message-batch',
      messageStatus: failing.isEmpty ? 'active' : 'draft',
      items: items,
    );
    onProgress?.call(result);
    return result;
  }

  @override
  Future<ChatAttachmentDiscardResult> discardAttachment(String attachmentId) async {
    discarded.add(attachmentId);
    final remaining = {
      0,
      1,
      2,
    }.difference(discarded.map((id) => int.parse(id.split('-').last)).toSet());
    final readyLeft = remaining.difference(failing);
    final failedLeft = remaining.intersection(failing);
    return ChatAttachmentDiscardResult(
      messageId: 'message-batch',
      messageStatus: readyLeft.isEmpty
          ? 'archived'
          : failedLeft.isEmpty
          ? 'active'
          : 'draft',
    );
  }

  @override
  Future<String> uploadAttachment(ChatAttachmentUpload command) => throw UnimplementedError();

  @override
  Future<ChatAttachmentRead> readAttachment(String attachmentId) => throw UnimplementedError();
}
