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
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    expect(find.text('Cadastrar pessoa'), findsOneWidget);

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

  testWidgets('wizard searches server-side and requires child selection', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = ChildSafetyController(_Repository());
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
    await tester.enterText(find.byType(TextFormField).at(0), 'person-1');
    await tester.enterText(find.byType(TextFormField).at(1), 'Solicitação familiar');
    await tester.tap(find.byKey(const Key('safety-wizard-primary')));
    await tester.pump();
    expect(find.byType(CoeloDateRangeField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wizard preselects deep-linked child and loads edit version', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _Repository();
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
    child: body!,
  ),
  home: child,
);
Future<LogoutResult> _logout() async => const LogoutResult.success();

final class _Repository implements ChildSafetyRepository {
  _Repository({this.unauthorized = false, this.totalCount = 3, this.canCreate = true});
  final bool unauthorized;
  final int totalCount;
  final bool canCreate;
  SavePickupAuthorizationCommand? savedCommand;
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
      if (record.childId == childId) return record;
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
  Future<void> removeAuthorization(RemovePickupAuthorizationCommand command) async {}
  @override
  Future<void> requestExport(ChildSafetyExportCommand command) async {}
}
