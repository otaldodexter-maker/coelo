import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/safety/application/child_safety_controller.dart';
import 'package:coelo_superadmin/features/safety/domain/child_safety.dart';
import 'package:coelo_superadmin/features/safety/domain/child_safety_contract.dart';
import 'package:coelo_superadmin/features/safety/presentation/safety_pages.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/golden_header_profile.dart';

void main() {
  testWidgets('read-only composition disables edit transition and suspension', (tester) async {
    final controller = ChildSafetyController(_Repository(mutationsEnabled: false));
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(
      _app(
        ChildSecurityPage(
          childId: 'child-1',
          controller: controller,
          logout: _logout,
          onBack: () {},
          onEdit: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Gerenciar').first);
    await tester.tap(find.text('Gerenciar').first);
    await tester.pumpAndSettle();
    expect(find.text('Criança: Ana Criança'), findsOneWidget);
    expect(find.text('Relação: Mãe'), findsOneWidget);
    expect(find.text('Capacidades: Retirada'), findsOneWidget);
    expect(find.text('Motivo: Solicitação familiar'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('safety-suspend-authorization')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Gerenciar').last);
    await tester.tap(find.text('Gerenciar').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Aprovar')).onPressed,
      isNull,
    );
    expect(
      tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Rejeitar')).onPressed,
      isNull,
    );
    expect(
      tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Editar')).onPressed,
      isNull,
    );
  });

  testWidgets('read-only composition blocks wizard deep link and command dispatch', (tester) async {
    final repository = _Repository(editPending: true, mutationsEnabled: false);
    final controller = ChildSafetyController(repository);
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(
      _app(
        ChildSafetyWizardPage(
          childId: 'child-1',
          authorizationId: 'auth-1',
          controller: controller,
          logout: _logout,
          onCancel: () {},
          onSaved: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('safety-wizard-primary'))).onPressed,
      isNull,
    );
    expect(
      await controller.suspendAuthorization(
        const SuspendPickupAuthorizationCommand(
          requestId: 'request',
          childId: 'child-1',
          authorizationId: 'auth-1',
          reason: 'test',
        ),
      ),
      isFalse,
    );
    expect(repository.suspendedCommand, isNull);
    expect(controller.commandFailure, ChildSafetyCommandFailure.unavailable);
  });

  testWidgets('directory status keeps 48 px target and isolates touch and keyboard from card', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: SizedBox(
            width: 540,
            child: SafetyChildDirectoryCard(
              record: _Repository.records.first,
              onPressed: () => opened++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final status = find.byKey(const Key('safety-child-status-child-1'));
    final bounds = tester.getRect(status);
    expect(bounds.width, greaterThanOrEqualTo(CoeloSize.touchMin));
    expect(bounds.height, greaterThanOrEqualTo(CoeloSize.touchMin));
    final label = find.descendant(of: status, matching: find.text('Aguardando aprovação'));
    expect(label, findsNothing);
    // The right edge is outside the 24 px dot but inside its 48 px target.
    await tester.tapAt(bounds.centerRight - const Offset(2, 0));
    await tester.pumpAndSettle();
    expect(label, findsOneWidget);
    expect(opened, 0);
    final detector = find.descendant(of: status, matching: find.byType(FocusableActionDetector));
    Focus.of(
      tester.element(find.descendant(of: detector, matching: find.byType(GestureDetector))),
    ).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(label, findsNothing);
    expect(opened, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('table renders authoritative count without loading authorization details', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = ChildSafetyController(_Repository());
    addTearDown(controller.dispose);
    await controller.setView(ChildSafetyDirectoryView.table);
    await tester.pumpWidget(
      _app(SafetyLandingPage(controller: controller, logout: _logout, onOpenChild: (_) {})),
    );
    await tester.pumpAndSettle();
    final table = tester.widget<CoeloAdminResizableTable<ChildSafetyRecord>>(
      find.byKey(const Key('safety-children-table')),
    );
    final column = table.columns.singleWhere((column) => column.id == 'authorized');
    final cell =
        column.cellBuilder(
              tester.element(find.byKey(const Key('safety-children-table'))),
              _Repository.records.last,
            )
            as Text;
    expect(cell.data, '1');
  });

  testWidgets('detail discards prior child when route child changes', (tester) async {
    final controller = ChildSafetyController(_Repository());
    addTearDown(controller.dispose);
    await controller.load();
    Widget page(String id) => _app(
      ChildSecurityPage(childId: id, controller: controller, logout: _logout, onBack: () {}),
    );
    await tester.pumpWidget(page('child-1'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Criança'), findsOneWidget);
    await tester.pumpWidget(page('child-2'));
    await tester.pumpAndSettle();
    expect(find.text('Bia Criança'), findsOneWidget);
    expect(find.text('Ana Criança'), findsNothing);
  });

  testWidgets('detail removes cached private content after authorization is lost', (tester) async {
    final repository = _Repository();
    final controller = ChildSafetyController(repository);
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(
      _app(
        ChildSecurityPage(
          childId: 'child-1',
          controller: controller,
          logout: _logout,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    repository.unauthorized = true;
    await controller.retry();
    await tester.pumpAndSettle();
    expect(find.text('Ana Criança'), findsNothing);
    expect(find.text('Contexto indisponível'), findsOneWidget);
  });

  testWidgets('edit rejects a nonpending authorization before enabling continuation', (
    tester,
  ) async {
    final controller = ChildSafetyController(_Repository());
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        ChildSafetyWizardPage(
          childId: 'child-1',
          authorizationId: 'auth-1',
          controller: controller,
          logout: _logout,
          onCancel: () {},
          onSaved: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível carregar o contexto solicitado.'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('safety-wizard-primary'))).onPressed,
      isNull,
    );
  });

  testWidgets('edit preserves the authorized child and person identity', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = ChildSafetyController(_Repository(editPending: true));
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        ChildSafetyWizardPage(
          childId: 'child-1',
          authorizationId: 'auth-1',
          controller: controller,
          logout: _logout,
          onCancel: () {},
          onSaved: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<CoeloFormTextField>(find.byType(CoeloFormTextField).first).enabled,
      isFalse,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate((widget) => widget is IconButton && widget.tooltip == 'Buscar'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('safety-wizard-primary')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CoeloFormTextField>(find.byType(CoeloFormTextField).first).enabled,
      isFalse,
    );
  });

  testWidgets('directory uses exclusive counted tabs, canonical cards and table', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = ChildSafetyController(_Repository(), searchDebounce: Duration.zero);
    await controller.load();
    var created = false;
    await tester.pumpWidget(
      _app(
        SafetyLandingPage(
          controller: controller,
          logout: _logout,
          onOpenChild: (_) {},
          onCreate: () => created = true,
          onExport: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Todos (3)'), findsOneWidget);
    expect(find.text('Aguardando aprovação (1)'), findsOneWidget);
    expect(find.text('Atenção (0)'), findsOneWidget);
    expect(find.text('Autorizadas (1)'), findsOneWidget);
    expect(find.text('Sem autorização (1)'), findsOneWidget);
    expect(find.byType(CoeloAdminInteractiveCard), findsNWidgets(3));
    expect(find.byKey(const Key('safety-create-card')), findsOneWidget);
    expect(find.byType(CoeloAdminFileActions), findsOneWidget);
    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    expect(find.text('Importar'), findsOneWidget);

    await tester.tap(find.text('Criar segurança'));
    expect(created, isTrue);
    await tester.tap(find.byKey(const Key('safety-view-table')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-children-table')), findsOneWidget);
    expect(find.byKey(const Key('safety-create-banner')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unauthorized fails closed without create action', (tester) async {
    final controller = ChildSafetyController(_Repository(unauthorized: true));
    await controller.load();
    await tester.pumpWidget(
      _app(
        SafetyLandingPage(
          controller: controller,
          logout: _logout,
          onOpenChild: (_) {},
          onCreate: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Sem permissão'), findsOneWidget);
    expect(find.text('Criar segurança'), findsNothing);
    expect(find.byType(CoeloSearchField), findsNothing);
    expect(find.textContaining('Todos ('), findsNothing);
  });

  testWidgets('keeps unavailable export visible with honest feedback', (tester) async {
    final controller = ChildSafetyController(_Repository(), searchDebounce: Duration.zero);
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(
      _app(SafetyLandingPage(controller: controller, logout: _logout, onOpenChild: (_) {})),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    expect(find.text('Exportar CSV'), findsOneWidget);
    await tester.tap(find.text('Exportar CSV'));
    await tester.pumpAndSettle();
    expect(find.text('Indisponível nesta etapa'), findsOneWidget);
  });

  testWidgets('paginated directory keeps controls in a sticky footer', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = ChildSafetyController(
      _Repository(totalCount: 24),
      searchDebounce: Duration.zero,
    );
    await controller.load();
    await tester.pumpWidget(
      _app(
        SafetyLandingPage(
          controller: controller,
          logout: _logout,
          onOpenChild: (_) {},
          onCreate: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('safety-directory-pagination-footer')), findsOneWidget);
    expect(
      find.ancestor(of: find.byType(CoeloAdminPagination), matching: find.byType(Positioned)),
      findsOneWidget,
    );
  });

  testWidgets('detail uses table at 768 and cards at 375', (tester) async {
    final controller = ChildSafetyController(_Repository());
    await controller.load();
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(768, 1000));
    await tester.pumpWidget(
      _app(
        ChildSecurityPage(
          childId: 'child-1',
          controller: controller,
          logout: _logout,
          onBack: () {},
          onCreate: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('authorized-persons-table')), findsOneWidget);
    expect(find.text('Aprovado · Ativa'), findsOneWidget);
    expect(find.byKey(const Key('safety-create-authorization-banner')), findsOneWidget);
    expect(find.text('Criar autorização'), findsOneWidget);
    expect(find.text('Cadastrar pessoa'), findsNothing);

    await tester.binding.setSurfaceSize(const Size(375, 1000));
    await tester.pumpWidget(
      _app(
        ChildSecurityPage(
          childId: 'child-1',
          controller: controller,
          logout: _logout,
          onBack: () {},
          onCreate: () {},
        ),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Maria'), 200);
    expect(find.byType(CoeloAdminExpandableStatusIndicator), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail hides create action without create capability', (tester) async {
    final controller = ChildSafetyController(_Repository(canCreate: false));
    await controller.load();
    await tester.pumpWidget(
      _app(
        ChildSecurityPage(
          childId: 'child-1',
          controller: controller,
          logout: _logout,
          onBack: () {},
          onCreate: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('safety-add-authorized-person')), findsNothing);
  });

  testWidgets('suspension confirms, can be cancelled and reloads after success', (tester) async {
    await tester.binding.setSurfaceSize(const Size(768, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _Repository();
    final controller = ChildSafetyController(repository);
    await controller.load();
    await tester.pumpWidget(
      _app(
        ChildSecurityPage(
          childId: 'child-1',
          controller: controller,
          logout: _logout,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Gerenciar').first);
    await tester.tap(find.text('Gerenciar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safety-suspend-authorization')));
    await tester.pumpAndSettle();
    expect(find.text('Suspender autorização?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('safety-cancel-suspension')));
    await tester.pumpAndSettle();
    expect(repository.suspendedCommand, isNull);

    await tester.tap(find.byKey(const Key('safety-suspend-authorization')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safety-confirm-suspension')));
    await tester.pumpAndSettle();

    expect(repository.suspendedCommand?.authorizationId, 'auth-1');
    expect(repository.suspendedCommand?.expectedVersion, 7);
    expect(repository.directoryLoads, 2);
    expect(find.text('Suspender autorização?'), findsNothing);
  });

  testWidgets('pending request does not present inactive lifecycle as revoked', (tester) async {
    await tester.binding.setSurfaceSize(const Size(768, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = ChildSafetyController(_Repository());
    await controller.load();
    await tester.pumpWidget(
      _app(
        ChildSecurityPage(
          childId: 'child-1',
          controller: controller,
          logout: _logout,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Gerenciar').last);
    await tester.tap(find.text('Gerenciar').last);
    await tester.pumpAndSettle();

    expect(find.text('Gerenciar Carlos'), findsOneWidget);
    expect(find.textContaining('Situação:'), findsNothing);
    expect(find.textContaining('Revogada'), findsNothing);
  });

  testWidgets('wizard searches server-side and requires child selection', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _Repository();
    final controller = ChildSafetyController(repository);
    await tester.pumpWidget(
      _app(
        ChildSafetyWizardPage(
          controller: controller,
          logout: _logout,
          onCancel: () {},
          onSaved: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SuperadminFormStepNavigation), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('superadmin-form-steps-scroll'))).width, 248);
    await tester.tap(find.byKey(const Key('safety-wizard-primary')));
    await tester.pump();
    expect(find.text('Busque e selecione uma criança.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Ana');
    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Criança'), findsWidgets);
    await tester.tap(find.text('Ana Criança'));
    await tester.tap(find.byKey(const Key('safety-wizard-primary')));
    await tester.pump();
    expect(find.text('Pessoa autorizada'), findsWidgets);
    // B5: sem pessoa selecionada o passo nao avanca; o UUID nunca e digitado.
    await tester.enterText(find.byType(TextFormField).at(1), 'Solicitação familiar');
    await tester.tap(find.byKey(const Key('safety-wizard-primary')));
    await tester.pump();
    expect(find.textContaining('Busque e selecione a pessoa autorizada'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('safety-person-search')), 'Ma');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Digite ao menos 3 caracteres.'), findsOneWidget);
    expect(repository.personSearches, isEmpty);
    await tester.enterText(find.byKey(const Key('safety-person-search')), 'Maria');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(repository.personSearches, ['Maria']);
    expect(find.text('Maria Responsável'), findsOneWidget);
    expect(find.text('@maria.resp · •••• 1234'), findsOneWidget);
    expect(find.textContaining('123.456'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Selecionar Maria Responsável'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('safety-wizard-primary')));
    await tester.pump();
    expect(find.byType(CoeloDateRangeField), findsOneWidget);
    await tester.tap(find.byKey(const Key('safety-wizard-primary')));
    await tester.pump();
    expect(find.text('Maria Responsável'), findsOneWidget);
    expect(find.text('person-1'), findsNothing);
    await tester.tap(find.byKey(const Key('safety-wizard-primary')));
    await tester.pumpAndSettle();
    expect(repository.savedCommand?.personId, 'person-1');
    expect(repository.savedCommand?.childId, 'child-1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('wizard person search fills child and person from a linked child', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _Repository();
    final controller = ChildSafetyController(repository);
    await tester.pumpWidget(
      _app(
        ChildSafetyWizardPage(
          controller: controller,
          logout: _logout,
          onCancel: () {},
          onSaved: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('safety-person-search')), '99-1234');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(repository.personSearches, ['99-1234']);
    await tester.tap(find.byKey(const Key('safety-person-child-person-1-child-1')));
    await tester.pump();
    expect(find.text('Ana Criança'), findsWidgets);
    await tester.tap(find.byKey(const Key('safety-wizard-primary')));
    await tester.pump();
    expect(find.text('Pessoa autorizada'), findsWidgets);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(1), 'Solicitação familiar');
    await tester.tap(find.byKey(const Key('safety-wizard-primary')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('safety-wizard-primary')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('safety-wizard-primary')));
    await tester.pumpAndSettle();
    expect(repository.savedCommand?.personId, 'person-1');
    expect(repository.savedCommand?.childId, 'child-1');
    expect(repository.savedCommand?.childContextId, 'context-1');
    expect(repository.savedCommand?.unitId, 'unit-1');
  });

  testWidgets('wizard registers a person without account and requires the document', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _Repository(personSearchEmpty: true);
    final controller = ChildSafetyController(repository);
    var picks = 0;
    await tester.pumpWidget(
      _app(
        ChildSafetyWizardPage(
          controller: controller,
          logout: _logout,
          onCancel: () {},
          onSaved: () {},
          pickPersonDocument: () async {
            picks++;
            return const ChildSafetyPersonDocumentFile(
              fileName: 'rg.png',
              mimeType: 'image/png',
              bytes: [137, 80, 78, 71, 13, 10, 26, 10],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Crianca pela busca; depois a busca de pessoa nao encontra ninguem.
    await tester.enterText(find.byKey(const Key('safety-child-search')), 'Ana');
    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Criança'));
    await tester.tap(find.byKey(const Key('safety-wizard-primary')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('safety-person-search')), 'Tio Sem');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-person-register-toggle')), findsOneWidget);
    await tester.tap(find.byKey(const Key('safety-person-register-toggle')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('safety-register-name')), 'Tio Sem Conta');
    await tester.enterText(find.byKey(const Key('safety-register-cpf')), '111.444.777-35');
    await tester.ensureVisible(find.byKey(const Key('safety-register-submit')));
    await tester.tap(find.byKey(const Key('safety-register-submit')));
    await tester.pumpAndSettle();
    expect(repository.registeredCommand?.cpf, '11144477735');
    expect(repository.registeredCommand?.childContextId, 'context-1');
    expect(repository.registeredCommand?.unitId, 'unit-1');
    expect(find.byKey(const Key('safety-person-without-account-card')), findsOneWidget);
    expect(find.textContaining('***.***.***-35'), findsWidgets);
    expect(find.textContaining('11144477735'), findsNothing);

    // Sem documento nao avanca; com documento avanca e salva com authorized_person_id.
    await tester.enterText(find.byType(TextFormField).at(1), 'Solicitação familiar');
    await tester.tap(find.byKey(const Key('safety-wizard-primary')));
    await tester.pump();
    expect(find.text('Envie a imagem do documento para continuar.'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('safety-person-document-upload')));
    await tester.tap(find.byKey(const Key('safety-person-document-upload')));
    await tester.pumpAndSettle();
    expect(picks, 1);
    expect(repository.uploadedDocument?.authorizedPersonId, 'no-account-1');
    expect(repository.uploadedDocument?.file.mimeType, 'image/png');
    expect(find.byKey(const Key('safety-person-document-ready')), findsOneWidget);
    await tester.tap(find.byKey(const Key('safety-wizard-primary')));
    await tester.pump();
    expect(find.byType(CoeloDateRangeField), findsOneWidget);
    await tester.tap(find.byKey(const Key('safety-wizard-primary')));
    await tester.pump();
    expect(find.textContaining('sem conta'), findsWidgets);
    await tester.tap(find.byKey(const Key('safety-wizard-primary')));
    await tester.pumpAndSettle();
    expect(repository.savedCommand?.authorizedPersonId, 'no-account-1');
    expect(repository.savedCommand?.personId, '');
    expect(tester.takeException(), isNull);
  });

  testWidgets('wizard explains when the CPF already belongs to an account', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _Repository(personSearchEmpty: true, personHasAccount: true);
    final controller = ChildSafetyController(repository);
    await tester.pumpWidget(
      _app(
        ChildSafetyWizardPage(
          childId: 'child-1',
          controller: controller,
          logout: _logout,
          onCancel: () {},
          onSaved: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safety-wizard-primary')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('safety-person-search')), 'Tio Sem');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safety-person-register-toggle')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('safety-register-name')), 'Tio Sem Conta');
    await tester.enterText(find.byKey(const Key('safety-register-cpf')), '11144477735');
    await tester.ensureVisible(find.byKey(const Key('safety-register-submit')));
    await tester.tap(find.byKey(const Key('safety-register-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Essa pessoa já tem conta: busque pelo CPF completo acima.'), findsOneWidget);
    expect(find.byKey(const Key('safety-person-without-account-card')), findsNothing);
  });

  testWidgets('wizard person search shows the rate limit message', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _Repository(personSearchRateLimited: true);
    final controller = ChildSafetyController(repository);
    await tester.pumpWidget(
      _app(
        ChildSafetyWizardPage(
          controller: controller,
          logout: _logout,
          onCancel: () {},
          onSaved: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('safety-person-search')), 'Maria');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Muitas buscas em sequência. Aguarde um minuto.'), findsOneWidget);
  });

  testWidgets('wizard preselects deep-linked child and loads edit version', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _Repository(editPending: true);
    final controller = ChildSafetyController(repository);
    var saved = false;
    await tester.pumpWidget(
      _app(
        ChildSafetyWizardPage(
          childId: 'child-1',
          authorizationId: 'auth-1',
          controller: controller,
          logout: _logout,
          onCancel: () {},
          onSaved: () => saved = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ana Criança'), findsWidgets);
    await tester.tap(find.byKey(const Key('safety-wizard-primary')));
    await tester.pump();
    expect(find.text('Pessoa autorizada'), findsWidgets);
    expect(find.text('Solicitação familiar'), findsOneWidget);
    await tester.tap(find.byKey(const Key('safety-wizard-primary')));
    await tester.pump();
    expect(find.text('Sem data final'), findsOneWidget);
    await tester.tap(find.byKey(const Key('safety-wizard-primary')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('safety-wizard-primary')));
    await tester.pumpAndSettle();
    expect(repository.savedCommand?.validFrom, DateTime(2026, 1, 1));
    expect(repository.savedCommand?.validUntil, isNull);
    expect(saved, isTrue);
  });

  testWidgets('directory stays responsive in light and dark at 200 percent text', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in <double>[375, 768, 1024, 1440]) {
      for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
        await tester.binding.setSurfaceSize(Size(width, 1200));
        final controller = ChildSafetyController(_Repository());
        await controller.load();
        await tester.pumpWidget(
          _app(
            SafetyLandingPage(
              controller: controller,
              logout: _logout,
              onOpenChild: (_) {},
              onCreate: () {},
              onExport: () {},
            ),
            themeMode: mode,
            textScaler: const TextScaler.linear(2),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$width / $mode');
        expect(find.text('Todos (3)'), findsOneWidget);
        controller.dispose();
      }
    }
  });

  testWidgets('directory golden matches approved institution-card anatomy', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = ChildSafetyController(_Repository());
    await controller.load();
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('safety-directory-golden'),
        child: _app(
          SafetyLandingPage(
            controller: controller,
            logout: _logout,
            onOpenChild: (_) {},
            onCreate: () {},
            onExport: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('safety-directory-golden')),
      matchesGoldenFile('goldens/child_safety_directory_light_1440.png'),
    );
  });

  testWidgets('relationship codes are localized in authorization cards', (tester) async {
    final controller = ChildSafetyController(_Repository());
    addTearDown(controller.dispose);
    const authorization = PickupAuthorization(
      id: 'auth-code',
      name: 'Maria',
      relationship: 'mother',
      institutionName: 'Instituição Aurora',
      unitName: 'Unidade Centro',
      status: PickupAuthorizationStatus.approved,
      origin: PickupAuthorizationOrigin.institution,
    );
    const record = ChildSafetyRecord(
      childId: 'child-code',
      childName: 'Ana Criança',
      internalId: 'RA code',
      institutionName: 'Instituição Aurora',
      unitName: 'Unidade Centro',
      authorizations: [authorization],
    );
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: AuthorizedPersonCard(
            record: record,
            authorization: authorization,
            controller: controller,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mãe'), findsOneWidget);
    expect(find.text('mother'), findsNothing);
  });
}

Widget _app(
  Widget child, {
  ThemeMode themeMode = ThemeMode.light,
  TextScaler textScaler = TextScaler.noScaling,
}) => MaterialApp(
  theme: CoeloTheme.light,
  darkTheme: CoeloTheme.dark,
  themeMode: themeMode,
  builder: (context, body) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler),
    child: withGoldenHeaderProfile(body!),
  ),
  home: child,
);
Future<LogoutResult> _logout() async => const LogoutResult.success();

final class _Repository
    implements
        ChildSafetyRepository,
        ChildSafetyMutationSupport,
        ChildSafetyPersonSearchSupport,
        ChildSafetyPersonWithoutAccountSupport {
  _Repository({
    this.unauthorized = false,
    this.totalCount = 3,
    this.canCreate = true,
    this.editPending = false,
    this.mutationsEnabled = true,
    this.personSearchRateLimited = false,
    this.personSearchEmpty = false,
    this.personHasAccount = false,
  });
  @override
  final bool mutationsEnabled;
  final bool editPending;
  final bool personSearchRateLimited;
  final bool personSearchEmpty;
  final bool personHasAccount;
  final personSearches = <String>[];
  RegisterPersonWithoutAccountCommand? registeredCommand;
  ChildSafetyPersonDocumentUpload? uploadedDocument;
  bool unauthorized;

  @override
  Future<PersonWithoutAccountRegistration> registerPersonWithoutAccount(
    RegisterPersonWithoutAccountCommand command,
  ) async {
    registeredCommand = command;
    if (personHasAccount) throw const ChildSafetyPersonHasAccountException();
    return const PersonWithoutAccountRegistration(
      authorizedPersonId: 'no-account-1',
      displayName: 'Tio Sem Conta',
      cpfMasked: '***.***.***-35',
      existing: false,
      documentStatus: 'missing',
    );
  }

  @override
  Future<ChildSafetyPersonDocument> uploadPersonDocument(
    ChildSafetyPersonDocumentUpload upload,
  ) async {
    uploadedDocument = upload;
    return const ChildSafetyPersonDocument(documentId: 'doc-1', status: 'ready');
  }

  @override
  Future<List<ChildSafetyPersonMatch>> searchPeople(String query) async {
    personSearches.add(query);
    if (personSearchRateLimited) throw const ChildSafetyRateLimitException();
    if (personSearchEmpty) return const [];
    return const [
      ChildSafetyPersonMatch(
        personId: 'person-1',
        displayName: 'Maria Responsável',
        initials: 'MR',
        matchedBy: 'name',
        handle: '@maria.resp',
        phoneLast4: '1234',
        hasAccount: true,
        children: [
          ChildSafetyChildOption(
            id: 'child-1',
            name: 'Ana Criança',
            childContextId: 'context-1',
            institutionId: 'institution-1',
            institutionName: 'Instituição Aurora',
            unitId: 'unit-1',
            unitName: 'Unidade Centro',
          ),
        ],
      ),
    ];
  }

  final int totalCount;
  final bool canCreate;
  SavePickupAuthorizationCommand? savedCommand;
  SuspendPickupAuthorizationCommand? suspendedCommand;
  int directoryLoads = 0;
  static final records = [
    ChildSafetyRecord(
      childId: 'child-1',
      childName: 'Ana Criança',
      internalId: 'RA 1',
      institutionName: 'Instituição Aurora',
      unitName: 'Unidade Centro',
      authorizations: [
        PickupAuthorization(
          id: 'auth-1',
          name: 'Maria',
          relationship: 'Mãe',
          institutionName: 'Instituição Aurora',
          unitName: 'Unidade Centro',
          status: PickupAuthorizationStatus.approved,
          origin: PickupAuthorizationOrigin.institution,
          startsAt: DateTime(2026, 1, 1),
          lifetime: false,
          personId: 'person-1',
          childContextId: 'context-1',
          unitId: 'unit-1',
          capabilityCodes: {'pickup'},
          requestReason: 'Solicitação familiar',
          version: 7,
        ),
        const PickupAuthorization(
          id: 'auth-2',
          name: 'Carlos',
          relationship: 'Avô',
          institutionName: 'Instituição Aurora',
          unitName: 'Unidade Centro',
          status: PickupAuthorizationStatus.pending,
          origin: PickupAuthorizationOrigin.guardian,
        ),
      ],
      childContextId: 'context-1',
      institutionId: 'institution-1',
      unitId: 'unit-1',
      directorySegment: ChildSafetyDirectorySegment.awaitingApproval,
      authorizationCount: 1,
    ),
    const ChildSafetyRecord(
      childId: 'child-2',
      childName: 'Bia Criança',
      internalId: 'RA 2',
      institutionName: 'Instituição Aurora',
      unitName: 'Unidade Norte',
      authorizations: [],
      directorySegment: ChildSafetyDirectorySegment.withoutAuthorization,
    ),
    const ChildSafetyRecord(
      childId: 'child-3',
      childName: 'Caio Criança',
      internalId: 'RA 3',
      institutionName: 'Instituição Horizonte',
      unitName: 'Unidade Sul',
      authorizations: [],
      directorySegment: ChildSafetyDirectorySegment.authorized,
      authorizationCount: 1,
    ),
  ];
  @override
  Future<ChildSafetyDirectoryPage> fetchDirectory(ChildSafetyDirectoryQuery query) async {
    directoryLoads++;
    if (unauthorized) throw const ChildSafetyUnauthorizedException();
    return ChildSafetyDirectoryPage(
      records: records,
      totalCount: totalCount,
      segmentCounts: const ChildSafetySegmentCounts(
        all: 3,
        awaitingApproval: 1,
        authorized: 1,
        withoutAuthorization: 1,
      ),
      canCreate: canCreate,
    );
  }

  @override
  Future<ChildSafetyRecord?> fetchChild(String childId) async {
    for (final record in records) {
      if (record.childId == childId) {
        return editPending
            ? record.withAuthorizations(
                record.authorizations
                    .map((item) => item.withStatus(PickupAuthorizationStatus.pending))
                    .toList(),
              )
            : record;
      }
    }
    return null;
  }

  @override
  Future<List<ChildSafetyChildOption>> searchChildren(String query, {int limit = 20}) async =>
      const [
        ChildSafetyChildOption(
          id: 'child-1',
          name: 'Ana Criança',
          internalId: 'RA 1',
          childContextId: 'context-1',
          institutionId: 'institution-1',
          institutionName: 'Instituição Aurora',
          unitId: 'unit-1',
          unitName: 'Unidade Centro',
        ),
      ];
  @override
  Future<void> saveAuthorization(SavePickupAuthorizationCommand command) async {
    savedCommand = command;
  }

  @override
  Future<void> transitionAuthorization(TransitionPickupAuthorizationCommand command) async {}
  @override
  Future<void> suspendAuthorization(SuspendPickupAuthorizationCommand command) async {
    suspendedCommand = command;
  }

  @override
  Future<void> requestExport(ChildSafetyExportCommand command) async {}
}
