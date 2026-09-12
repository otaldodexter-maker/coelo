import 'dart:typed_data';

import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_upload_dialog.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final command = ChatAttachmentUpload(
    conversationId: 'conversation-1',
    requestId: 'request-1',
    fileName: 'imagem.png',
    contentType: 'image/png',
    bytes: Uint8List(8),
  );

  testWidgets('explicit send retries the same request and preserves the file on failure', (
    tester,
  ) async {
    final repository = _Media();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: SuperadminChatUploadDialog(
          repository: repository,
          command: command,
          isContextCurrent: () => true,
        ),
      ),
    );
    expect(repository.commands, isEmpty);
    await tester.tap(find.text('Enviar arquivo'));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível enviar o arquivo. Tente novamente.'), findsOneWidget);
    expect(find.text('imagem.png'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(repository.commands, [same(command), same(command)]);
  });

  testWidgets('context replaced before send cannot upload into the former conversation', (
    tester,
  ) async {
    final repository = _Media();
    var current = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: SuperadminChatUploadDialog(
          repository: repository,
          command: command,
          isContextCurrent: () => current,
        ),
      ),
    );
    current = false;
    await tester.tap(find.text('Enviar arquivo'));
    await tester.pumpAndSettle();
    expect(repository.commands, isEmpty);
  });

  testWidgets('compact enlarged text keeps file actions usable without overflow', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: SuperadminChatUploadDialog(
          repository: _Media(),
          command: command,
          isContextCurrent: () => true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Enviar arquivo'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
  });
}

class _Media implements ChatAttachmentRepository {
  final commands = <ChatAttachmentUpload>[];
  @override
  Future<String> uploadAttachment(ChatAttachmentUpload command) async {
    commands.add(command);
    throw const ChatFailureException();
  }

  @override
  Future<ChatAttachmentRead> readAttachment(String attachmentId) => throw UnimplementedError();
}
