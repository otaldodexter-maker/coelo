import 'package:coelo_superadmin/features/circulars/presentation/superadmin_circular_composer_page.dart';
import 'package:coelo_superadmin/features/principal_circulars/application/circular_composer_controller.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:coelo_superadmin/features/principal_circulars/presentation/principal_circular_composer_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final principalMenu in [false, true]) {
    for (final changed in [false, true]) {
      testWidgets('publication recovery feedback menu=$principalMenu changed=$changed', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(1440, 1100));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = _Repository();
        var request = 0;
        final controller =
            CircularComposerController(
                repository: repository,
                scope: const CircularScope(institutionId: 'institution-1'),
                requestIdFactory: () => 'request-${++request}',
              )
              ..updateTitle('Circular')
              ..updateBody('Texto')
              ..toggleAudience(CircularAudienceKind.families);
        addTearDown(controller.dispose);
        await expectLater(controller.publish(), throwsA(isA<CircularUnavailable>()));
        if (changed) controller.updateTitle('Edição local');
        var publishedCallbacks = 0;
        final page = principalMenu
            ? PrincipalCircularComposerPage(
                controller: controller,
                onCancel: () {},
                onPickFiles: () async {},
                onPublished: () => publishedCallbacks++,
              )
            : SuperadminCircularComposerPage(
                controller: controller,
                onCancel: () {},
                onPickFiles: (_) async {},
                onPublished: () => publishedCallbacks++,
              );
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
        final action = find.byKey(Key(changed ? 'circular-publish' : 'circular-save-draft'));
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(
          find.text(
            changed
                ? 'Publicação anterior confirmada. Suas alterações ainda não foram publicadas; revise e publique novamente.'
                : 'Confirme a publicação pendente em Publicar antes de salvar novas alterações.',
          ),
          findsOneWidget,
        );
        expect(publishedCallbacks, 0);
        expect(find.text('Circular publicada'), findsNothing);
        expect(repository.saves, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

final class _Repository implements CircularRepository {
  var saves = 0;
  String? originalRequest;
  @override
  Future<CircularSaveResult> saveDraft({
    required String requestId,
    required CircularScope scope,
    required CircularDraft draft,
  }) async {
    saves++;
    return const CircularSaveResult(
      id: 'circular-1',
      revisionId: 'revision-1',
      version: 1,
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
    if (originalRequest == null) {
      originalRequest = requestId;
      throw const CircularUnavailable();
    }
    if (requestId != originalRequest) throw const CircularVersionConflict();
    return const CircularSaveResult(
      id: 'circular-1',
      revisionId: 'revision-1',
      version: 2,
      status: CircularStatus.published,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
