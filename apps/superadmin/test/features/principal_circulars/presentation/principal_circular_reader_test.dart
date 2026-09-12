import 'dart:async';

import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:coelo_superadmin/features/principal_circulars/presentation/principal_circular_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final failure in [false, true]) {
    testWidgets('new revision clears answers and ignores late ${failure ? 'error' : 'success'}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final pending = Completer<void>();
      final next = CircularDetail(
        id: _detail.id,
        revisionId: 'revision-2',
        title: 'Nova revisão',
        authorName: _detail.authorName,
        contextLabel: _detail.contextLabel,
        publishedAt: _detail.publishedAt,
        status: _detail.status,
        responseState: CircularResponseState.unanswered,
        blocks: _detail.blocks,
      );
      Map<String, List<String>>? submitted;
      Widget page(CircularDetail detail, Future<void> Function(Map<String, List<String>>) submit) =>
          MaterialApp(
            home: Scaffold(
              body: PrincipalCircularReader(detail: detail, onSubmit: submit),
            ),
          );
      await tester.pumpWidget(page(_detail, (_) => pending.future));
      await tester.tap(find.byKey(const Key('circular-option-question-1-yes')));
      await tester.tap(find.byKey(const Key('circular-option-question-2-uniform')));
      await tester.tap(find.byKey(const Key('circular-submit-responses')));
      await tester.pump();
      await tester.pumpWidget(
        page(next, (answers) async {
          submitted = answers;
        }),
      );
      await tester.pump();
      expect(find.byIcon(Icons.radio_button_checked_rounded), findsNothing);
      if (failure) {
        pending.completeError(StateError('old request'));
      } else {
        pending.complete();
      }
      await tester.pumpAndSettle();
      expect(find.text('Respostas enviadas'), findsNothing);
      expect(find.text('Não foi possível enviar. Tente novamente.'), findsNothing);
      await tester.tap(find.byKey(const Key('circular-option-question-1-no')));
      await tester.tap(find.byKey(const Key('circular-submit-responses')));
      await tester.pumpAndSettle();
      expect(submitted, {
        'question-1': ['no'],
      });
    });
  }

  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('renders and responds without overflow at ${width.toInt()}px', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = previous);
      Map<String, List<String>>? submitted;

      await tester.binding.setSurfaceSize(Size(width, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrincipalCircularReader(
              detail: _detail,
              onSubmit: (answers) async => submitted = answers,
            ),
          ),
        ),
      );

      expect(find.text('Renovação de matrícula'), findsOneWidget);
      await tester.tap(find.byKey(const Key('circular-option-question-1-yes')));
      await tester.tap(find.byKey(const Key('circular-option-question-2-uniform')));
      await tester.tap(find.byKey(const Key('circular-submit-responses')));
      await tester.pumpAndSettle();

      expect(submitted?['question-1'], ['yes']);
      expect(submitted?['question-2'], ['uniform']);
      expect(find.text('Respostas enviadas'), findsOneWidget);
      expect(errors.where((error) => error.exceptionAsString().contains('overflowed')), isEmpty);
    });
  }

  testWidgets('blocks submission while a required question is unanswered', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrincipalCircularReader(detail: _detail, onSubmit: (_) async {}),
        ),
      ),
    );

    await tester.ensureVisible(find.byKey(const Key('circular-submit-responses')));
    await tester.tap(find.byKey(const Key('circular-submit-responses')));
    await tester.pump();

    expect(find.text('Responda às perguntas obrigatórias.'), findsOneWidget);
  });

  testWidgets('reader preserves the published interleaved block order', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrincipalCircularReader(detail: _detail, onSubmit: (_) async {}),
        ),
      ),
    );

    double top(String id) => tester.getTopLeft(find.byKey(Key('circular-reader-$id'))).dy;
    expect(top('text-1'), lessThan(top('media-1')));
    expect(top('media-1'), lessThan(top('question-1')));
    expect(top('question-1'), lessThan(top('media-2')));
    expect(top('media-2'), lessThan(top('question-2')));
  });
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
    CircularTextBlock(
      id: 'text-1',
      text: 'Queridos responsáveis, confirme a renovação para o próximo ano.',
    ),
    CircularMediaBlock(id: 'media-1', assetIds: ['asset-1', 'asset-2']),
    CircularQuestionBlock(
      id: 'question-1',
      prompt: 'A matrícula será renovada?',
      kind: CircularQuestionKind.singleChoice,
      required: true,
      options: [
        CircularQuestionOption(id: 'yes', label: 'Sim'),
        CircularQuestionOption(id: 'no', label: 'Não'),
      ],
    ),
    CircularMediaBlock(id: 'media-2', assetIds: ['asset-3']),
    CircularQuestionBlock(
      id: 'question-2',
      prompt: 'Quais itens deseja reservar?',
      kind: CircularQuestionKind.multipleChoice,
      required: false,
      options: [
        CircularQuestionOption(id: 'uniform', label: 'Uniforme'),
        CircularQuestionOption(id: 'books', label: 'Livros'),
      ],
    ),
  ],
);
