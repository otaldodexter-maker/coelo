import 'dart:io';
import 'dart:ui';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_superadmin/features/agenda/domain/agenda_models.dart';
import 'package:coelo_superadmin/features/agenda/domain/agenda_read_repository.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_read_controller.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_read_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadFonts);
  for (final failure in [AgendaReadFailure.notFound, AgendaReadFailure.unavailable]) {
    testWidgets('return from $failure restores origin card focus', (tester) async {
      final repo = _Repo();
      await _pump(tester, repo);
      await tester.pumpAndSettle();
      repo.failure = AgendaReadException(failure);
      await tester.tap(find.text('Evento 0'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eventos'));
      await tester.pumpAndSettle();
      repo.failure = null;
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(repo.calls.where((call) => call == 'get:event-0'), hasLength(2));
    });
  }
  testWidgets('compact detail scroll exposes the last history section', (tester) async {
    await _pump(tester, _Repo(), width: 375, scale: 2);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Evento 0'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Nenhuma alteração registrada.'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Nenhuma alteração registrada.').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('compact sticky footer does not cover the last card at text200', (tester) async {
    final repo = _Repo()..count = 11;
    await _pump(tester, repo, width: 375, scale: 2);
    await tester.pumpAndSettle();
    final card = find.byKey(const Key('agenda-read-item-event-10'));
    await tester.scrollUntilVisible(card, 500, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    final footer = find.text('Página 1 de 2');
    expect(tester.getRect(card).bottom, lessThan(tester.getRect(footer).top));
    expect(tester.takeException(), isNull);
  });
  testWidgets('compact light view owns the approved surface background', (tester) async {
    await _pump(tester, _Repo(), width: 375);
    await tester.pumpAndSettle();
    final surface = tester.widget<ColoredBox>(find.byKey(const Key('agenda-read-surface')));
    expect(surface.color, CoeloTheme.light.colorScheme.surface);
  });
  testWidgets('empty stale page offers an explicit first-page recovery', (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    repo.empty = true;
    await tester.tap(find.text('Próxima'));
    await tester.pumpAndSettle();
    expect(find.text('Voltar à primeira página'), findsOneWidget);
    expect(find.text('Nenhum item encontrado'), findsNothing);
    repo.empty = false;
    await tester.tap(find.text('Voltar à primeira página'));
    await tester.pumpAndSettle();
    expect(repo.calls[repo.calls.length - 2], 'list:0:');
  });
  testWidgets('keyboard opens a card and returns from detail', (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    final ink = tester.widget<InkWell>(
      find
          .descendant(
            of: find.byKey(const Key('agenda-read-item-event-0')),
            matching: find.byType(InkWell),
          )
          .first,
    );
    ink.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'get:event-0');
    await tester.tap(find.text('Eventos'));
    await tester.pumpAndSettle();
    expect(find.text('Evento 0'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(repo.calls.where((call) => call == 'get:event-0'), hasLength(2));
  });
  testWidgets('detail404 does not render the previously opened event', (tester) async {
    final repo = _Repo();
    final controller = await _pump(tester, repo);
    await tester.pumpAndSettle();
    await controller.openDetail('event-0');
    await tester.pumpAndSettle();
    repo.failure = const AgendaReadException(AgendaReadFailure.notFound);
    await controller.openDetail('missing');
    await tester.pumpAndSettle();
    expect(find.text('Item não encontrado'), findsOneWidget);
    expect(find.text('Detalhe sintético'), findsNothing);
  });
  for (final sample in [
    'list-light',
    'list-dark',
    'hover-light',
    'status-light',
    'detail-light-200',
    'detail-dark',
    'denied-light',
    'failure-light',
  ]) {
    testWidgets('READ039 golden $sample', (tester) async {
      final repo = _Repo();
      if (sample.startsWith('denied')) {
        repo.failure = const AgendaReadException(AgendaReadFailure.unauthorized);
      }
      if (sample.startsWith('failure')) {
        repo.failure = const AgendaReadException(AgendaReadFailure.unavailable);
      }
      final compact = sample == 'detail-light-200';
      await _pump(
        tester,
        repo,
        width: compact ? 375 : 1440,
        dark: sample.contains('dark'),
        scale: compact ? 2 : 1,
      );
      await tester.pumpAndSettle();
      if (sample.startsWith('detail')) {
        await tester.tap(find.text('Evento 0'));
        await tester.pumpAndSettle();
      }
      if (sample.startsWith('hover')) {
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer();
        await mouse.moveTo(tester.getCenter(find.byKey(const Key('agenda-read-item-event-0'))));
        await tester.pumpAndSettle();
        addTearDown(mouse.removePointer);
      }
      if (sample.startsWith('status')) {
        await tester.tap(find.byType(CoeloAdminExpandableStatusIndicator));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const Key('agenda-read-golden')),
        matchesGoldenFile('goldens/agenda_read039_$sample.png'),
      );
    });
  }
  testWidgets('card status follows the compact expandable indicator', (tester) async {
    await _pump(tester, _Repo());
    await tester.pumpAndSettle();
    expect(find.byType(CoeloAdminExpandableStatusIndicator), findsOneWidget);
    await tester.tap(find.byType(CoeloAdminExpandableStatusIndicator));
    await tester.pumpAndSettle();
    expect(find.text('Publicado'), findsOneWidget);
    expect(find.byKey(const Key('agenda-read-detail')), findsNothing);
  });
  testWidgets('loads real read contract and exposes no mutation actions', (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('Evento 0'), findsOneWidget);
    expect(repo.calls, ['list:0:', 'contexts']);
    for (final command in [
      'Criar item',
      'Editar item',
      'Cancelar evento',
      'Publicar',
      'Excluir rascunho',
    ]) {
      expect(find.text(command), findsNothing);
    }
  });
  testWidgets('opens partial detail with explicit context and unknown individuals', (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Evento 0'));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'get:event-0');
    expect(
      find.text('Detalhes individuais da audiência indisponíveis nesta consulta.'),
      findsOneWidget,
    );
    expect(find.text('Unidade A Sul'), findsOneWidget);
    expect(find.text('Nenhuma alteração registrada.'), findsOneWidget);
    expect(find.textContaining('0 pessoas'), findsNothing);
  });
  testWidgets('server pagination requests next offset and never derives total from page length', (
    tester,
  ) async {
    final repo = _Repo();
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('Página 1 de 2'), findsOneWidget);
    await tester.tap(find.text('Próxima'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('list:11:'));
    expect(find.text('Página 2 de 2'), findsOneWidget);
  });
  testWidgets('denial removes content and does not offer retry', (tester) async {
    final repo = _Repo();
    final controller = await _pump(tester, repo);
    await tester.pumpAndSettle();
    repo.failure = const AgendaReadException(AgendaReadFailure.unauthorized);
    await controller.retryPage();
    await tester.pumpAndSettle();
    expect(find.text('Acesso à Agenda negado'), findsOneWidget);
    expect(find.textContaining('Evento 0'), findsNothing);
    expect(find.text('Tentar novamente'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });
  testWidgets('transient read error has explicit retry then renders refreshed content', (
    tester,
  ) async {
    final repo = _Repo()..failure = const AgendaReadException(AgendaReadFailure.unavailable);
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível carregar a Agenda'), findsOneWidget);
    repo.failure = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Evento 0'), findsOneWidget);
  });
  testWidgets('boundary change clears search and reloads without old callbacks', (tester) async {
    final repo = _Repo();
    final controller = await _pump(tester, repo);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'consulta antiga');
    await tester.pumpAndSettle();
    controller.setBoundary('new-session');
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'contexts');
    expect(repo.calls[repo.calls.length - 2], 'list:0:');
    expect(find.text('consulta antiga'), findsNothing);
  });
  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    for (final dark in [false, true]) {
      testWidgets('read view fits $width dark=$dark with text200', (tester) async {
        await _pump(tester, _Repo(), width: width, dark: dark, scale: 2);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Evento 0'), findsOneWidget);
      });
    }
  }
}

Future<AgendaReadController> _pump(
  WidgetTester tester,
  _Repo repo, {
  double width = 1440,
  bool dark = false,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = AgendaReadController(repo, boundaryKey: 'session');
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? CoeloTheme.dark : CoeloTheme.light,
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 1000), textScaler: TextScaler.linear(scale)),
        child: RepaintBoundary(
          key: const Key('agenda-read-golden'),
          child: Scaffold(
            body: AgendaReadView(
              controller: controller,
              from: DateTime.utc(2026, 9, 1),
              to: DateTime.utc(2026, 10, 1),
            ),
          ),
        ),
      ),
    ),
  );
  return controller;
}

final class _Repo implements AgendaReadRepository {
  final calls = <String>[];
  AgendaReadException? failure;
  bool empty = false;
  int count = 1;
  @override
  Future<AgendaReadPage> fetchEvents({
    required DateTime from,
    required DateTime to,
    String? institutionId,
    String search = '',
    int limit = 100,
    int offset = 0,
  }) async {
    calls.add('list:$offset:$search');
    if (failure != null) throw failure!;
    return AgendaReadPage(
      items: empty
          ? []
          : List.generate(
              count,
              (index) => _item('event-${offset + index}', 'Evento ${offset + index}'),
            ),
      total: empty ? 11 : 22,
      limit: limit,
      offset: offset,
      correlationId: 'correlation',
    );
  }

  @override
  Future<AgendaReadDetail> fetchEvent(String id) async {
    calls.add('get:$id');
    if (failure != null) throw failure!;
    return AgendaReadDetail(item: _item(id, 'Detalhe sintético'), correlationId: 'correlation');
  }

  @override
  Future<AgendaReadContexts> fetchContexts() async {
    calls.add('contexts');
    return AgendaReadContexts(
      contexts: [
        AgendaReadContext(
          id: 'unit-12',
          name: 'Unidade A Sul',
          institutionId: 'institution',
          parentId: 'institution',
          level: AgendaContextLevel.unit,
          granted: {},
          restricted: AgendaCapability.values.toSet(),
        ),
      ],
      correlationId: 'correlation',
    );
  }
}

Future<void> _loadFonts() async {
  await (FontLoader(
    'Nunito Sans',
  )..addFont(rootBundle.load('assets/brand/NunitoSans-VariableFont.ttf'))).load();
  final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final bytes = File(
    '${artifacts.path}/material_fonts/MaterialIcons-Regular.otf',
  ).readAsBytesSync();
  await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(bytes)))).load();
}

AgendaReadItem _item(String id, String title) => AgendaReadItem(
  id: id,
  institutionId: 'institution',
  contextId: 'unit-12',
  contextKind: AgendaContextLevel.unit,
  title: title,
  type: AgendaItemType.event,
  priority: AgendaPriority.normal,
  status: AgendaItemStatus.published,
  origin: AgendaItemOrigin.institution,
  startsAt: DateTime.utc(2026, 9, 8, 12),
  endsAt: DateTime.utc(2026, 9, 8, 13),
  allDay: false,
  timeZoneId: 'UTC',
  location: 'Sala',
  description: 'Descrição sintética',
  responseMode: AgendaResponseMode.none,
  guardianResponsePolicy: GuardianResponsePolicy.oneIsEnough,
  audience: AgendaReadAudience(
    institutionId: 'institution',
    unitIds: {'unit-11'},
    groupIds: {},
    activityIds: {},
  ),
  reminders: {},
  questions: [],
  revision: 1,
  history: [],
);
