import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_superadmin/features/circulars/domain/superadmin_circular_repository.dart';
import 'package:coelo_superadmin/features/circulars/presentation/production_circular_hosts.dart';
import 'package:coelo_superadmin/features/circulars/presentation/circular_directory_page.dart';
import 'package:coelo_superadmin/features/circulars/presentation/superadmin_circular_composer_page.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_repository.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final oldFailure in [false, true]) {
    testWidgets('composer rejects old ${oldFailure ? 'denial' : 'draft'} after repository swap', (
      tester,
    ) async {
      final repositoryA = _QueuedRepository();
      final repositoryB = _QueuedRepository();
      final institutions = _UnusedInstitutions();
      Widget page(_QueuedRepository repository, String id) => MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: ProductionCircularComposerHost(
            repository: repository,
            institutionRepository: institutions,
            circularId: id,
            onCancel: () {},
            onDone: () {},
          ),
        ),
      );
      await tester.pumpWidget(page(repositoryA, 'a'));
      await tester.pumpWidget(page(repositoryB, 'b'));
      expect(repositoryB.draftIds, ['b']);
      repositoryB.drafts.single.complete(_editable('B'));
      await tester.pumpAndSettle();
      if (oldFailure) {
        repositoryA.drafts.single.completeError(const CircularUnauthorized());
      } else {
        repositoryA.drafts.single.complete(_editable('A'));
      }
      await tester.pumpAndSettle();
      final composer = tester.widget<SuperadminCircularComposerPage>(
        find.byType(SuperadminCircularComposerPage),
      );
      expect(composer.controller.repository, same(repositoryB));
      expect(composer.controller.scope.institutionId, 'institution-B');
      expect(composer.controller.draft.title, 'Private B');
      expect(find.text('Private A'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('composer clears loaded draft and reloads changed ID', (tester) async {
    final repository = _QueuedRepository();
    final institutions = _UnusedInstitutions();
    Widget page(String id) => MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: ProductionCircularComposerHost(
          repository: repository,
          institutionRepository: institutions,
          circularId: id,
          onCancel: () {},
          onDone: () {},
        ),
      ),
    );
    await tester.pumpWidget(page('a'));
    repository.drafts.single.complete(_editable('A'));
    await tester.pumpAndSettle();
    expect(find.text('Private A'), findsAtLeastNWidgets(1));
    await tester.pumpWidget(page('b'));
    expect(find.text('Private A'), findsNothing);
    expect(repository.draftIds, ['a', 'b']);
    repository.drafts.last.complete(_editable('B'));
    await tester.pumpAndSettle();
    expect(find.text('Private B'), findsAtLeastNWidgets(1));
  });

  for (final oldFailure in [false, true]) {
    testWidgets('directory rejects old ${oldFailure ? 'denial' : 'items'} after repository swap', (
      tester,
    ) async {
      final repositoryA = _QueuedRepository();
      final repositoryB = _QueuedRepository();
      Widget page(_QueuedRepository repository) => MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: ProductionCircularDirectoryHost(
            repository: repository,
            onOpen: (_) {},
            onCreate: () {},
          ),
        ),
      );
      await tester.pumpWidget(page(repositoryA));
      await tester.pumpWidget(page(repositoryB));
      expect(repositoryB.directories, hasLength(1));
      repositoryB.directories.single.complete(_directory('B'));
      await tester.pumpAndSettle();
      if (oldFailure) {
        repositoryA.directories.single.completeError(const CircularUnauthorized());
      } else {
        repositoryA.directories.single.complete(_directory('A'));
      }
      await tester.pumpAndSettle();
      expect(find.text('Private B'), findsAtLeastNWidgets(1));
      expect(
        tester.widget<CircularDirectoryPage>(find.byType(CircularDirectoryPage)).items.single.title,
        'Private B',
      );
      expect(find.text('Private A'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

SuperadminCircularEditableDraft _editable(String label) => SuperadminCircularEditableDraft(
  scope: CircularScope(institutionId: 'institution-$label'),
  draft: CircularDraft(id: label, title: 'Private $label', blocks: const []),
);

SuperadminCircularDirectoryPage _directory(String label) => SuperadminCircularDirectoryPage(
  items: [
    SuperadminCircularDirectoryItem(
      id: label,
      institutionId: 'institution-$label',
      title: 'Private $label',
      excerpt: '',
      authorName: 'Synthetic author',
      contextLabel: 'Synthetic context',
      status: CircularStatus.draft,
      effectiveAt: DateTime.utc(2026, 9, 7),
      updatedAt: DateTime.utc(2026, 9, 7),
      attachmentCount: 0,
      questionCount: 0,
      responseCount: 0,
      managementVersion: 1,
    ),
  ],
);

final class _QueuedRepository implements SuperadminCircularRepository {
  final draftIds = <String>[];
  final drafts = <Completer<SuperadminCircularEditableDraft>>[];
  final directories = <Completer<SuperadminCircularDirectoryPage>>[];

  @override
  Future<SuperadminCircularEditableDraft> loadDraftById(String circularId) {
    draftIds.add(circularId);
    final request = Completer<SuperadminCircularEditableDraft>();
    drafts.add(request);
    return request.future;
  }

  @override
  Future<SuperadminCircularDirectoryPage> fetchDirectory(SuperadminCircularDirectoryQuery query) {
    final request = Completer<SuperadminCircularDirectoryPage>();
    directories.add(request);
    return request.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _UnusedInstitutions implements InstitutionDirectoryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
