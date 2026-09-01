import 'package:coelo_superadmin/features/circulars/presentation/superadmin_circular_composer_page.dart';
import 'package:coelo_superadmin/features/circulars/presentation/superadmin_circular_detail_page.dart';
import 'package:coelo_superadmin/features/principal_circulars/application/circular_composer_controller.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('admin composer follows the approved responsive form at ${width.toInt()}px', (
      tester,
    ) async {
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = previous);
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = CircularComposerController(
        repository: _Repository(),
        scope: const CircularScope(institutionId: 'institution-1'),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuperadminCircularComposerPage(
              controller: controller,
              onCancel: () {},
              onPickFiles: () async {},
            ),
          ),
        ),
      );

      expect(find.text('Publicar circular'), findsOneWidget);
      expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
      expect(
        find.byKey(const Key('superadmin-circular-preview')),
        width >= 1200 ? findsOneWidget : findsNothing,
      );
      expect(errors.where((error) => error.exceptionAsString().contains('overflowed')), isEmpty);
    });
  }

  testWidgets('admin composer saves and publishes through the existing domain controller', (
    tester,
  ) async {
    final repository = _Repository();
    final controller = CircularComposerController(
      repository: repository,
      scope: const CircularScope(institutionId: 'institution-1'),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuperadminCircularComposerPage(
            controller: controller,
            onCancel: () {},
            onPickFiles: () async {},
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('circular-title')), 'Renovação 2027');
    await tester.enterText(find.byKey(const Key('circular-body')), 'Queridos responsáveis');
    await tester.tap(find.byKey(const Key('circular-audience-families')));
    await tester.ensureVisible(find.byKey(const Key('circular-save-draft')));
    await tester.tap(find.byKey(const Key('circular-save-draft')));
    await tester.pumpAndSettle();
    expect(repository.saved, isTrue);

    await tester.tap(find.byKey(const Key('circular-publish')));
    await tester.pumpAndSettle();
    expect(repository.published, isTrue);
  });

  testWidgets('admin detail renders circular content and an edit action', (tester) async {
    var edited = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuperadminCircularDetailPage(
            circularId: 'circular-published',
            repository: _Repository(),
            onBack: () {},
            onEdit: () => edited = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Renovação de matrícula'), findsOneWidget);
    expect(find.text('Coordenação Pedagógica'), findsOneWidget);
    expect(find.text('Ensino Fundamental'), findsOneWidget);
    expect(find.text('Confirme a renovação até 30 de setembro.'), findsOneWidget);
    await tester.tap(find.text('Editar circular'));
    expect(edited, isTrue);
  });
}

final class _Repository implements CircularRepository {
  bool saved = false;
  bool published = false;

  @override
  Future<CircularDraft?> loadDraft(CircularScope scope) async => null;

  @override
  Future<CircularSaveResult> saveDraft({
    required String requestId,
    required CircularScope scope,
    required CircularDraft draft,
  }) async {
    saved = true;
    return const CircularSaveResult(
      id: 'circular-published',
      revisionId: 'revision-1',
      version: 2,
      status: CircularStatus.draft,
    );
  }

  @override
  Future<CircularSaveResult> publish({
    required String requestId,
    required String circularId,
    required int expectedVersion,
    DateTime? publishAt,
  }) async {
    published = true;
    return const CircularSaveResult(
      id: 'circular-published',
      revisionId: 'revision-2',
      version: 3,
      status: CircularStatus.published,
    );
  }

  @override
  Future<CircularDetail> getVisible(String circularId, {String? childContextId}) async =>
      CircularDetail(
        id: circularId,
        revisionId: 'revision-2',
        title: 'Renovação de matrícula',
        authorName: 'Coordenação Pedagógica',
        contextLabel: 'Ensino Fundamental',
        publishedAt: DateTime.utc(2026, 8, 21),
        status: CircularStatus.published,
        responseState: CircularResponseState.unanswered,
        blocks: const [
          CircularTextBlock(id: 'text-1', text: 'Confirme a renovação até 30 de setembro.'),
        ],
      );

  @override
  Future<CircularSaveResult> closeResponses({
    required String requestId,
    required String circularId,
    required int expectedVersion,
  }) => throw UnimplementedError();

  @override
  Future<PrincipalCursorPage<CircularSummary>> listProfile(
    CircularScope scope, {
    CircularCursor? cursor,
    int limit = 20,
  }) => throw UnimplementedError();
}
