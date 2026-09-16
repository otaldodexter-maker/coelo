import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_directory_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/activities/fake_activity_directory_repository.dart';

/// spec 052 (ADR 0041 B1, owner.r12-02): Atividades › Modelos com aba
/// Arquivados, Arquivar/Restaurar com confirmação, recarga e leitor v1.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required _LifecycleDirectoryRepository repository,
    Future<bool> Function(ActivityTemplateOption template)? onArchive,
    Future<bool> Function(ActivityTemplateOption template)? onRestore,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: ActivityDirectoryPage(
          repository: repository,
          logout: () async => const LogoutResult.success(),
          onCreate: () {},
          onView: (_) {},
          onCreateFromTemplate: (_) {},
          onCreateTemplate: (_) async {},
          onDuplicateTemplate: (_, _, _, _) async {},
          onArchiveTemplate: onArchive,
          onRestoreTemplate: onRestore,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the directory reads the v1 reader and hides archived templates from Todos', (
    tester,
  ) async {
    final repository = _LifecycleDirectoryRepository();
    await pump(tester, repository: repository, onArchive: (_) async => true);

    expect(repository.directoryReads, 1, reason: 'diretório lê o leitor v1');
    expect(repository.optionReads, 0, reason: 'o leitor de opções fica para o formulário');
    expect(find.byKey(const Key('activity-template-template-active')), findsOneWidget);
    expect(find.byKey(const Key('activity-template-template-archived')), findsNothing);
    expect(find.text('Arquivados'), findsOneWidget);
  });

  testWidgets('Arquivados shows only archived templates with Restaurar and no start/duplicate', (
    tester,
  ) async {
    await pump(
      tester,
      repository: _LifecycleDirectoryRepository(),
      onArchive: (_) async => true,
      onRestore: (_) async => true,
    );
    tester
        .widget<CoeloAdminDirectoryStatusTabs>(
          find.byKey(const Key('activity-template-status-tabs')),
        )
        .onSelected(CoeloAdminDirectoryStatusTab.archived);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('activity-template-template-active')), findsNothing);
    expect(find.byKey(const Key('activity-template-template-archived')), findsOneWidget);
    expect(find.byKey(const Key('activity-template-archived-template-archived')), findsOneWidget);
    expect(find.byKey(const Key('activity-template-restore-template-archived')), findsOneWidget);
    expect(find.byKey(const Key('activity-template-archive-template-archived')), findsNothing);
    expect(find.byKey(const Key('activity-template-start-template-archived')), findsNothing);
    expect(find.byKey(const Key('activity-template-duplicate-template-archived')), findsNothing);
  });

  testWidgets('Arquivar confirms, calls the callback with the loaded version and reloads', (
    tester,
  ) async {
    final repository = _LifecycleDirectoryRepository();
    final archived = <ActivityTemplateOption>[];
    await pump(
      tester,
      repository: repository,
      onArchive: (template) async {
        archived.add(template);
        repository.archive(template.id);
        return true;
      },
    );
    final archiveButton = find.byKey(const Key('activity-template-archive-template-active'));
    await tester.ensureVisible(archiveButton);
    await tester.tap(archiveButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('activity-template-archive-dialog')), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(archived, isEmpty, reason: 'cancelar não chama o callback');

    await tester.tap(archiveButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('activity-template-archive-confirm')));
    await tester.pumpAndSettle();
    expect(archived.single.id, 'template-active');
    expect(archived.single.managementVersion, 3, reason: 'expected_version do item carregado');
    expect(repository.directoryReads, 2, reason: 'recarga após arquivar');
    expect(find.byKey(const Key('activity-template-template-active')), findsNothing);
  });

  testWidgets('Restaurar confirms and reloads, bringing the template back to Todos', (
    tester,
  ) async {
    final repository = _LifecycleDirectoryRepository();
    await pump(
      tester,
      repository: repository,
      onArchive: (_) async => true,
      onRestore: (template) async {
        repository.restore(template.id);
        return true;
      },
    );
    tester
        .widget<CoeloAdminDirectoryStatusTabs>(
          find.byKey(const Key('activity-template-status-tabs')),
        )
        .onSelected(CoeloAdminDirectoryStatusTab.archived);
    await tester.pumpAndSettle();
    final restoreButton = find.byKey(const Key('activity-template-restore-template-archived'));
    await tester.ensureVisible(restoreButton);
    await tester.tap(restoreButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('activity-template-restore-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('activity-template-restore-confirm')));
    await tester.pumpAndSettle();
    expect(repository.directoryReads, 2);
    expect(find.byKey(const Key('activity-template-template-archived')), findsNothing);
    tester
        .widget<CoeloAdminDirectoryStatusTabs>(
          find.byKey(const Key('activity-template-status-tabs')),
        )
        .onSelected(CoeloAdminDirectoryStatusTab.all);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('activity-template-template-archived')), findsOneWidget);
  });

  testWidgets('the table exposes archive and restore per row', (tester) async {
    await pump(
      tester,
      repository: _LifecycleDirectoryRepository(),
      onArchive: (_) async => true,
      onRestore: (_) async => true,
    );
    await tester.tap(find.byKey(const Key('activity-template-view-table')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('activity-template-table-archive-template-active')),
      findsOneWidget,
    );
    tester
        .widget<CoeloAdminDirectoryStatusTabs>(
          find.byKey(const Key('activity-template-status-tabs')),
        )
        .onSelected(CoeloAdminDirectoryStatusTab.archived);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('activity-template-table-restore-template-archived')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('activity-template-table-start-template-archived')), findsNothing);
  });

  testWidgets('without lifecycle callbacks nothing is exposed', (tester) async {
    await pump(tester, repository: _LifecycleDirectoryRepository());
    expect(find.byKey(const Key('activity-template-archive-template-active')), findsNothing);
    expect(find.widgetWithText(TextButton, 'Arquivar'), findsNothing);
  });
}

final class _LifecycleDirectoryRepository extends FakeActivityDirectoryRepository
    implements ActivityTemplateDirectoryReader {
  int directoryReads = 0;
  int optionReads = 0;
  final Map<String, ActivityStatus> _status = {
    'template-active': ActivityStatus.active,
    'template-archived': ActivityStatus.archived,
  };

  void archive(String id) => _status[id] = ActivityStatus.archived;
  void restore(String id) => _status[id] = ActivityStatus.active;

  ActivityTemplateOptions _catalog() => ActivityTemplateOptions(
    institutions: const [
      ActivityFormInstitutionOption(id: 'institution-1', name: 'Colégio Horizonte'),
    ],
    taxonomy: const [ActivityTaxonomyOption(id: 'languages', label: 'Idiomas')],
    templates: [
      ActivityTemplateOption(
        id: 'template-active',
        name: 'Inglês',
        taxonomyId: 'languages',
        scopeKind: ActivityTemplateScopeKind.institution,
        institutionId: 'institution-1',
        status: _status['template-active']!,
        managementVersion: 3,
      ),
      ActivityTemplateOption(
        id: 'template-archived',
        name: 'Xadrez',
        taxonomyId: 'languages',
        scopeKind: ActivityTemplateScopeKind.institution,
        institutionId: 'institution-1',
        status: _status['template-archived']!,
        managementVersion: 1,
      ),
    ],
  );

  @override
  Future<ActivityTemplateOptions> fetchTemplateDirectory({String? institutionId}) async {
    directoryReads++;
    return _catalog();
  }

  @override
  Future<ActivityTemplateOptions> fetchTemplateOptions({String? institutionId}) async {
    optionReads++;
    return _catalog();
  }
}
