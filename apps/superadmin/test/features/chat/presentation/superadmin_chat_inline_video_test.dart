import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_inline_video.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('denied video read keeps playback unavailable and retries only on request', (
    tester,
  ) async {
    final repository = _DeniedReader();
    await tester.pumpWidget(_video(repository, MediaSession()));
    expect(find.text('Carregando vídeo…'), findsOneWidget);
    await tester.pump();
    expect(find.text('Não foi possível carregar o vídeo. Tente novamente.'), findsOneWidget);
    expect(repository.requests, hasLength(1));

    await tester.tap(find.text('Carregar novamente'));
    await tester.pump();
    expect(repository.requests, hasLength(2));
    expect(find.byTooltip('Reproduzir vídeo'), findsNothing);
  });

  testWidgets('expired video ticket waits for explicit reauthorisation', (tester) async {
    final repository = _ExpiredReader();
    await tester.pumpWidget(_video(repository, MediaSession()));
    await tester.pump();
    expect(find.text('A visualização expirou. Carregue novamente.'), findsOneWidget);
    await tester.pump();
    expect(repository.requests, hasLength(1));
  });

  testWidgets('purge clears a pending video ticket without offering playback', (tester) async {
    final repository = _PendingReader();
    final session = MediaSession();
    await tester.pumpWidget(_video(repository, session));
    await tester.pump();
    expect(repository.requests, ['video-1']);
    await session.invalidate();
    repository.pending.complete(_ticket());
    await tester.pumpAndSettle();

    expect(find.text('Visualização indisponível neste contexto.'), findsOneWidget);
    expect(find.byTooltip('Reproduzir vídeo'), findsNothing);
    expect(find.text('Carregar novamente'), findsNothing);
  });
}

Widget _video(ChatAttachmentRepository repository, MediaSession session) => MaterialApp(
  theme: CoeloTheme.light,
  home: Scaffold(
    body: SuperadminChatInlineVideo(
      attachment: const ChatAttachment(
        id: 'video-1',
        fileName: 'R10-private.mp4',
        mediaType: 'video/mp4',
        byteSize: 82,
      ),
      attachmentRepository: repository,
      session: session,
    ),
  ),
);

final class _DeniedReader implements ChatAttachmentRepository {
  final requests = <String>[];

  @override
  Future<ChatAttachmentRead> readAttachment(String attachmentId) async {
    requests.add(attachmentId);
    throw const ChatUnauthorizedException();
  }

  @override
  Future<String> uploadAttachment(ChatAttachmentUpload command) => throw UnimplementedError();
}

final class _ExpiredReader implements ChatAttachmentRepository {
  final requests = <String>[];

  @override
  Future<ChatAttachmentRead> readAttachment(String attachmentId) async {
    requests.add(attachmentId);
    return ChatAttachmentRead(
      url: Uri.parse('https://private.invalid/expired.mp4'),
      expiresAt: DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
    );
  }

  @override
  Future<String> uploadAttachment(ChatAttachmentUpload command) => throw UnimplementedError();
}

final class _PendingReader implements ChatAttachmentRepository {
  final requests = <String>[];
  final pending = Completer<ChatAttachmentRead>();

  @override
  Future<ChatAttachmentRead> readAttachment(String attachmentId) {
    requests.add(attachmentId);
    return pending.future;
  }

  @override
  Future<String> uploadAttachment(ChatAttachmentUpload command) => throw UnimplementedError();
}

ChatAttachmentRead _ticket() => ChatAttachmentRead(
  url: Uri.parse('https://private.invalid/video.mp4'),
  expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
);
