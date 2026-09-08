import 'dart:async';

import 'package:coelo_superadmin/features/principal_circulars/application/circular_composer_controller.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:coelo_superadmin/features/principal_circulars/presentation/principal_circular_composer_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dispose in [false, true]) {
    testWidgets(
      'late publication does not navigate after ${dispose ? 'dispose' : 'controller swap'}',
      (tester) async {
        final pending = Completer<CircularSaveResult>();
        final first = _readyController(_Repository(pendingPublish: pending));
        final second = _readyController(_Repository());
        addTearDown(first.dispose);
        addTearDown(second.dispose);
        var firstCallbacks = 0;
        var secondCallbacks = 0;
        Widget page(CircularComposerController controller, VoidCallback onPublished) => MaterialApp(
          home: PrincipalCircularComposerPage(
            controller: controller,
            onCancel: () {},
            onPickFiles: () async {},
            onPublished: onPublished,
          ),
        );
        await tester.pumpWidget(page(first, () => firstCallbacks++));
        await tester.tap(find.byKey(const Key('circular-publish')));
        await tester.pump();
        await tester.pumpWidget(dispose ? const SizedBox() : page(second, () => secondCallbacks++));
        pending.complete(
          const CircularSaveResult(
            id: 'circular-1',
            revisionId: 'revision-1',
            version: 3,
            status: CircularStatus.published,
          ),
        );
        await tester.pumpAndSettle();
        expect(firstCallbacks, 0);
        expect(secondCallbacks, 0);
      },
    );
  }

  testWidgets('schedule selected for old controller cannot schedule the new draft', (tester) async {
    final pending = Completer<DateTime?>();
    final first = _readyController(_Repository());
    final secondRepository = _Repository();
    final second = _readyController(secondRepository);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    Widget page(CircularComposerController controller) => MaterialApp(
      home: PrincipalCircularComposerPage(
        controller: controller,
        onCancel: () {},
        onPickFiles: () async {},
        onChooseSchedule: () => pending.future,
      ),
    );
    await tester.pumpWidget(page(first));
    await tester.ensureVisible(find.text('Agendamento'));
    await tester.tap(find.text('Agendamento'));
    await tester.pumpWidget(page(second));
    pending.complete(DateTime.now().add(const Duration(days: 10)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('circular-publish')));
    await tester.pumpAndSettle();
    expect(secondRepository.published, isTrue);
    expect(secondRepository.publishAt, isNull);
  });

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

CircularComposerController _readyController(_Repository repository) =>
    CircularComposerController(
        repository: repository,
        scope: const CircularScope(institutionId: 'institution-1'),
      )
      ..updateTitle('Circular')
      ..updateBody('Texto')
      ..toggleAudience(CircularAudienceKind.families);

final class _Repository implements CircularRepository {
  _Repository({this.pendingPublish});
  final Completer<CircularSaveResult>? pendingPublish;
  DateTime? publishAt;
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
    this.publishAt = publishAt;
    if (pendingPublish case final pending?) return pending.future;
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
