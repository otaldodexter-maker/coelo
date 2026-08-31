import 'package:coelo_superadmin/features/principal_circulars/application/circular_composer_controller.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:coelo_superadmin/features/principal_circulars/presentation/principal_circular_composer_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('composer respects constraints at ${width.toInt()}px', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = previous);
      await tester.binding.setSurfaceSize(Size(width, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = CircularComposerController(
        repository: _Repository(),
        scope: const CircularScope(institutionId: 'institution-1'),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: PrincipalCircularComposerPage(
            controller: controller,
            onCancel: () {},
            onPickFiles: () async {},
          ),
        ),
      );

      expect(find.text('Sua publicação'), findsOneWidget);
      if (width >= 980) {
        expect(find.byKey(const Key('circular-publication-preview')), findsOneWidget);
      } else {
        expect(find.byKey(const Key('circular-publication-preview')), findsNothing);
      }

      await tester.enterText(find.byKey(const Key('circular-title')), 'Renovação 2027');
      await tester.enterText(find.byKey(const Key('circular-body')), 'Queridos responsáveis');
      await tester.tap(find.byKey(const Key('circular-add-question')));
      await tester.pump();

      expect(find.text('Nova pergunta'), findsWidgets);
      expect(find.text('Renovação 2027'), findsWidgets);
      expect(errors.where((error) => error.exceptionAsString().contains('overflowed')), isEmpty);
    });
  }

  testWidgets('publishes through the primary action and shows saved state', (tester) async {
    final repository = _Repository();
    final controller = CircularComposerController(
      repository: repository,
      scope: const CircularScope(institutionId: 'institution-1'),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: PrincipalCircularComposerPage(
          controller: controller,
          onCancel: () {},
          onPickFiles: () async {},
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('circular-title')), 'Circular');
    await tester.enterText(find.byKey(const Key('circular-body')), 'Texto');
    await tester.ensureVisible(find.byKey(const Key('circular-audience-families')));
    await tester.tap(find.byKey(const Key('circular-audience-families')));
    await tester.ensureVisible(find.byKey(const Key('circular-publish')));
    await tester.tap(find.byKey(const Key('circular-publish')));
    await tester.pumpAndSettle();

    expect(repository.published, isTrue);
    expect(find.text('Circular publicada'), findsOneWidget);
  });

  testWidgets('compact composer keeps preview contextual and all footer actions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var canceled = false;
    final controller = CircularComposerController(
      repository: _Repository(),
      scope: const CircularScope(institutionId: 'institution-1'),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: PrincipalCircularComposerPage(
          controller: controller,
          onCancel: () => canceled = true,
          onPickFiles: () async {},
        ),
      ),
    );

    expect(find.byKey(const Key('circular-publication-preview')), findsNothing);
    await tester.tap(find.byKey(const Key('circular-toggle-preview')));
    await tester.pump();
    expect(find.byKey(const Key('circular-publication-preview')), findsOneWidget);

    expect(find.byKey(const Key('circular-publish')), findsOneWidget);
    expect(find.byKey(const Key('circular-save-draft')), findsOneWidget);
    expect(find.byKey(const Key('circular-cancel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('circular-cancel')));
    expect(canceled, isTrue);
  });
}

final class _Repository implements CircularRepository {
  bool published = false;
  @override
  Future<CircularDraft?> loadDraft(CircularScope scope) async => null;
  @override
  Future<CircularSaveResult> saveDraft({
    required String requestId,
    required CircularScope scope,
    required CircularDraft draft,
  }) async => const CircularSaveResult(
    id: 'circular-1',
    revisionId: 'revision-1',
    version: 2,
    status: CircularStatus.draft,
  );
  @override
  Future<CircularSaveResult> publish({
    required String requestId,
    required String circularId,
    required int expectedVersion,
    DateTime? publishAt,
  }) async {
    published = true;
    return const CircularSaveResult(
      id: 'circular-1',
      revisionId: 'revision-1',
      version: 3,
      status: CircularStatus.published,
    );
  }

  @override
  Future<CircularSaveResult> closeResponses({
    required String requestId,
    required String circularId,
    required int expectedVersion,
  }) => throw UnimplementedError();
  @override
  Future<CircularDetail> getVisible(String circularId, {String? childContextId}) =>
      throw UnimplementedError();
  @override
  Future<PrincipalCursorPage<CircularSummary>> listProfile(
    CircularScope scope, {
    CircularCursor? cursor,
    int limit = 20,
  }) => throw UnimplementedError();
}
