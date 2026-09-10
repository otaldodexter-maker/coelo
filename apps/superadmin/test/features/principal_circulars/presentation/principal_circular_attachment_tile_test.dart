import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:coelo_superadmin/features/principal_circulars/presentation/principal_circular_reader.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('without a media capability the attachment stays closed', (tester) async {
    await _pumpReader(tester, repository: null);

    expect(find.text('Anexo 1'), findsOneWidget);
    expect(find.text('Abertura indisponível nesta tela'), findsOneWidget);
    expect(tester.widget<TextButton>(find.byType(TextButton).first).onPressed, isNull);
  });

  testWidgets('a denied read shows no permission and leaks no path', (tester) async {
    final repository = _FakeMedia(failure: const CircularUnauthorized());
    await _pumpReader(tester, repository: repository);

    await tester.tap(find.byType(TextButton).first);
    await tester.pumpAndSettle();

    expect(repository.requested, ['asset-1']);
    expect(find.text('Você não tem permissão para abrir este anexo'), findsOneWidget);
    expect(find.textContaining('https://'), findsNothing);
    expect(find.textContaining('coelo-media'), findsNothing);
  });

  testWidgets('an expired ticket is announced and a new tap renegotiates', (tester) async {
    final repository = _FakeMedia(
      tickets: [
        _ticket(expiresIn: const Duration(seconds: -1)),
        _ticket(expiresIn: const Duration(seconds: 120), mimeType: 'application/pdf'),
      ],
    );
    await _pumpReader(tester, repository: repository);

    await tester.tap(find.byType(TextButton).first);
    await tester.pumpAndSettle();
    expect(find.text('Link expirado · toque para renovar'), findsOneWidget);

    await tester.tap(find.byType(TextButton).first);
    await tester.pumpAndSettle();

    expect(repository.requested, ['asset-1', 'asset-1']);
    expect(find.textContaining('sem visualizador no app'), findsOneWidget);
  });

  testWidgets('a PDF reports its identity instead of faking an opening', (tester) async {
    final repository = _FakeMedia(
      tickets: [
        _ticket(
          expiresIn: const Duration(seconds: 120),
          mimeType: 'application/pdf',
          name: 'circular-agosto.pdf',
          byteSize: 2 * 1024 * 1024,
        ),
      ],
    );
    await _pumpReader(tester, repository: repository);

    await tester.tap(find.byType(TextButton).first);
    await tester.pumpAndSettle();

    expect(find.text('circular-agosto.pdf'), findsOneWidget);
    expect(find.text('Documento PDF · 2.0 MB · sem visualizador no app'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('an unavailable read offers a retry without success wording', (tester) async {
    final repository = _FakeMedia(failure: const CircularUnavailable());
    await _pumpReader(tester, repository: repository);

    await tester.tap(find.byType(TextButton).first);
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível abrir agora · toque para tentar novamente'), findsOneWidget);
  });
}

Future<void> _pumpReader(
  WidgetTester tester, {
  required CircularMediaRepository? repository,
}) async {
  await tester.binding.setSurfaceSize(const Size(1024, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: PrincipalCircularReader(
          detail: _detail,
          onSubmit: (_) async {},
          mediaRepository: repository,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

CircularMediaReadTicket _ticket({
  required Duration expiresIn,
  String mimeType = 'image/png',
  String? name,
  int? byteSize,
}) => CircularMediaReadTicket(
  assetId: 'asset-1',
  url: Uri.parse('https://storage.example/opaque'),
  mimeType: mimeType,
  expiresAt: DateTime.now().toUtc().add(expiresIn),
  name: name,
  byteSize: byteSize,
);

final class _FakeMedia implements CircularMediaRepository {
  _FakeMedia({this.tickets = const [], this.failure});

  final List<CircularMediaReadTicket> tickets;
  final CircularFailure? failure;
  final requested = <String>[];

  @override
  Future<CircularMediaReadTicket> resolveRead(String assetId) async {
    requested.add(assetId);
    final failure = this.failure;
    if (failure != null) throw failure;
    return tickets[requested.length - 1];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _detail = CircularDetail(
  id: 'circular-1',
  revisionId: 'revision-1',
  title: 'Renovação de matrícula',
  authorName: 'Colégio Coelo',
  contextLabel: 'Ensino Fundamental',
  publishedAt: DateTime.utc(2026, 8, 21),
  status: CircularStatus.published,
  responseState: CircularResponseState.unanswered,
  blocks: const [
    CircularTextBlock(id: 'text-1', text: 'Confirme a renovação.'),
    CircularMediaBlock(id: 'media-1', assetIds: ['asset-1']),
  ],
);
