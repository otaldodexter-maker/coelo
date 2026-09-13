import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_attachment_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final canonicalImage = ChatAttachment(
    id: 'metadata-1',
    assetId: '11111111-1111-4111-8111-111111111111',
    fileName: 'imagem.png',
    mediaType: 'image/png',
    byteSize: 100,
    downloadUrl: Uri.parse('https://legacy.invalid/never-follow'),
  );

  testWidgets('ready image shows loading while its private ticket is pending', (tester) async {
    final repository = _BindingReader();
    await tester.pumpWidget(_inlineTile(repository: repository, session: MediaSession()));

    expect(find.text('Carregando imagem…'), findsOneWidget);
    await tester.pump();
    expect(repository.requests, ['inline-image-1']);
  });

  testWidgets('denied inline read exposes a retry that reauthorises once', (tester) async {
    final repository = _DeniedThenReadyReader();
    await tester.pumpWidget(_inlineTile(repository: repository, session: MediaSession()));
    await tester.pump();

    expect(find.text('Não foi possível carregar a imagem. Tente novamente.'), findsOneWidget);
    expect(repository.requests, hasLength(1));
    await tester.tap(find.text('Carregar novamente'));
    await tester.pump();
    expect(repository.requests, hasLength(2));
    expect(find.byKey(const Key('superadmin-chat-inline-image-inline-image-1')), findsOneWidget);
  });

  testWidgets('expired inline ticket waits for explicit reauthorisation', (tester) async {
    final repository = _ExpiredThenReadyReader();
    await tester.pumpWidget(_inlineTile(repository: repository, session: MediaSession()));
    await tester.pump();

    expect(find.text('A visualização expirou. Carregue novamente.'), findsOneWidget);
    expect(repository.requests, hasLength(1));
    await tester.pump();
    expect(repository.requests, hasLength(1));
    await tester.tap(find.text('Carregar novamente'));
    await tester.pump();
    expect(repository.requests, hasLength(2));
    expect(find.byKey(const Key('superadmin-chat-inline-image-inline-image-1')), findsOneWidget);
  });
  testWidgets('binding read discards its pending inline ticket after purge', (
    tester,
  ) async {
    final repository = _BindingReader();
    final session = MediaSession();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: SuperadminChatAttachmentTile(
            attachment: const ChatAttachment(
              id: 'binding-1',
              fileName: 'imagem.png',
              mediaType: 'image/png',
              byteSize: 100,
            ),
            state: SuperadminChatAttachmentState.ready,
            attachmentRepository: repository,
            mediaSession: session,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(repository.requests, ['binding-1']);
    await session.invalidate();
    repository.pending.complete(
      ChatAttachmentRead(
        url: Uri.parse('https://private.invalid/read'),
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-image-preview')), findsNothing);
    expect(find.text('Visualização indisponível neste contexto.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final control in ['footer', 'header']) {
    for (final change in ['covered', 'disposed']) {
      testWidgets('image $control close cannot affect another route after $change', (tester) async {
        final navigator = GlobalKey<NavigatorState>();
        final session = MediaSession();
        Widget host(bool disposed) => MaterialApp(
          navigatorKey: navigator,
          home: Scaffold(
            body: disposed
                ? const Text('Origem')
                : SuperadminChatAttachmentTile(
                    attachment: canonicalImage,
                    state: SuperadminChatAttachmentState.ready,
                    mediaReader: _Reader(),
                    mediaSession: session,
                  ),
          ),
        );
        await tester.pumpWidget(host(false));
        await tester.tap(find.text('Abrir imagem'));
        await tester.pumpAndSettle();
        final close = control == 'footer'
            ? tester
                  .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Fechar'))
                  .onPressed!
            : tester
                  .widget<IconButton>(
                    find.byWidgetPredicate(
                      (widget) => widget is IconButton && widget.tooltip == 'Fechar',
                    ),
                  )
                  .onPressed!;
        navigator.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Outra rota'))),
        );
        await tester.pumpAndSettle();
        if (change == 'disposed') {
          await tester.pumpWidget(host(true));
          await tester.pumpAndSettle();
        }
        close();
        await tester.pumpAndSettle();
        expect(find.text('Outra rota'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('image route honors reduced motion and keyboard open close focus', (tester) async {
    final reader = _Reader();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: SuperadminChatAttachmentTile(
              attachment: canonicalImage,
              state: SuperadminChatAttachmentState.ready,
              mediaReader: reader,
              mediaSession: MediaSession(),
            ),
          ),
        ),
      ),
    );
    final button = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Abrir imagem'));
    button.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    final route = ModalRoute.of(tester.element(find.byType(Dialog)))!;
    expect(route.transitionDuration, Duration.zero);
    expect(route.reverseTransitionDuration, Duration.zero);
    expect(reader.requests, hasLength(1));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(button.focusNode!.hasFocus, isTrue);
  });

  testWidgets('image dialog captures local theme barrier and closed focus traversal', (
    tester,
  ) async {
    const barrier = Color(0x99000000);
    final localTheme = CoeloTheme.dark.copyWith(
      dialogTheme: CoeloTheme.dark.dialogTheme.copyWith(barrierColor: barrier),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Theme(
          data: localTheme,
          child: Scaffold(
            body: SuperadminChatAttachmentTile(
              attachment: canonicalImage,
              state: SuperadminChatAttachmentState.ready,
              mediaReader: _Reader(),
              mediaSession: MediaSession(),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir imagem'));
    await tester.pumpAndSettle();
    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    expect(dialog.backgroundColor, localTheme.colorScheme.surface);
    final route = ModalRoute.of(tester.element(find.byType(Dialog)))!;
    expect(route.barrierColor, barrier);
    expect(route.traversalEdgeBehavior, TraversalEdgeBehavior.closedLoop);
  });
  testWidgets('canonical image reads only after explicit open and restores focus', (tester) async {
    final reader = _Reader();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: SuperadminChatAttachmentTile(
            attachment: canonicalImage,
            state: SuperadminChatAttachmentState.ready,
            mediaReader: reader,
            mediaSession: MediaSession(),
          ),
        ),
      ),
    );
    expect(reader.requests, isEmpty);
    final open = find.text('Abrir imagem');
    expect(open, findsOneWidget);
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(reader.requests, hasLength(1));
    expect(reader.requests.single.assetId, canonicalImage.assetId);
    expect(find.byKey(const Key('chat-image-processing')), findsOneWidget);
    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-image-processing')), findsNothing);
    final button = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Abrir imagem'));
    expect(button.focusNode!.hasFocus, isTrue);
  });

  testWidgets('missing transport exposes disabled image action without fallback', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuperadminChatAttachmentTile(
            attachment: canonicalImage,
            state: SuperadminChatAttachmentState.ready,
          ),
        ),
      ),
    );
    final button = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Abrir imagem'));
    expect(button.onPressed, isNull);
    expect(find.text('Visualização indisponível neste contexto.'), findsOneWidget);
  });

  const attachment = ChatAttachment(
    id: 'attachment-1',
    fileName: 'relatorio-pedagogico-completo.pdf',
    mediaType: 'application/pdf',
    byteSize: 1536000,
  );

  testWidgets('context replacement dismisses only the owned image route', (tester) async {
    final reader = _Reader();
    final session = MediaSession();
    final navigator = GlobalKey<NavigatorState>();
    Widget host(MediaSession current) => MaterialApp(
      navigatorKey: navigator,
      theme: CoeloTheme.light,
      home: Scaffold(
        body: SuperadminChatAttachmentTile(
          attachment: canonicalImage,
          state: SuperadminChatAttachmentState.ready,
          mediaReader: reader,
          mediaSession: current,
        ),
      ),
    );
    await tester.pumpWidget(host(session));
    await tester.tap(find.text('Abrir imagem'));
    await tester.pumpAndSettle();
    navigator.currentState!.push(
      DialogRoute<void>(
        context: navigator.currentContext!,
        builder: (_) => const Dialog(child: Text('Outra rota')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(host(MediaSession()));
    await tester.pumpAndSettle();
    expect(find.text('Outra rota'), findsOneWidget);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-image-processing')), findsNothing);
    expect(find.text('Abrir imagem'), findsOneWidget);
    expect(reader.requests, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy image never treats metadata id or URL as canonical asset', (tester) async {
    final reader = _Reader();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuperadminChatAttachmentTile(
            attachment: ChatAttachment(
              id: canonicalImage.assetId!,
              fileName: 'legado.png',
              mediaType: 'image/png',
              byteSize: 100,
              downloadUrl: canonicalImage.downloadUrl,
            ),
            state: SuperadminChatAttachmentState.ready,
            mediaReader: reader,
            mediaSession: MediaSession(),
          ),
        ),
      ),
    );
    final button = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Abrir imagem'));
    expect(button.onPressed, isNull);
    expect(reader.requests, isEmpty);
  });

  testWidgets('context change before dialog first build never starts old read', (tester) async {
    final reader = _Reader();
    Widget host(MediaSession session) => MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: SuperadminChatAttachmentTile(
          attachment: canonicalImage,
          state: SuperadminChatAttachmentState.ready,
          mediaReader: reader,
          mediaSession: session,
        ),
      ),
    );
    await tester.pumpWidget(host(MediaSession()));
    await tester.tap(find.text('Abrir imagem'));
    await tester.pumpWidget(host(MediaSession()));
    await tester.pumpAndSettle();
    expect(reader.requests, isEmpty);
    expect(find.byKey(const Key('chat-image-processing')), findsNothing);
  });

  testWidgets('session invalidation disables opening with no widget replacement', (tester) async {
    final reader = _Reader();
    final session = MediaSession();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuperadminChatAttachmentTile(
            attachment: canonicalImage,
            state: SuperadminChatAttachmentState.ready,
            mediaReader: reader,
            mediaSession: session,
          ),
        ),
      ),
    );
    await session.invalidate();
    await tester.pump();
    final button = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Abrir imagem'));
    expect(button.onPressed, isNull);
    expect(reader.requests, isEmpty);
  });

  testWidgets('disposing tile before dialog first build never starts a read', (tester) async {
    final reader = _Reader();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: SuperadminChatAttachmentTile(
            attachment: canonicalImage,
            state: SuperadminChatAttachmentState.ready,
            mediaReader: reader,
            mediaSession: MediaSession(),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir imagem'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(reader.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

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

    expect(find.text('Anexo disponível'), findsOneWidget);
    expect(find.byTooltip('Tentar novamente'), findsNothing);
  });
}

final class _Reader implements MediaReader {
  final requests = <MediaReadRequest>[];
  @override
  Future<MediaReadResult> read(MediaReadRequest request) async {
    requests.add(request);
    return MediaReadResult.fromJson({'asset_id': request.assetId, 'state': 'processing'});
  }
}

final class _BindingReader implements ChatAttachmentRepository {
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

Widget _inlineTile({required ChatAttachmentRepository repository, required MediaSession session}) => MaterialApp(
  theme: CoeloTheme.light,
  home: Scaffold(
    body: SuperadminChatAttachmentTile(
      attachment: const ChatAttachment(
        id: 'inline-image-1',
        fileName: 'R08-G4-synthetic.png',
        mediaType: 'image/png',
        byteSize: 82,
      ),
      state: SuperadminChatAttachmentState.ready,
      attachmentRepository: repository,
      mediaSession: session,
    ),
  ),
);

final class _DeniedThenReadyReader implements ChatAttachmentRepository {
  final requests = <String>[];

  @override
  Future<ChatAttachmentRead> readAttachment(String attachmentId) async {
    requests.add(attachmentId);
    if (requests.length == 1) throw const ChatUnauthorizedException();
    return _ticket();
  }

  @override
  Future<String> uploadAttachment(ChatAttachmentUpload command) => throw UnimplementedError();
}

final class _ExpiredThenReadyReader implements ChatAttachmentRepository {
  final requests = <String>[];

  @override
  Future<ChatAttachmentRead> readAttachment(String attachmentId) async {
    requests.add(attachmentId);
    if (requests.length == 1) {
      return ChatAttachmentRead(
        url: Uri.parse('https://private.invalid/expired'),
        expiresAt: DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
      );
    }
    return _ticket();
  }

  @override
  Future<String> uploadAttachment(ChatAttachmentUpload command) => throw UnimplementedError();
}

ChatAttachmentRead _ticket() => ChatAttachmentRead(
  url: Uri.parse('https://private.invalid/read'),
  expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
);
