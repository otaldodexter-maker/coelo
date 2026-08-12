import 'dart:ui' show SemanticsAction, Tristate;

import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/features/audit/domain/audit.dart';
import 'package:coelo_superadmin/features/audit/presentation/audit_controller.dart';
import 'package:coelo_superadmin/features/audit/presentation/audit_detail_panel.dart';
import 'package:coelo_superadmin/features/audit/presentation/audit_directory_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loads a read-only card directory and keeps view choice across widths', (
    tester,
  ) async {
    final repository = _AuditRepository(page: _page());
    await _pump(tester, width: 1440, repository: repository);

    expect(find.byType(CoeloAdminResizableTable<AuditEvent>), findsOneWidget);
    expect(find.byKey(const Key('audit-card-list')), findsNothing);
    expect(find.byKey(const Key('audit-view-cards')), findsOneWidget);
    expect(find.byKey(const Key('audit-view-table')), findsOneWidget);
    expect(find.text('Arquivos'), findsOneWidget);
    expect(find.text('Importar'), findsNothing);
    for (final mutation in ['Criar', 'Editar', 'Excluir']) {
      expect(find.text(mutation), findsNothing);
    }

    await tester.tap(find.byKey(const Key('audit-view-cards')));
    await tester.pump();
    expect(find.byKey(const Key('audit-card-list')), findsOneWidget);

    tester.view.physicalSize = const Size(375, 900);
    await tester.pump();
    expect(find.byKey(const Key('audit-card-list')), findsOneWidget);
    expect(find.byType(CoeloAdminResizableTable<AuditEvent>), findsNothing);
  });

  testWidgets('sends search and outcome filters to the controller', (tester) async {
    final repository = _AuditRepository(page: _page());
    await _pump(tester, width: 1440, repository: repository);

    await tester.enterText(find.byKey(const Key('audit-search')), 'sessão');
    await tester.pumpAndSettle();
    expect(repository.queries.last.search, 'sessão');

    await tester.tap(find.byKey(const Key('audit-outcome-filter')));
    await tester.pump();
    final deniedItem = find.ancestor(
      of: find.text('Negado'),
      matching: find.byType(MenuItemButton),
    );
    tester.widget<MenuItemButton>(deniedItem).onPressed!();
    await tester.pump();
    final applyButton = find.ancestor(
      of: find.text('Aplicar'),
      matching: find.byType(FilledButton),
    );
    tester.widget<FilledButton>(applyButton).onPressed!();
    await tester.pumpAndSettle();
    expect(repository.queries.last.outcomes, {AuditOutcome.denied});
  });

  testWidgets('exports only CSV or XLSX with the active server query', (tester) async {
    final repository = _AuditRepository(page: _page());
    await _pump(tester, width: 1440, repository: repository);

    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pump();
    expect(find.text('Exportar CSV'), findsOneWidget);
    expect(find.text('Exportar XLSX'), findsOneWidget);
    await tester.tap(find.text('Exportar CSV'));
    await tester.pumpAndSettle();
    expect(find.text('Exportar auditoria'), findsOneWidget);
    await tester.tap(find.text('Solicitar exportação'));
    await tester.pumpAndSettle();

    expect(repository.exports.single.format, AuditExportFormat.csv);
    expect(repository.exports.single.idempotencyKey, isNotEmpty);
    expect(find.text('Exportação enfileirada'), findsOneWidget);
  });

  testWidgets('opens a completed temporary HTTPS export through the injected adapter', (
    tester,
  ) async {
    final repository = _AuditRepository(
      page: _page(),
      exportJob: AuditExportJob(
        id: 'export-ready',
        status: AuditExportStatus.completed,
        format: AuditExportFormat.xlsx,
        downloadUrl: Uri.parse('https://files.coelo.me/export.xlsx'),
        downloadExpiresInSeconds: 300,
      ),
    );
    String? openedUrl;
    await _pump(
      tester,
      width: 1440,
      repository: repository,
      openDownloadUrl: (url) async {
        openedUrl = url;
        return true;
      },
    );

    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pump();
    await tester.tap(find.text('Exportar XLSX'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Solicitar exportação'));
    await tester.pumpAndSettle();
    expect(find.text('Link temporário válido por 5 min'), findsOneWidget);
    await tester.tap(find.text('Baixar arquivo'));
    await tester.pump();
    expect(openedUrl, 'https://files.coelo.me/export.xlsx');
  });

  testWidgets('opens a read-only detail with masked diff and no simulated labels', (tester) async {
    final repository = _AuditRepository(page: _page(), detail: _detail());
    await _pump(tester, width: 1024, repository: repository);

    await tester.tap(find.byKey(const Key('audit-view-cards')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('audit-card-event-1')));
    await tester.pump();
    expect(find.byType(AuditDetailPanel), findsOneWidget);
    expect(find.text('Carregando detalhe...'), findsOneWidget);
    repository.completeDetail();
    await tester.pumpAndSettle();

    expect(find.text('***@exemplo.com'), findsOneWidget);
    expect(find.textContaining('token-secreto'), findsNothing);
    expect(find.textContaining('fake'), findsNothing);
    expect(find.textContaining('simulado'), findsNothing);
    expect(find.text('Editar'), findsNothing);
  });

  testWidgets('retries a failed detail with the originally selected event id', (tester) async {
    final repository = _AuditRepository(page: _page(), detail: _detail(), detailErrorsRemaining: 1);
    await _pump(tester, width: 1440, repository: repository);

    await tester.tap(find.byKey(const Key('event-1')));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível carregar o detalhe.'), findsOneWidget);
    repository.completeDetail();
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(repository.detailRequests, ['event-1', 'event-1']);
    expect(find.text('***@exemplo.com'), findsOneWidget);
  });

  testWidgets('immediate outcome filter preserves pending search and closes stale detail', (
    tester,
  ) async {
    final repository = _AuditRepository(page: _page(), detail: _detail());
    await _pump(tester, width: 1440, repository: repository);
    await tester.tap(find.byKey(const Key('event-1')));
    repository.completeDetail();
    await tester.pumpAndSettle();
    expect(find.byType(AuditDetailPanel), findsOneWidget);

    await tester.enterText(find.byKey(const Key('audit-search')), 'sessão');
    await tester.tap(find.byKey(const Key('audit-outcome-filter')));
    await tester.pump();
    final deniedItem = find.ancestor(
      of: find.text('Negado'),
      matching: find.byType(MenuItemButton),
    );
    tester.widget<MenuItemButton>(deniedItem).onPressed!();
    await tester.pump();
    final applyButton = find.ancestor(
      of: find.text('Aplicar'),
      matching: find.byType(FilledButton),
    );
    tester.widget<FilledButton>(applyButton).onPressed!();
    await tester.pumpAndSettle();

    expect(repository.queries.last.search, 'sessão');
    expect(repository.queries.last.outcomes, {AuditOutcome.denied});
    expect(find.byType(AuditDetailPanel), findsNothing);
  });

  testWidgets('today period starts at local civil midnight near the day boundary', (tester) async {
    final repository = _AuditRepository(page: _page());
    final now = DateTime(2026, 8, 11, 0, 30);
    await _pump(tester, width: 1440, repository: repository, clock: () => now);

    final periodButton = find.descendant(
      of: find.byKey(const Key('audit-period-filter')),
      matching: find.byType(InkWell),
    );
    await tester.tap(periodButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hoje').last);
    await tester.pumpAndSettle();

    expect(repository.queries.last.from, DateTime(2026, 8, 11));
    expect(repository.queries.last.from?.isUtc, isFalse);
    expect(repository.queries.last.to, now);
  });

  testWidgets('table rows expose focus, selection and keyboard activation without motion', (
    tester,
  ) async {
    final repository = _AuditRepository(page: _page(), detail: _detail());
    await _pump(tester, width: 1440, repository: repository);

    final row = find.byKey(const Key('event-1'));
    expect(row, findsOneWidget);
    expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
    var focused = false;
    for (var index = 0; index < 80 && !focused; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final context = FocusManager.instance.primaryFocus?.context;
      if (context == null) continue;
      focused = find
          .ancestor(
            of: find.byElementPredicate((element) => identical(element, context)),
            matching: row,
          )
          .evaluate()
          .isNotEmpty;
    }
    expect(focused, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.byType(AuditDetailPanel), findsOneWidget);
    final semantics = tester.getSemantics(row);
    expect(semantics.flagsCollection.isButton, isTrue);
    expect(semantics.flagsCollection.isSelected, Tristate.isTrue);
    expect(semantics.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    repository.completeDetail();
    await tester.pumpAndSettle();
  });

  for (final entry in <Object, String>{
    const AuditUnauthorizedException(): 'unauthorized',
    const AuditNotFoundException(): 'notFound',
    const AuditUnavailableException(): 'failure',
  }.entries) {
    testWidgets('renders ${entry.value} and retry when applicable', (tester) async {
      final repository = _AuditRepository(error: entry.key);
      await _pump(tester, width: 768, repository: repository);
      expect(find.byKey(Key('audit-state-${entry.value}')), findsOneWidget);
      if (entry.value == 'failure') {
        expect(find.text('Tentar novamente'), findsOneWidget);
      }
    });
  }

  testWidgets('renders empty and no-results as different server states', (tester) async {
    final emptyRepository = _AuditRepository(page: _page(events: const []));
    await _pump(tester, width: 375, repository: emptyRepository);
    expect(find.byKey(const Key('audit-state-empty')), findsOneWidget);
    expect(find.text('Arquivos'), findsNothing);

    final filteredRepository = _AuditRepository(page: _page(events: const []));
    await _pump(
      tester,
      width: 375,
      repository: filteredRepository,
      query: AuditQuery(search: 'sem resultado'),
    );
    expect(find.byKey(const Key('audit-state-noResults')), findsOneWidget);
    expect(find.text('Arquivos'), findsNothing);
  });

  testWidgets('stays overflow-free at required widths, themes and 200 percent text', (
    tester,
  ) async {
    for (final configuration in const [
      (375.0, Brightness.light, 2.0),
      (768.0, Brightness.dark, 1.0),
      (1024.0, Brightness.light, 1.0),
      (1440.0, Brightness.dark, 1.0),
    ]) {
      await _pump(
        tester,
        width: configuration.$1,
        repository: _AuditRepository(page: _page()),
        brightness: configuration.$2,
        textScale: configuration.$3,
      );
      expect(tester.takeException(), isNull, reason: '${configuration.$1}px');
    }
  });
}

final class _AuditRepository implements AuditRepository {
  _AuditRepository({
    this.page,
    this.detail,
    this.error,
    this.exportJob,
    this.detailErrorsRemaining = 0,
  });

  final AuditPage? page;
  final AuditEventDetail? detail;
  final Object? error;
  final AuditExportJob? exportJob;
  int detailErrorsRemaining;
  final detailRequests = <String>[];
  final queries = <AuditQuery>[];
  final exports = <AuditExportRequest>[];
  var _detailRequested = false;

  void completeDetail() => _detailRequested = true;

  @override
  Future<AuditPage> fetchPage(AuditQuery query) async {
    queries.add(query);
    if (error != null) return Future.error(error!);
    return page!;
  }

  @override
  Future<AuditEventDetail> fetchDetail(String eventId) async {
    detailRequests.add(eventId);
    if (detailErrorsRemaining > 0) {
      detailErrorsRemaining -= 1;
      throw const AuditUnavailableException();
    }
    while (!_detailRequested) {
      await Future<void>.delayed(Duration.zero);
    }
    return detail!;
  }

  @override
  Future<AuditExportJob> startExport(AuditExportRequest request) async {
    exports.add(request);
    return exportJob ??
        AuditExportJob(
          id: 'export-1',
          status: AuditExportStatus.queued,
          format: request.format,
          createdAt: DateTime.utc(2026, 8, 11),
        );
  }

  @override
  Future<AuditExportJob> fetchExportStatus(String jobId) async =>
      exportJob ??
      AuditExportJob(id: jobId, status: AuditExportStatus.queued, format: AuditExportFormat.csv);
}

AuditPage _page({List<AuditEvent>? events}) => AuditPage(
  events: events ?? [_event()],
  hasMore: false,
  totalCount: events?.length ?? 1,
  canExport: true,
);

AuditEvent _event() => AuditEvent(
  id: 'event-1',
  actor: const AuditActor(id: 'actor-1', displayName: 'Operadora Coelo', roleCode: 'support'),
  institution: const AuditInstitution(id: 'institution-1', name: 'Escola Aurora'),
  actionCode: 'session.denied',
  resourceType: 'session',
  resourceId: 'session-1',
  outcome: AuditOutcome.denied,
  correlationId: 'correlation-1',
  origin: 'edge_function',
  context: const AuditContext(kind: 'institution', id: 'institution-1'),
  occurredAt: DateTime.utc(2026, 8, 11, 12),
);

AuditEventDetail _detail() => AuditEventDetail(
  event: _event(),
  before: const {'email': '***@exemplo.com'},
  after: const {'status': 'negado'},
  reason: 'Política de acesso',
  integrity: const AuditIntegrity(position: 1, hash: 'sha256:abc', verified: true),
);

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required AuditRepository repository,
  AuditQuery? query,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  Future<bool> Function(String url)? openDownloadUrl,
  DateTime Function()? clock,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(width, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      darkTheme: CoeloTheme.dark,
      themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: true),
        child: child!,
      ),
      home: AuditDirectoryPage(
        controller: AuditDirectoryController(
          repository: repository,
          query: query ?? AuditQuery(pageSize: 11),
        ),
        activityController: SuperadminActivityController(),
        logout: unavailableSuperadminLogout,
        openDownloadUrl: openDownloadUrl ?? (_) async => true,
        clock: clock ?? DateTime.now,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
