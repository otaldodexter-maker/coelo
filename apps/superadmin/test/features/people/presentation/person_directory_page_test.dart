import 'dart:ui' show PointerDeviceKind, SemanticsAction;

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/people/domain/person_directory.dart'
    show
        PersonDirectoryRepository,
        PersonDirectorySegment,
        PersonDirectoryTableView,
        PersonFilterOption;
import 'package:coelo_superadmin/features/people/presentation/person_directory_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_directory_view_toggle.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_underline_tabs.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/people/fake_person_directory_repository.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('offers approved people segments and progressive filter chains', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    for (final label in const [
      'Todos',
      'Equipe institucional',
      'Responsáveis',
      'Crianças',
      'Perfil duplo',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byType(SuperadminUnderlineTabs<PersonDirectorySegment>), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('people-filter-toolbar'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('people-segment-selector'))).dy),
    );
    expect(find.byKey(const Key('people-unit-filter')), findsNothing);
    expect(find.byKey(const Key('people-group-filter')), findsNothing);
    expect(find.byKey(const Key('people-activity-filter')), findsNothing);
    expect(find.byKey(const Key('people-municipality-filter')), findsNothing);
    expect(find.byKey(const Key('people-neighborhood-filter')), findsNothing);

    final institutionFilter = tester.widget<CoeloAdminMultiSelectFilter<PersonFilterOption>>(
      find.descendant(
        of: find.byKey(const Key('people-institution-filter')),
        matching: find.byType(CoeloAdminMultiSelectFilter<PersonFilterOption>),
      ),
    );
    institutionFilter.onChanged({institutionFilter.options.first});
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('people-unit-filter')), findsOneWidget);

    final stateFilter = tester.widget<CoeloAdminMultiSelectFilter<PersonFilterOption>>(
      find.descendant(
        of: find.byKey(const Key('people-state-filter')),
        matching: find.byType(CoeloAdminMultiSelectFilter<PersonFilterOption>),
      ),
    );
    stateFilter.onChanged({stateFilter.options.first});
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('people-municipality-filter')), findsOneWidget);
  });

  testWidgets('uses directory toggle and exposes grouped institution unit group activity tables', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final finder = find.byType(SuperadminDirectoryViewToggle<PersonDirectoryTableView>);
    expect(finder, findsOneWidget);
    final toggle = tester.widget<SuperadminDirectoryViewToggle<PersonDirectoryTableView>>(finder);
    expect(
      toggle.tableViews.map((option) => option.label),
      containsAll(const ['Instituições', 'Unidades', 'Turmas', 'Atividades']),
    );
    toggle.onTableViewSelected(PersonDirectoryTableView.activities);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byKey(const Key('people-table')), matching: find.text('Atividades')),
      findsOneWidget,
    );
  });

  testWidgets('cards show deduplicated quantitative relations without contact or roles', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        repository: FakePersonDirectoryRepository(
          seed: [
            FakePersonDirectoryRepository.samplePeople[0],
            FakePersonDirectoryRepository.samplePeople[1],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final child = find.byKey(const Key('person-card-person-1'));
    expect(child, findsOneWidget);
    expect(find.descendant(of: child, matching: find.text('Contato')), findsNothing);
    expect(find.descendant(of: child, matching: find.text('Papéis')), findsNothing);
    expect(find.descendant(of: child, matching: find.text('Instituição 1')), findsNothing);
    expect(find.descendant(of: child, matching: find.text('Instituições')), findsOneWidget);
    expect(
      find.descendant(of: child, matching: find.text('Responsáveis vinculados')),
      findsOneWidget,
    );

    final adult = find.byKey(const Key('person-card-person-0'));
    expect(find.descendant(of: adult, matching: find.text('Contato')), findsNothing);
    expect(find.descendant(of: adult, matching: find.text('Papéis')), findsNothing);
    expect(find.descendant(of: adult, matching: find.text('Crianças vinculadas')), findsOneWidget);
    expect(find.descendant(of: adult, matching: find.text('Alunos acompanhados')), findsOneWidget);
  });

  testWidgets('shows eleven cards, avatar, banner and file actions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(CoeloAvatar), findsNWidgets(11));
    expect(find.byType(CoeloAdminCreateAction), findsOneWidget);
    final create = tester.widget<CoeloAdminCreateAction>(find.byType(CoeloAdminCreateAction));
    expect(create.variant, CoeloAdminCreateActionVariant.tile);
    expect(find.byKey(const Key('create-person-card')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('create-person-card'))).height,
      tester.getSize(find.byKey(const Key('person-card-person-0'))).height,
    );
    expect(find.byKey(const Key('coelo-admin-files-action')), findsOneWidget);
    expect(find.text('Arquivos'), findsOneWidget);
  });

  testWidgets('switches to eight table rows and exposes approved page sizes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('people-view-table')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('people-table')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('people-table-row-person-'),
      ),
      findsNWidgets(8),
    );
    final banner = tester.widget<CoeloAdminCreateAction>(find.byType(CoeloAdminCreateAction));
    expect(banner.variant, CoeloAdminCreateActionVariant.banner);
    expect(banner.description, 'Cadastre identidade e vínculos contextuais.');
    await tester.tap(find.byKey(const Key('coelo-admin-pagination-page-size')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coelo-admin-pagination-page-size-20')), findsOneWidget);
    expect(find.byKey(const Key('coelo-admin-pagination-page-size-50')), findsOneWidget);
    expect(find.byKey(const Key('coelo-admin-pagination-page-size-100')), findsOneWidget);
  });

  testWidgets('service opens its read-only detail route', (tester) async {
    String? edited;
    final repository = FakePersonDirectoryRepository(
      seed: [FakePersonDirectoryRepository.samplePeople[2]],
    );
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(repository: repository, onEdit: (value) => edited = value));
    await tester.pumpAndSettle();

    final service = find.byKey(const Key('person-card-person-2'));
    expect(service, findsOneWidget);
    await tester.tap(service);
    await tester.pump();
    expect(edited, 'person-2');
    expect(find.textContaining('Somente leitura'), findsWidgets);
  });

  testWidgets('table exposes all contextual columns', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('people-view-table')));
    await tester.pumpAndSettle();

    final table = find.byKey(const Key('people-table'));
    for (final label in const [
      'Pessoa',
      'Tipo',
      'Status',
      'Instituição',
      'Unidade',
      'Turma',
      'Papel contextual',
      'Auth',
    ]) {
      expect(
        find.descendant(of: table, matching: find.text(label)),
        label == 'Pessoa' ? findsNWidgets(2) : findsOneWidget,
      );
    }
    final horizontalScroll = tester.widget<SingleChildScrollView>(
      find.descendant(of: table, matching: find.byKey(const Key('coelo-admin-table-scroll'))),
    );
    expect(horizontalScroll.scrollDirection, Axis.horizontal);
    expect(horizontalScroll.controller!.position.maxScrollExtent, greaterThan(0));
    expect(
      tester
          .widget<Scrollbar>(find.descendant(of: table, matching: find.byType(Scrollbar)))
          .thumbVisibility,
      isTrue,
    );
  });

  testWidgets('card supports hover, focus, keyboard and semantics', (tester) async {
    String? edited;
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(onEdit: (value) => edited = value));
    await tester.pumpAndSettle();

    final card = find.byKey(const Key('person-card-person-0'));
    expect(
      find.ancestor(of: card, matching: find.byType(CoeloAdminInteractiveCard)),
      findsOneWidget,
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(card));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final action = find.descendant(of: card, matching: find.byType(InkWell));
    tester.widget<InkWell>(action.first).focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(edited, 'person-0');

    final semantics = tester.getSemantics(card);
    expect(semantics.label, contains('Ana Pessoa 1'));
    expect(semantics.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
  });

  testWidgets('create action supports focus, keyboard and semantics', (tester) async {
    var creates = 0;
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(onCreate: () => creates++));
    await tester.pumpAndSettle();

    final create = find.byType(CoeloAdminCreateAction);
    final action = find.descendant(of: create, matching: find.byType(InkWell));
    tester.widget<InkWell>(action).focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(creates, 1);
    final semantics = tester.getSemantics(create);
    expect(semantics.label, contains('Criar pessoa'));
    expect(semantics.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
  });

  testWidgets('last card and launcher scroll above sticky pagination at 375', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(onConversationsOpen: () {}));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    final scroll = find.byKey(const Key('people-directory-scroll'));
    final scrollable = find.descendant(of: scroll, matching: find.byType(Scrollable)).first;
    final cards = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('person-card-person-'),
    );
    await tester.scrollUntilVisible(cards.last, 400, scrollable: scrollable);
    await tester.drag(scroll, const Offset(0, -1000));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    final footerTop = tester
        .getTopLeft(find.byKey(const Key('people-directory-pagination-footer')))
        .dy;
    expect(tester.getBottomRight(cards.last).dy, lessThanOrEqualTo(footerTop));
    expect(
      tester.getBottomRight(find.byKey(const Key('superadmin-chat-launcher-surface'))).dy,
      lessThanOrEqualTo(footerTop),
    );
  });

  testWidgets('last table row scrolls above sticky pagination at 375', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('people-view-table')));
    await tester.pumpAndSettle();

    final directoryScroll = find.byKey(const Key('people-directory-scroll'));
    final verticalScrollable = find
        .descendant(of: directoryScroll, matching: find.byType(Scrollable))
        .first;
    final rows = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('people-table-row-person-'),
    );
    await tester.scrollUntilVisible(rows.last, 400, scrollable: verticalScrollable);
    await tester.drag(directoryScroll, const Offset(0, -1000));
    await tester.pumpAndSettle();

    final footerTop = tester
        .getTopLeft(find.byKey(const Key('people-directory-pagination-footer')))
        .dy;
    expect(tester.getBottomRight(rows.last).dy, lessThanOrEqualTo(footerTop));
  });

  testWidgets('renders unauthorized and retryable failure states', (tester) async {
    await tester.pumpWidget(_app(repository: FakePersonDirectoryRepository(unauthorized: true)));
    await tester.pumpAndSettle();
    expect(find.text('Acesso não autorizado'), findsOneWidget);
    expect(find.byKey(const Key('people-filter-toolbar')), findsNothing);
    expect(find.byKey(const Key('people-segment-selector')), findsNothing);
    expect(find.byKey(const Key('create-person-card')), findsNothing);
    expect(find.byKey(const Key('create-person-banner')), findsNothing);

    await tester.pumpWidget(_app(repository: FakePersonDirectoryRepository(fail: true)));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível carregar as pessoas'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('clears tenant content when repository is replaced by unauthorized', (tester) async {
    final allowed = FakePersonDirectoryRepository();
    await tester.pumpWidget(_pageApp(allowed));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('people-filter-toolbar')), findsOneWidget);
    expect(find.text('Ana Pessoa 1'), findsWidgets);

    await tester.pumpWidget(_pageApp(FakePersonDirectoryRepository(unauthorized: true)));
    await tester.pumpAndSettle();

    expect(find.text('Acesso não autorizado'), findsOneWidget);
    expect(find.text('Ana Pessoa 1'), findsNothing);
    expect(find.byKey(const Key('people-filter-toolbar')), findsNothing);
    expect(find.byKey(const Key('people-segment-selector')), findsNothing);
    expect(find.byKey(const Key('create-person-card')), findsNothing);
    expect(find.byKey(const Key('coelo-admin-files-action')), findsNothing);
  });

  testWidgets('omits create and edit actions when callbacks are absent', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(withActions: false));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create-person-card')), findsNothing);
    final card = find.byKey(const Key('person-card-person-0'));
    final action = find.descendant(of: card, matching: find.byType(InkWell));
    expect(tester.widget<InkWell>(action).onTap, isNull);

    await tester.tap(find.byKey(const Key('people-view-table')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('create-person-banner')), findsNothing);
  });
}

Widget _pageApp(PersonDirectoryRepository repository) => MaterialApp(
  theme: CoeloTheme.light,
  home: PersonDirectoryPage(
    repository: repository,
    logout: () async => const LogoutResult.success(),
    onCreate: () {},
    onEdit: (_) {},
    onImport: () {},
    onExport: (_, _) {},
  ),
);

Widget _app({
  FakePersonDirectoryRepository? repository,
  VoidCallback? onCreate,
  ValueChanged<String>? onEdit,
  VoidCallback? onConversationsOpen,
  bool withActions = true,
}) {
  final resolvedRepository = repository ?? FakePersonDirectoryRepository();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => PersonDirectoryPage(
          key: ValueKey(resolvedRepository),
          repository: resolvedRepository,
          logout: () async => const LogoutResult.success(),
          onCreate: withActions ? (onCreate ?? () {}) : null,
          onEdit: withActions ? (onEdit ?? (_) {}) : null,
          onConversationsOpen: onConversationsOpen,
          onImport: () {},
          onExport: (_, _) {},
        ),
      ),
    ],
  );
  return MaterialApp.router(
    theme: CoeloTheme.light,
    darkTheme: CoeloTheme.dark,
    routerConfig: router,
  );
}
