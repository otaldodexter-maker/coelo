import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coelo_superadmin/app/navigation/superadmin_navigation.dart';

void main() {
  test('declares the requested top-level order and preview name', () {
    expect(coeloSuperadminNavigation.map((node) => node.label).toList(), <String>[
      'Home',
      'Estrutura',
      'Acompanhamento',
      'Acessos',
      'Saúde e Cuidado',
      'Operação',
      'Comunicação',
      'Governança',
      'Coelo (Principal)',
    ]);
    expect(coeloSuperadminNavigation.every((node) => !node.label.contains('Menu')), isTrue);
  });

  test('guards attendance creation with an explicit capability', () {
    final node = coeloNavigationNodeById('attendance-create')!;

    expect(node.capability, 'attendance.create');
    expect(
      node.isAvailable(CoeloNavigationEnvironment.production, canAccess: (_) => false),
      isFalse,
    );
    expect(
      node.isAvailable(CoeloNavigationEnvironment.development, canAccess: (_) => true),
      isTrue,
    );
  });

  test('guards activity creation with an explicit capability', () {
    final node = coeloNavigationNodeById('activity-create')!;

    expect(node.capability, 'activities.create');
    expect(
      node.isAvailable(CoeloNavigationEnvironment.production, canAccess: (_) => false),
      isFalse,
    );
  });

  test('mutation destinations fail closed without a capability resolver', () {
    for (final id in const [
      'institution-create',
      'person-create',
      'form-create',
      'notice-create',
      'principal-now-publish',
    ]) {
      final node = coeloNavigationNodeById(id)!;
      expect(node.capability, isNotNull, reason: id);
      expect(node.isAvailable(CoeloNavigationEnvironment.production), isFalse, reason: id);
    }
  });

  test('keeps the exact static hierarchy and excludes record-only destinations', () {
    List<String> flatten(CoeloNavigationNode node) => [
      node.label,
      for (final child in node.children) ...flatten(child),
    ];

    expect(coeloSuperadminNavigation.expand(flatten).toList(), <String>[
      'Home',
      'Estrutura',
      'Instituições',
      'Criar instituição',
      'Unidades',
      'Criar unidade',
      'Turmas',
      'Criar turma',
      'Atividades',
      'Criar atividade',
      'Lançar avaliações',
      'Fechamento de avaliações',
      'Acompanhamento',
      'Assiduidade',
      'Nova chamada',
      'Rotina diária',
      'Criar item',
      'Acompanhamento de alunos',
      'Acessos',
      'Pessoas',
      'Criar pessoa',
      'Segurança da criança',
      'Criar autorização',
      'Usuários internos',
      'Criar usuário interno',
      'Perfis e permissões',
      'Modelos de perfil',
      'Saúde e Cuidado',
      'Perfis de cuidado',
      'Criar perfil de cuidado',
      'Planos de medicação',
      'Criar plano de medicação',
      'Operação',
      'Planos',
      'Criar plano',
      'Cardápios',
      'Criar cardápio',
      'Criar modelo de cardápio',
      'Formulários',
      'Criar formulário',
      'Importações',
      'Criar importação',
      'Agenda',
      'Eventos',
      'Criar evento',
      'Solicitações',
      'Permissões',
      'Comunicação',
      'Conversas',
      'Convites',
      'Criar convite',
      'Comunicações',
      'Criar comunicação',
      'Governança',
      'Suporte e implantação',
      'Auditoria',
      'Catálogo',
      'Coelo (Principal)',
      'Acontece',
      'Publicar no Acontece',
      'Para você',
      'Momentos',
      'Publicar em Momentos',
      'Agora',
      'Publicar no Agora',
      'Perfil',
    ]);

    final labels = coeloSuperadminNavigation.expand(flatten).toSet();
    expect(labels.where((label) => label.contains('Menu')), isEmpty);
    expect(labels.where((label) => label.startsWith('Editar')), isEmpty);
    expect(labels.where((label) => label.contains('Detalhe')), isEmpty);
    expect(labels.where((label) => RegExp(r'\b(403|404|500|503)\b').hasMatch(label)), isEmpty);
    expect(labels, isNot(contains('Configurações')));
    expect(labels, isNot(contains('Criar perfil')));
    expect(labels, isNot(contains('Criar modelo de perfil')));
  });

  test('searches accents, case and create/publish actions with breadcrumbs', () {
    expect(
      searchCoeloNavigation('CRIAR').map((result) => result.node.label),
      contains('Criar instituição'),
    );
    expect(
      searchCoeloNavigation('cardapio').map((result) => result.node.label),
      contains('Cardápios'),
    );
    final publish = searchCoeloNavigation('publicar em momentos').single;
    expect(publish.breadcrumb, <String>['Coelo (Principal)', 'Momentos', 'Publicar em Momentos']);
    expect(searchCoeloNavigation('Acessos'), isEmpty);
    expect(searchCoeloNavigation('Operação'), isEmpty);
  });

  testWidgets('inline search keeps structural results non-actionable', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: const Scaffold(
          body: CoeloNavigationContent(
            collapsed: false,
            currentDestination: 'home',
            onDestinationSelected: null,
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('superadmin-navigation-search')), 'Acessos');
    await tester.pump();

    expect(find.text('Nenhum item de navegação encontrado.'), findsOneWidget);
    expect(find.text('Abrir resultado'), findsNothing);
  });

  test('exposes ancestors and filters development-only nodes', () {
    expect(coeloNavigationAncestors('principal-moments-publish'), {
      'principal',
      'principal-moments',
    });
    expect(
      searchCoeloNavigation(
        'usuários internos',
        environment: CoeloNavigationEnvironment.production,
      ),
      isEmpty,
    );
  });

  test('applies an optional capability filter without becoming an authorization boundary', () {
    const restricted = CoeloNavigationNode(
      id: 'restricted',
      label: 'Área restrita',
      icon: Icons.lock_outline,
      capability: 'area.read',
    );

    expect(
      restricted.isAvailable(CoeloNavigationEnvironment.production, canAccess: (_) => false),
      isFalse,
    );
    expect(restricted.isAvailable(CoeloNavigationEnvironment.production), isTrue);
  });

  testWidgets('navigable parents also reveal their child actions', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: CoeloNavigationContent(
            collapsed: false,
            currentDestination: 'home',
            onDestinationSelected: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('superadmin-navigation-section-structure')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('superadmin-navigation-institutions')));
    await tester.pump();

    expect(selected, 'institutions');
    expect(find.byKey(const Key('superadmin-navigation-institution-create')), findsOneWidget);
  });

  testWidgets('restores the expansion state after clearing navigation search', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: const Scaffold(
          body: CoeloNavigationContent(
            collapsed: false,
            currentDestination: 'home',
            onDestinationSelected: null,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('superadmin-navigation-section-structure')));
    await tester.pump();
    expect(find.byKey(const Key('superadmin-navigation-institutions')), findsOneWidget);
    expect(find.byKey(const Key('superadmin-navigation-institution-create')), findsNothing);

    final search = find.byKey(const Key('superadmin-navigation-search'));
    await tester.enterText(search, 'criar instituição');
    await tester.pump();
    expect(find.byKey(const Key('superadmin-navigation-institution-create')), findsOneWidget);

    await tester.enterText(search, '');
    await tester.pump();
    expect(find.byKey(const Key('superadmin-navigation-institutions')), findsOneWidget);
    expect(find.byKey(const Key('superadmin-navigation-institution-create')), findsNothing);
  });

  testWidgets('navigation items support keyboard activation and visible focus', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: CoeloNavigationContent(
            collapsed: false,
            currentDestination: 'unknown',
            onDestinationSelected: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(selected, isNotNull);
    expect(find.byType(FocusableActionDetector), findsWidgets);
  });

  testWidgets('collapsed search renders breadcrumbs and navigates to a result', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: CoeloNavigationContent(
            collapsed: true,
            currentDestination: 'home',
            onDestinationSelected: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('superadmin-navigation-search-collapsed')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('superadmin-navigation-search-dialog')), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'CRIAR instituição');
    await tester.pump();
    expect(find.bySemanticsLabel('Estrutura › Instituições › Criar instituição'), findsOneWidget);
    await tester.tap(find.text('Criar instituição'));
    await tester.pumpAndSettle();
    expect(selected, 'institution-create');
    expect(find.byKey(const Key('superadmin-navigation-search-dialog')), findsNothing);
  });

  testWidgets('collapsed search closes with Escape', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: const Scaffold(
          body: CoeloNavigationContent(
            collapsed: true,
            currentDestination: 'home',
            onDestinationSelected: null,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('superadmin-navigation-search-collapsed')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('superadmin-navigation-search-dialog')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('superadmin-navigation-search-dialog')), findsNothing);
    expect(FocusManager.instance.primaryFocus, isNotNull);
  });

  testWidgets('collapsed search keeps structural results in the dialog without closing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: const Scaffold(
          body: CoeloNavigationContent(
            collapsed: true,
            currentDestination: 'home',
            onDestinationSelected: null,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('superadmin-navigation-search-collapsed')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Operação');
    await tester.pump();

    expect(find.byKey(const Key('superadmin-navigation-search-dialog')), findsOneWidget);
    expect(find.text('Nenhum item de navegação encontrado.'), findsOneWidget);
    expect(find.text('Abrir resultado'), findsNothing);
  });
}
